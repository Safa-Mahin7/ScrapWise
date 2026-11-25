
from datetime import datetime, timezone
from uuid import uuid4

import pandas as pd
from pymongo.collection import Collection

from ..schemas.pickup_request import PickupRequestCreate
from .clustering import cluster_pickup_requests


def create_pickup_request(
    collection: Collection,
    payload: PickupRequestCreate,
) -> dict:
    """Save a household pickup request."""

    data = payload.model_dump()

    # MongoDB stores dates as datetime, so keep the
    # preferred calendar date as an ISO date string.
    data["preferred_date"] = data["preferred_date"].isoformat()

    request = {
        **data,
        "request_id": str(uuid4()),
        "status": "pending",
        "cluster_id": None,
        "cluster_status": "not_processed",
        "created_at": datetime.now(timezone.utc),
        "updated_at": datetime.now(timezone.utc),
        "data_source": "real_household_request",
    }

    collection.insert_one(request)
    request.pop("_id", None)

    return request


def get_pending_pickup_requests(
    collection: Collection,
    filters: dict | None = None,
) -> list:
    """Return all pending household pickup requests."""

    query = {
        "status": "pending",
        "collection_transaction_id": {"$exists": False},
        **(filters or {}),
    }
    return list(
        collection.find(
            query,
            {"_id": 0},
        ).sort("created_at", 1)
    )


def generate_pickup_clusters(
    requests_collection: Collection,
    clusters_collection: Collection,
    eps_metres: float = 500,
    min_samples: int = 2,
) -> dict:
    """
    Cluster pending requests using the existing DBSCAN module.

    Requests are first separated by their exact material
    combinations, then DBSCAN groups them by locality,
    date, time slot and geographic proximity.
    """

    documents = get_pending_pickup_requests(requests_collection)

    if not documents:
        return {
            "message": "No pending pickup requests available.",
            "total_requests": 0,
            "total_clusters": 0,
            "assignments": [],
            "clusters": [],
        }

    df = pd.DataFrame(documents)

    # Keep requests with different material combinations separate.
    df["material_key"] = df["materials"].apply(
        lambda items: tuple(sorted(set(items)))
    )

    all_assignments = []
    all_summaries = []

    run_id = str(uuid4())
    now = datetime.now(timezone.utc)

    for bucket_number, (material_key, group) in enumerate(
        df.groupby("material_key", sort=True),
        start=1,
    ):
        clustering_input = group.drop(
            columns=["material_key"],
            errors="ignore",
        )

        assignments, summaries = cluster_pickup_requests(
            clustering_input,
            eps_metres=eps_metres,
            min_samples=min_samples,
        )

        # Save each request's clustering result.
        for record in assignments.to_dict("records"):
            cluster_id = record.get("cluster_id")

            if cluster_id:
                cluster_id = f"{cluster_id}_M{bucket_number}"

            record["cluster_id"] = cluster_id
            record["clustering_run_id"] = run_id

            requests_collection.update_one(
                {"request_id": record["request_id"]},
                {
                    "$set": {
                        "cluster_id": cluster_id,
                        "cluster_status": record["cluster_status"],
                        "clustering_run_id": run_id,
                        "clustered_at": now,
                        "updated_at": now,
                    }
                },
            )

            all_assignments.append(record)

        # Save summaries for detected clusters.
        for summary in summaries.to_dict("records"):
            summary["cluster_id"] = (
                f"{summary['cluster_id']}_M{bucket_number}"
            )

            request_ids = summary["request_ids"].split(";")

            cluster_record = {
                **summary,
                "request_ids": request_ids,
                "compatible_materials": list(material_key),
                "clustering_run_id": run_id,
                "created_at": now,
            }

            all_summaries.append(cluster_record)

    # Store the cluster summaries in MongoDB.
    if all_summaries:
        clusters_collection.insert_many(all_summaries)

    clustered_count = sum(
        item["cluster_status"] == "clustered"
        for item in all_assignments
    )

    noise_count = sum(
        item["cluster_status"] == "noise"
        for item in all_assignments
    )

    invalid_count = sum(
        item["cluster_status"] == "missing_or_invalid_coordinates"
        for item in all_assignments
    )

    return {
        "clustering_run_id": run_id,
        "total_requests": len(all_assignments),
        "total_clusters": len(all_summaries),
        "clustered_requests": clustered_count,
        "noise_requests": noise_count,
        "invalid_coordinate_requests": invalid_count,
        "assignments": all_assignments,
        "clusters": all_summaries,
    }
