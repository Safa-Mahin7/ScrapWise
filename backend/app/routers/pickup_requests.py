
from datetime import date

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field
from pymongo.errors import PyMongoError

from ..database import db
from ..schemas.pickup_request import (
    PickupRequestCreate,
    PickupRequestResponse,
)
from ..services.pickup_service import (
    create_pickup_request,
    get_pending_pickup_requests,
    generate_pickup_clusters,
)


router = APIRouter(
    prefix="/api/pickups",
    tags=["Pickup Requests"],
)

pickup_collection = db["pickup_requests"]
cluster_collection = db["pickup_clusters"]


# Verified locality reference points.
# These are map reference points, NOT ward boundaries.

BALLARI_LOCALITIES = [
    {
        "locality_id": "cowl_bazar",
        "locality_name": "Cowl Bazar",
        "place_type": "suburb",
        "latitude": 15.13649,
        "longitude": 76.89829,
    },
    {
        "locality_id": "bandihatti",
        "locality_name": "Bandihatti",
        "place_type": "suburb",
        "latitude": 15.13281,
        "longitude": 76.89022,
    },
    {
        "locality_id": "cantonment",
        "locality_name": "Cantonment",
        "place_type": "suburb",
        "latitude": 15.15718,
        "longitude": 76.89061,
    },
    {
        "locality_id": "havambhavi",
        "locality_name": "Havambhavi",
        "place_type": "suburb",
        "latitude": 15.17144,
        "longitude": 76.91217,
    },
    {
        "locality_id": "gandhinagara",
        "locality_name": "Gandhi Nagar",
        "place_type": "suburb",
        "latitude": 15.15795,
        "longitude": 76.93757,
    },
    {
        "locality_id": "renuka_nagar",
        "locality_name": "Renuka Nagar",
        "place_type": "suburb",
        "latitude": 15.16184,
        "longitude": 76.92708,
    },
    {
        "locality_id": "bandimot",
        "locality_name": "Bandimot",
        "place_type": "suburb",
        "latitude": 15.14005,
        "longitude": 76.94168,
    },
    {
        "locality_id": "guggarahatti",
        "locality_name": "Guggarahatti",
        "place_type": "nearby_village",
        "latitude": 15.12215,
        "longitude": 76.91029,
    },
    {
        "locality_id": "andralu",
        "locality_name": "Andralu",
        "place_type": "nearby_village",
        "latitude": 15.12344,
        "longitude": 76.93233,
    },
    {
        "locality_id": "satyanarayana_pete",
        "locality_name": "Satyanarayana Pete",
        "place_type": "locality",
        "latitude": 15.14751,
        "longitude": 76.95294,
    },
]


class ClusterRunRequest(BaseModel):
    eps_metres: float = Field(default=500, gt=0)
    min_samples: int = Field(default=2, ge=2)


# 1. CREATE PICKUP REQUEST

@router.post(
    "",
    response_model=PickupRequestResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_request(payload: PickupRequestCreate):
    try:
        return create_pickup_request(
            pickup_collection,
            payload,
        )
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not save pickup request.",
        ) from error


# 2. GET PENDING REQUESTS

@router.get("/pending")
def list_pending_requests():
    try:
        return get_pending_pickup_requests(
            pickup_collection
        )
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve pickup requests.",
        ) from error


# 3. DBSCAN CLUSTERING

@router.post("/cluster")
def cluster_pending_requests(
    payload: ClusterRunRequest,
):
    try:
        return generate_pickup_clusters(
            pickup_collection,
            cluster_collection,
            eps_metres=payload.eps_metres,
            min_samples=payload.min_samples,
        )
    except ValueError as error:
        raise HTTPException(
            status_code=400,
            detail=str(error),
        ) from error
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not generate pickup clusters.",
        ) from error


# 4. PICKUP DEMAND HEATMAP

@router.get("/heatmap")
def get_pickup_heatmap(
    pickup_date: date | None = Query(default=None),
    time_slot: str | None = Query(default=None),
    locality_id: str | None = Query(default=None),
):
    query = {"status": "pending"}

    if pickup_date:
        query["preferred_date"] = pickup_date.isoformat()

    if time_slot:
        query["preferred_time_slot"] = time_slot

    if locality_id:
        query["locality_id"] = locality_id

    try:
        documents = pickup_collection.find(
            query,
            {
                "_id": 0,
                "locality_id": 1,
                "latitude": 1,
                "longitude": 1,
                "preferred_date": 1,
                "preferred_time_slot": 1,
            },
        )

        points = []
        invalid_coordinates = 0

        for document in documents:
            try:
                latitude = float(document["latitude"])
                longitude = float(document["longitude"])
            except (KeyError, TypeError, ValueError):
                invalid_coordinates += 1
                continue

            if not (
                -90 <= latitude <= 90
                and -180 <= longitude <= 180
            ):
                invalid_coordinates += 1
                continue

            points.append({
                "locality_id": document.get("locality_id"),
                "latitude": latitude,
                "longitude": longitude,
                "intensity": 1.0,
                "preferred_date": document.get("preferred_date"),
                "preferred_time_slot": document.get(
                    "preferred_time_slot"
                ),
            })

        return {
            "map_layer": "pickup_demand",
            "data_source": "live_household_pickup_requests",
            "measure": "pending_pickup_request_count",
            "request_count": len(points),
            "invalid_coordinate_records": invalid_coordinates,
            "heatmap_points": points,
            "filters": {
                "pickup_date": (
                    pickup_date.isoformat() if pickup_date else None
                ),
                "time_slot": time_slot,
                "locality_id": locality_id,
            },
        }

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve pickup heatmap data.",
        ) from error


# 5. BALLARI LOCALITY REFERENCE

@router.get("/localities/ballari")
def get_ballari_localities():
    return {
        "city": "Ballari",
        "data_source": "OpenStreetMap locality reference points",
        "note": (
            "Reference points are not administrative boundaries. "
            "Smaller colony labels are supplied by the map layer."
        ),
        "count": len(BALLARI_LOCALITIES),
        "localities": BALLARI_LOCALITIES,
    }
