
from datetime import date
from pydantic import BaseModel, Field, field_validator


class PickupRequestCreate(BaseModel):
    household_id: str = Field(min_length=1)
    locality_id: str = Field(min_length=1)

    # Household's pickup location
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)

    # Preferred collection schedule
    preferred_date: date
    preferred_time_slot: str = Field(min_length=1)

    # Materials available for collection
    # Household does NOT enter estimated weight.
    materials: list[str] = Field(min_length=1)

    notes: str | None = Field(default=None, max_length=500)

    @field_validator("materials")
    @classmethod
    def validate_materials(cls, materials):
        cleaned = list(dict.fromkeys(
            item.strip().lower()
            for item in materials
            if item.strip()
        ))

        if not cleaned:
            raise ValueError("At least one valid material is required.")

        return cleaned


class PickupAssignmentRequest(BaseModel):
    collector_id: str = Field(min_length=1, max_length=128)


class PickupRequestResponse(BaseModel):
    request_id: str
    household_id: str
    locality_id: str
    latitude: float
    longitude: float
    preferred_date: date
    preferred_time_slot: str
    materials: list[str]
    notes: str | None = None
    status: str
