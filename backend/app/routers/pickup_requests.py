
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from pymongo.errors import PyMongoError

from ..auth.dependencies import get_auth_db, has_permissions, require_roles
from ..schemas.pickup_request import (
    PickupAssignmentRequest,
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
def create_request(
    payload: PickupRequestCreate,
    database=Depends(get_auth_db),
    household=Depends(require_roles("household")),
):
    if payload.household_id != household["user_id"]:
        raise HTTPException(
            status_code=403,
            detail="Pickup household must match the authenticated account.",
        )

    try:
        return create_pickup_request(
            database["pickup_requests"],
            payload.model_copy(update={"household_id": household["user_id"]}),
        )
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not save pickup request.",
        ) from error


# 2. HOUSEHOLD PICKUP HISTORY

@router.get("/my")
def list_my_requests(
    database=Depends(get_auth_db),
    household=Depends(require_roles("household")),
):
    try:
        return list(
            database["pickup_requests"].find(
                {"household_id": household["user_id"]},
                {"_id": 0},
            ).sort("created_at", -1)
        )
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve pickup requests.",
        ) from error


# 3. GET ASSIGNED PENDING REQUESTS

@router.get("/pending")
def list_pending_requests(
    database=Depends(get_auth_db),
    user=Depends(require_roles("collector", "trader", "admin")),
):
    try:
        filters = {}
        if user["role"] == "collector":
            filters["assigned_collector_id"] = user["user_id"]
        elif user["role"] == "trader":
            collector_ids = [
                collector["user_id"]
                for collector in database["users"].find(
                    {
                        "role": "collector",
                        "status": "active",
                        "phone_verified": True,
                        "invited_by_user_id": user["user_id"],
                    },
                    {"user_id": 1, "_id": 0},
                )
            ]
            filters["assigned_collector_id"] = {"$in": collector_ids}
        elif not has_permissions(user, "pickups:read_all"):
            raise HTTPException(status_code=403, detail="Insufficient permissions")

        return get_pending_pickup_requests(
            database["pickup_requests"],
            filters,
        )
    except HTTPException:
        raise
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not retrieve pickup requests.",
        ) from error


# 4. ASSIGN PICKUP TO COLLECTOR

@router.post("/{request_id}/assignment")
def assign_pickup(
    request_id: str,
    payload: PickupAssignmentRequest,
    database=Depends(get_auth_db),
    user=Depends(require_roles("trader", "admin")),
):
    if user["role"] == "admin" and not has_permissions(user, "pickups:assign"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    try:
        pickup = database["pickup_requests"].find_one(
            {"request_id": request_id}
        )
        if pickup is None:
            raise HTTPException(status_code=404, detail="Pickup request not found")
        if pickup.get("status") != "pending":
            raise HTTPException(status_code=409, detail="Pickup request is not pending")
        if (
            "collection_transaction_id" in pickup
            or database["collection_transactions"].find_one(
                {"request_id": request_id},
                {"_id": 1},
            )
        ):
            raise HTTPException(
                status_code=409,
                detail="Pickup already has a collection transaction.",
            )

        existing_collector_id = pickup.get("assigned_collector_id")
        if user["role"] == "trader" and existing_collector_id:
            existing_collector = database["users"].find_one({
                "user_id": existing_collector_id,
                "role": "collector",
                "status": "active",
            })
            if (
                existing_collector is None
                or existing_collector.get("invited_by_user_id") != user["user_id"]
            ):
                raise HTTPException(
                    status_code=403,
                    detail="Pickup is assigned outside this trader's team",
                )

        collector = database["users"].find_one({
            "user_id": payload.collector_id,
            "role": "collector",
            "status": "active",
            "phone_verified": True,
        })
        if collector is None:
            raise HTTPException(status_code=404, detail="Active collector not found")
        if (
            user["role"] == "trader"
            and collector.get("invited_by_user_id") != user["user_id"]
        ):
            raise HTTPException(status_code=403, detail="Collector is not in this trader's team")

        assignment_filter = {
            "request_id": request_id,
            "status": "pending",
            "collection_transaction_id": {"$exists": False},
        }
        observed_values = []
        for field in ("assigned_collector_id", "assigned_by_user_id"):
            present = field in pickup
            assignment_filter[field] = {"$exists": present}
            if present:
                # Compare the whole value, including null or legacy array values.
                observed_values.append(
                    {"$eq": [f"${field}", {"$literal": pickup[field]}]}
                )
        if observed_values:
            assignment_filter["$expr"] = {"$and": observed_values}

        result = database["pickup_requests"].update_one(
            assignment_filter,
            {"$set": {
                "assigned_collector_id": collector["user_id"],
                "assigned_by_user_id": user["user_id"],
            }},
        )
        if not result.matched_count:
            raise HTTPException(status_code=409, detail="Pickup assignment changed")
        return {
            "message": "Pickup assigned",
            "request_id": request_id,
            "collector_id": collector["user_id"],
        }
    except HTTPException:
        raise
    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="Could not assign pickup request.",
        ) from error


# 5. DBSCAN CLUSTERING

@router.post("/cluster")
def cluster_pending_requests(
    payload: ClusterRunRequest,
    database=Depends(get_auth_db),
    admin=Depends(require_roles("admin")),
):
    if not has_permissions(admin, "pickups:cluster"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    try:
        return generate_pickup_clusters(
            database["pickup_requests"],
            database["pickup_clusters"],
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


# 6. PICKUP DEMAND HEATMAP

@router.get("/heatmap")
def get_pickup_heatmap(
    pickup_date: date | None = Query(default=None),
    time_slot: str | None = Query(default=None),
    locality_id: str | None = Query(default=None),
    database=Depends(get_auth_db),
    admin=Depends(require_roles("admin")),
):
    if not has_permissions(admin, "pickups:read_all"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    query = {
        "status": "pending",
        "collection_transaction_id": {"$exists": False},
    }

    if pickup_date:
        query["preferred_date"] = pickup_date.isoformat()

    if time_slot:
        query["preferred_time_slot"] = time_slot

    if locality_id:
        query["locality_id"] = locality_id

    try:
        documents = database["pickup_requests"].find(
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


# 7. BALLARI LOCALITY REFERENCE

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
