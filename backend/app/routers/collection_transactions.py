
from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel, Field
from pymongo.errors import PyMongoError

from ..database import get_collection_transactions
from ..schemas.collection_transaction import (
    CollectionTransactionCreate,
    CollectionTransactionResponse,
)
from ..services.collection_service import (
    create_collection_transaction,
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
def create_transaction(payload: CollectionTransactionCreate):
    try:
        collection = get_collection_transactions()

        return create_collection_transaction(
            collection,
            payload,
        )

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Database operation failed.",
        ) from error


@router.post("/{transaction_id}/confirm")
def confirm_household_transaction(
    transaction_id: str,
    payload: HouseholdDecisionRequest,
):
    try:
        confirm_transaction(
            get_collection_transactions(),
            transaction_id,
            payload.household_id,
        )

        return {
            "message": "Transaction confirmed successfully.",
            "transaction_id": transaction_id,
            "transaction_status": "confirmed",
        }

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
):
    try:
        dispute_transaction(
            get_collection_transactions(),
            transaction_id,
            payload.household_id,
        )

        return {
            "message": "Transaction disputed successfully.",
            "transaction_id": transaction_id,
            "transaction_status": "disputed",
        }

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
def get_weekly_forecasting_data():
    try:
        return get_confirmed_weekly_collection_data(
            get_collection_transactions()
        )

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve forecasting data.",
        ) from error
