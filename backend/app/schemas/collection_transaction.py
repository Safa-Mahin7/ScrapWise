from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class MaterialWeight(BaseModel):
    material_type: str = Field(min_length=1)

    # Weight measured by the collector
    actual_weight_kg: float = Field(gt=0)

    # Price agreed with the household
    agreed_rate_per_kg: float = Field(ge=0)


class CollectionTransactionCreate(BaseModel):
    request_id: str
    household_id: str
    locality_id: str

    # Actual person collecting the scrap
    collector_id: str

    # Person entering the transaction
    recorded_by_user_id: str

    entry_mode: Literal[
        "collector_self",
        "staff_on_behalf"
    ]

    # Each material has its own weight and rate
    materials: list[MaterialWeight] = Field(min_length=1)

    weighed_at: datetime


class CollectionTransactionResponse(
    CollectionTransactionCreate
):
    transaction_id: str

    total_amount: float = Field(ge=0)

    transaction_status: Literal[
        "awaiting_household_confirmation",
        "confirmed",
        "disputed",
        "cancelled"
    ]

    data_source: str = "real_collector_transaction"