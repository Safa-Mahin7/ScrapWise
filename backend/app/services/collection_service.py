from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from uuid import uuid4

from pymongo.client_session import ClientSession
from pymongo.collection import Collection

from ..schemas.collection_transaction import (
    CollectionTransactionCreate
)


INDIA_TZ = ZoneInfo("Asia/Kolkata")


def create_collection_transaction(
    collection: Collection,
    payload: CollectionTransactionCreate,
) -> dict:
    return _insert_collection_transaction(
        collection,
        payload,
        session=None,
        transaction_id=None,
    )


def create_claimed_collection_transaction(
    collection: Collection,
    payload: CollectionTransactionCreate,
    *,
    session: ClientSession,
    transaction_id: str,
) -> dict:
    return _insert_collection_transaction(
        collection,
        payload,
        session=session,
        transaction_id=transaction_id,
    )


def _insert_collection_transaction(
    collection: Collection,
    payload: CollectionTransactionCreate,
    *,
    session: ClientSession | None,
    transaction_id: str | None,
) -> dict:

    data = payload.model_dump()

    # Calculate total on the backend.
    # Never trust a total amount sent by the frontend.
    total_amount = round(
        sum(
            item["actual_weight_kg"] *
            item["agreed_rate_per_kg"]
            for item in data["materials"]
        ),
        2
    )

    now = datetime.now(timezone.utc)

    transaction = {
        **data,
        "transaction_id": transaction_id or str(uuid4()),
        "total_amount": total_amount,
        "transaction_status": "awaiting_household_confirmation",
        "data_source": "real_collector_transaction",
        "created_at": now,
        "updated_at": now
    }

    if session is None:
        collection.insert_one(transaction)
    else:
        collection.insert_one(transaction, session=session)

    # MongoDB's internal ObjectId is not needed in the API response.
    transaction.pop("_id", None)

    return transaction


def confirm_transaction(
    collection: Collection,
    transaction_id: str,
    household_id: str
) -> bool:

    result = collection.update_one(
        {
            "transaction_id": transaction_id,
            "household_id": household_id,
            "transaction_status": "awaiting_household_confirmation"
        },
        {
            "$set": {
                "transaction_status": "confirmed",
                "confirmed_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )

    if result.matched_count == 0:
        raise ValueError(
            "Transaction not found or no longer awaiting confirmation."
        )

    return True


def dispute_transaction(
    collection: Collection,
    transaction_id: str,
    household_id: str
) -> bool:

    result = collection.update_one(
        {
            "transaction_id": transaction_id,
            "household_id": household_id,
            "transaction_status": "awaiting_household_confirmation"
        },
        {
            "$set": {
                "transaction_status": "disputed",
                "disputed_at": datetime.now(timezone.utc),
                "updated_at": datetime.now(timezone.utc)
            }
        }
    )

    if result.matched_count == 0:
        raise ValueError(
            "Transaction not found or no longer awaiting confirmation."
        )

    return True


def _get_week_start(date_time: datetime) -> str:

    # MongoDB stores dates in UTC. Convert to Indian local time
    # before deciding which collection week they belong to.
    if date_time.tzinfo is None:
        date_time = date_time.replace(tzinfo=timezone.utc)

    local_date = date_time.astimezone(INDIA_TZ).date()

    monday = local_date - timedelta(
        days=local_date.weekday()
    )

    return monday.isoformat()


def get_confirmed_weekly_collection_data(
    collection: Collection
) -> list:

    # Only household-confirmed transactions enter forecasting history.
    transactions = collection.find(
        {
            "transaction_status": "confirmed",
            "data_source": "real_collector_transaction"
        },
        {
            "_id": 0,
            "household_id": 1,
            "locality_id": 1,
            "weighed_at": 1,
            "materials": 1
        }
    )

    weekly_data = {}

    for transaction in transactions:

        weighed_at = transaction["weighed_at"]

        if isinstance(weighed_at, str):
            weighed_at = datetime.fromisoformat(
                weighed_at.replace("Z", "+00:00")
            )

        week_start = _get_week_start(weighed_at)

        for material in transaction["materials"]:

            key = (
                transaction["locality_id"],
                material["material_type"],
                week_start
            )

            if key not in weekly_data:
                weekly_data[key] = {
                    "locality_id": transaction["locality_id"],
                    "material_type": material["material_type"],
                    "week_start_date": week_start,
                    "actual_collected_kg": 0.0,
                    "confirmed_transaction_count": 0,
                    "households": set()
                }

            weekly_data[key]["actual_collected_kg"] += (
                material["actual_weight_kg"]
            )

            weekly_data[key]["confirmed_transaction_count"] += 1

            weekly_data[key]["households"].add(
                transaction["household_id"]
            )

    result = []

    for record in weekly_data.values():

        household_count = len(record["households"])
        record.pop("households")

        record["actual_collected_kg"] = round(
            record["actual_collected_kg"], 2
        )

        record["participating_households_count"] = household_count

        record["data_source"] = "real_collector_transaction"

        result.append(record)

    return sorted(
        result,
        key=lambda row: (
            row["locality_id"],
            row["material_type"],
            row["week_start_date"]
        )
    )