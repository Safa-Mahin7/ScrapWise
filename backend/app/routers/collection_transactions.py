
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from pymongo.errors import DuplicateKeyError, PyMongoError

from ..auth.dependencies import get_auth_db, has_permissions, require_roles
from ..schemas.collection_transaction import (
    CollectionTransactionCreate,
    CollectionTransactionResponse,
)
from ..services.collection_service import (
    create_claimed_collection_transaction,
    confirm_transaction,
    dispute_transaction,
    get_confirmed_weekly_collection_data,
)

router = APIRouter(
    prefix="/api/transactions",
    tags=["Collection Transactions"],
)


class HouseholdDecisionRequest(BaseModel):
    household_id: str = Field(min_length=1)


@router.post(
    "",
    response_model=CollectionTransactionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_transaction(
    payload: CollectionTransactionCreate,
    database=Depends(get_auth_db),
    user=Depends(require_roles("collector", "trader", "admin")),
):
    if user["role"] == "admin" and not has_permissions(
        user, "transactions:create"
    ):
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    try:
        pickup = database["pickup_requests"].find_one(
            {"request_id": payload.request_id}
        )
        if pickup is None:
            raise HTTPException(status_code=404, detail="Pickup request not found")
        if (
            payload.household_id != pickup.get("household_id")
            or payload.locality_id != pickup.get("locality_id")
        ):
            raise HTTPException(
                status_code=403,
                detail="Transaction ownership must match the pickup request.",
            )
        if pickup.get("status") != "pending":
            raise HTTPException(status_code=409, detail="Pickup request is not pending")

        collector = database["users"].find_one({
            "user_id": payload.collector_id,
            "role": "collector",
            "status": "active",
            "phone_verified": True,
        })
        if collector is None:
            raise HTTPException(status_code=403, detail="Collector is not authorized")
        if pickup.get("assigned_collector_id") != collector["user_id"]:
            raise HTTPException(status_code=403, detail="Collector is not assigned to this pickup")
        if payload.recorded_by_user_id != user["user_id"]:
            raise HTTPException(
                status_code=403,
                detail="Recorder must match the authenticated account.",
            )

        if user["role"] == "collector":
            if (
                collector["user_id"] != user["user_id"]
                or payload.entry_mode != "collector_self"
            ):
                raise HTTPException(status_code=403, detail="Collector identity mismatch")
        elif user["role"] == "trader":
            if (
                collector.get("invited_by_user_id") != user["user_id"]
                or payload.entry_mode != "staff_on_behalf"
            ):
                raise HTTPException(status_code=403, detail="Collector is not in this trader's team")
        elif payload.entry_mode != "staff_on_behalf":
            raise HTTPException(status_code=403, detail="Invalid administrative entry mode")

        transaction_id = str(uuid4())
        transaction_payload = payload.model_copy(update={
            "household_id": pickup["household_id"],
            "locality_id": pickup["locality_id"],
            "collector_id": collector["user_id"],
            "recorded_by_user_id": user["user_id"],
            "entry_mode": (
                "collector_self"
                if user["role"] == "collector"
                else "staff_on_behalf"
            ),
        })

        def claim_and_insert(session):
            claim = database["pickup_requests"].update_one(
                {
                    "request_id": payload.request_id,
                    "status": "pending",
                    "household_id": pickup["household_id"],
                    "locality_id": pickup["locality_id"],
                    "assigned_collector_id": collector["user_id"],
                    "collection_transaction_id": {"$exists": False},
                },
                {"$set": {"collection_transaction_id": transaction_id}},
                session=session,
            )
            if claim.matched_count != 1:
                raise HTTPException(
                    status_code=409,
                    detail="Pickup request is no longer available for a collection transaction.",
                )

            return create_claimed_collection_transaction(
                database["collection_transactions"],
                transaction_payload,
                session=session,
                transaction_id=transaction_id,
            )

        with database.client.start_session() as session:
            return session.with_transaction(claim_and_insert)

    except HTTPException:
        raise
    except DuplicateKeyError as error:
        raise HTTPException(
            status_code=409,
            detail="A collection transaction already exists for this pickup.",
        ) from error
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Database operation failed.",
        ) from error


@router.get("/my")
def list_my_transactions(
    database=Depends(get_auth_db),
    household=Depends(require_roles("household")),
):
    try:
        return list(
            database["collection_transactions"].find(
                {"household_id": household["user_id"]},
                {"_id": 0},
            ).sort("weighed_at", -1)
        )
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve collection transactions.",
        ) from error


@router.post("/{transaction_id}/confirm")
def confirm_household_transaction(
    transaction_id: str,
    payload: HouseholdDecisionRequest,
    database=Depends(get_auth_db),
    household=Depends(require_roles("household")),
):
    if payload.household_id != household["user_id"]:
        raise HTTPException(status_code=403, detail="Household identity mismatch")

    try:
        transaction = database["collection_transactions"].find_one({
            "transaction_id": transaction_id,
        })
        if transaction is None or transaction.get("household_id") != household["user_id"]:
            raise HTTPException(status_code=404, detail="Transaction not found")

        confirm_transaction(
            database["collection_transactions"],
            transaction_id,
            household["user_id"],
        )

        return {
            "message": "Transaction confirmed successfully.",
            "transaction_id": transaction_id,
            "transaction_status": "confirmed",
        }

    except HTTPException:
        raise
    except ValueError as error:
        raise HTTPException(
            status_code=409,
            detail=str(error),
        ) from error

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Database operation failed.",
        ) from error


@router.post("/{transaction_id}/dispute")
def dispute_household_transaction(
    transaction_id: str,
    payload: HouseholdDecisionRequest,
    database=Depends(get_auth_db),
    household=Depends(require_roles("household")),
):
    if payload.household_id != household["user_id"]:
        raise HTTPException(status_code=403, detail="Household identity mismatch")

    try:
        transaction = database["collection_transactions"].find_one({
            "transaction_id": transaction_id,
        })
        if transaction is None or transaction.get("household_id") != household["user_id"]:
            raise HTTPException(status_code=404, detail="Transaction not found")

        dispute_transaction(
            database["collection_transactions"],
            transaction_id,
            household["user_id"],
        )

        return {
            "message": "Transaction disputed successfully.",
            "transaction_id": transaction_id,
            "transaction_status": "disputed",
        }

    except HTTPException:
        raise
    except ValueError as error:
        raise HTTPException(
            status_code=409,
            detail=str(error),
        ) from error

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Database operation failed.",
        ) from error


@router.get("/confirmed-weekly")
def get_weekly_forecasting_data(
    database=Depends(get_auth_db),
    admin=Depends(require_roles("admin")),
):
    if not has_permissions(admin, "transactions:read_all"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    try:
        return get_confirmed_weekly_collection_data(
            database["collection_transactions"]
        )

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve forecasting data.",
        ) from error
