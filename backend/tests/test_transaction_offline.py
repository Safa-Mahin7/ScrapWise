
from copy import deepcopy
from types import SimpleNamespace
from datetime import datetime

from backend.app.schemas.collection_transaction import (
    CollectionTransactionCreate,
)

from backend.app.services.collection_service import (
    create_collection_transaction,
    confirm_transaction,
    dispute_transaction,
    get_confirmed_weekly_collection_data,
)


class FakeCursor:
    def __init__(self, documents):
        self.documents = documents

    def __iter__(self):
        return iter(self.documents)


class FakeCollection:
    """In-memory test collection. No MongoDB connection."""

    def __init__(self):
        self.documents = []

    def insert_one(self, document):
        self.documents.append(deepcopy(document))
        return SimpleNamespace(inserted_id="TEST-ID")

    def update_one(self, query, update):
        for doc in self.documents:
            if all(doc.get(k) == v for k, v in query.items()):
                doc.update(deepcopy(update.get("$set", {})))
                return SimpleNamespace(matched_count=1)

        return SimpleNamespace(matched_count=0)

    def find(self, query, projection=None):
        results = [
            deepcopy(doc)
            for doc in self.documents
            if all(doc.get(k) == v for k, v in query.items())
        ]

        if projection:
            included = [
                key for key, value in projection.items()
                if value == 1
            ]

            if included:
                results = [
                    {key: doc[key] for key in included if key in doc}
                    for doc in results
                ]

        return FakeCursor(results)


def main():
    collection = FakeCollection()

    payload = CollectionTransactionCreate(
        request_id="DEMO-REQ-001",
        household_id="DEMO-H001",
        locality_id="DEMO-BALLARI-1",
        collector_id="DEMO-C001",
        recorded_by_user_id="DEMO-C001",
        entry_mode="collector_self",
        materials=[
            {
                "material_type": "newspaper",
                "actual_weight_kg": 5.5,
                "agreed_rate_per_kg": 12,
            },
            {
                "material_type": "PET_plastic",
                "actual_weight_kg": 2,
                "agreed_rate_per_kg": 10,
            },
        ],
        weighed_at=datetime.fromisoformat(
            "2026-11-09T10:30:00+05:30"
        ),
    )

    transaction = create_collection_transaction(
        collection, payload
    )

    print("Transaction created:", transaction["transaction_id"])
    print("Calculated amount:", transaction["total_amount"])

    assert transaction["total_amount"] == 86
    assert transaction["transaction_status"] == (
        "awaiting_household_confirmation"
    )

    assert get_confirmed_weekly_collection_data(collection) == []

    try:
        confirm_transaction(
            collection,
            transaction["transaction_id"],
            "WRONG-HOUSEHOLD",
        )
        raise AssertionError(
            "Incorrect household was allowed to confirm."
        )
    except ValueError:
        print("Household ownership check: PASSED")

    confirm_transaction(
        collection,
        transaction["transaction_id"],
        "DEMO-H001",
    )

    disputed_payload = payload.model_copy(
        update={
            "request_id": "DEMO-REQ-002",
            "household_id": "DEMO-H002",
        }
    )

    disputed = create_collection_transaction(
        collection,
        disputed_payload,
    )

    dispute_transaction(
        collection,
        disputed["transaction_id"],
        "DEMO-H002",
    )

    weekly = get_confirmed_weekly_collection_data(collection)

    print("Confirmed weekly records:", len(weekly))

    for record in weekly:
        print(
            record["material_type"],
            record["actual_collected_kg"],
            "kg | households:",
            record["participating_households_count"],
        )

    assert len(weekly) == 2

    actual_weights = {
        row["material_type"]: row["actual_collected_kg"]
        for row in weekly
    }

    assert actual_weights["newspaper"] == 5.5
    assert actual_weights["PET_plastic"] == 2.0

    assert all(
        row["confirmed_transaction_count"] == 1
        for row in weekly
    )

    print("\nTRANSACTION WORKFLOW TEST PASSED!")


def test_standalone_transaction_workflow():
    main()


if __name__ == "__main__":
    main()
