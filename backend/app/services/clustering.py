
"""
ScrapWise - DBSCAN Collaborative Pickup Clustering

Groups pending household pickup requests according to:
1. Locality
2. Preferred pickup date
3. Preferred time slot
4. Geographic proximity

Coordinates are processed using the Haversine distance metric.
"""

from pathlib import Path

import numpy as np
import pandas as pd

from sklearn.cluster import DBSCAN


# --------------------------------------------------
# CONFIGURATION
# --------------------------------------------------

EARTH_RADIUS_METRES = 6_371_000

DEFAULT_RADIUS_METRES = 500
DEFAULT_MIN_SAMPLES = 2

REQUIRED_COLUMNS = [
    "request_id",
    "locality_id",
    "latitude",
    "longitude",
    "preferred_date",
    "preferred_time_slot",
]


# --------------------------------------------------
# MAIN CLUSTERING FUNCTION
# --------------------------------------------------

def cluster_pickup_requests(
    requests: pd.DataFrame,
    eps_metres: float = DEFAULT_RADIUS_METRES,
    min_samples: int = DEFAULT_MIN_SAMPLES,
):
    """
    Returns:
        assignments: One record per eligible pickup request.
        summaries: One record per detected cluster.

    Only pending requests are included when a status
    column is supplied.
    """

    if eps_metres <= 0:
        raise ValueError("eps_metres must be positive.")

    if min_samples < 2:
        raise ValueError("min_samples must be at least 2.")

    missing_columns = [
        col for col in REQUIRED_COLUMNS
        if col not in requests.columns
    ]

    if missing_columns:
        raise ValueError(
            f"Missing required columns: {missing_columns}"
        )

    df = requests.copy()

    # Each request must have a unique identifier.
    if df["request_id"].isna().any():
        raise ValueError("Request IDs cannot be missing.")

    if df["request_id"].duplicated().any():
        raise ValueError("Duplicate request IDs found.")

    # Include pending requests only.
    if "status" in df.columns:
        df = df[
            df["status"].astype(str).str.lower() == "pending"
        ].copy()

    # Convert coordinates to numeric values.
    df["latitude"] = pd.to_numeric(
        df["latitude"], errors="coerce"
    )

    df["longitude"] = pd.to_numeric(
        df["longitude"], errors="coerce"
    )

    assignments = []

    # Requests without valid coordinates cannot be clustered.
    valid_mask = (
        df["latitude"].between(-90, 90)
        & df["longitude"].between(-180, 180)
    )

    invalid = df[~valid_mask]

    for _, row in invalid.iterrows():
        assignments.append({
            "request_id": row["request_id"],
            "locality_id": row["locality_id"],
            "preferred_date": row["preferred_date"],
            "preferred_time_slot": row["preferred_time_slot"],
            "latitude": row["latitude"],
            "longitude": row["longitude"],
            "cluster_id": None,
            "cluster_status": "missing_or_invalid_coordinates",
        })

    valid = df[valid_mask].copy()

    # Convert the 500-metre radius into radians.
    eps_radians = eps_metres / EARTH_RADIUS_METRES

    # --------------------------------------------------
    # GROUP BY COMPATIBLE PICKUP WINDOWS
    # --------------------------------------------------

    grouping_columns = [
        "locality_id",
        "preferred_date",
        "preferred_time_slot",
    ]

    for group_key, group in valid.groupby(
        grouping_columns,
        sort=True,
        dropna=False,
    ):

        locality, date, time_slot = group_key

        # DBSCAN Haversine requires latitude and longitude
        # in radians, in that exact order.
        coordinates = np.radians(
            group[["latitude", "longitude"]].to_numpy()
        )

        model = DBSCAN(
            eps=eps_radians,
            min_samples=min_samples,
            metric="haversine",
            algorithm="ball_tree",
        )

        labels = model.fit_predict(coordinates)

        # --------------------------------------------------
        # SAVE INDIVIDUAL REQUEST ASSIGNMENTS
        # --------------------------------------------------

        for (_, row), label in zip(group.iterrows(), labels):

            if label == -1:
                cluster_id = None
                cluster_status = "noise"

            else:
                locality_key = str(locality).replace(" ", "_")

                date_key = pd.to_datetime(
                    date
                ).strftime("%Y%m%d")

                time_key = str(time_slot)

                cluster_id = (
                    f"{locality_key}_{date_key}_"
                    f"{time_key}_C{label + 1}"
                )

                cluster_status = "clustered"

            assignments.append({
                "request_id": row["request_id"],
                "locality_id": locality,
                "preferred_date": date,
                "preferred_time_slot": time_slot,
                "latitude": row["latitude"],
                "longitude": row["longitude"],
                "cluster_id": cluster_id,
                "cluster_status": cluster_status,
            })

    assignment_df = pd.DataFrame(assignments)

    # --------------------------------------------------
    # BUILD CLUSTER SUMMARIES
    # --------------------------------------------------

    summaries = []

    clustered = assignment_df[
        assignment_df["cluster_status"] == "clustered"
    ]

    for cluster_id, group in clustered.groupby("cluster_id"):

        summaries.append({
            "cluster_id": cluster_id,
            "locality_id": group["locality_id"].iloc[0],
            "preferred_date": group["preferred_date"].iloc[0],
            "preferred_time_slot": (
                group["preferred_time_slot"].iloc[0]
            ),
            "request_ids": ";".join(
                group["request_id"].astype(str)
            ),
            "number_of_requests": len(group),
            "centre_latitude": group["latitude"].mean(),
            "centre_longitude": group["longitude"].mean(),
        })

    summary_df = pd.DataFrame(summaries)

    return assignment_df, summary_df


# --------------------------------------------------
# TEST THE MODULE WITH SAMPLE DATA
# --------------------------------------------------

def main():

    project_root = Path(__file__).resolve().parents[3]

    input_path = (
        project_root
        / "ml"
        / "scrap_forecasting"
        / "data"
        / "raw"
        / "sample_pickup_requests.csv"
    )

    output_dir = (
        project_root
        / "ml"
        / "scrap_forecasting"
        / "data"
        / "processed"
    )

    output_dir.mkdir(parents=True, exist_ok=True)

    if not input_path.exists():
        raise FileNotFoundError(
            f"Sample dataset not found: {input_path}"
        )

    requests = pd.read_csv(input_path)

    assignments, summaries = cluster_pickup_requests(
        requests,
        eps_metres=500,
        min_samples=2,
    )

    assignments_path = (
        output_dir / "dbscan_assignments.csv"
    )

    summary_path = (
        output_dir / "dbscan_cluster_summary.csv"
    )

    assignments.to_csv(assignments_path, index=False)
    summaries.to_csv(summary_path, index=False)

    print("\n========== SCRAPWISE DBSCAN RESULTS ==========\n")

    print("Total pending requests:", len(assignments))

    print("Clusters identified:", len(summaries))

    if not summaries.empty:
        print("\nCLUSTER DETAILS:")

        for _, cluster in summaries.iterrows():

            print(
                f"\nCluster: {cluster['cluster_id']}"
            )

            print(
                "Requests:",
                cluster["request_ids"]
            )

            print(
                "Number of requests:",
                cluster["number_of_requests"]
            )

    noise_count = (
        assignments["cluster_status"] == "noise"
    ).sum()

    print("\nNoise requests:", noise_count)

    invalid_count = (
        assignments["cluster_status"]
        == "missing_or_invalid_coordinates"
    ).sum()

    print("Invalid-coordinate requests:", invalid_count)

    print("\nAssignment file:", assignments_path)
    print("Summary file:", summary_path)

    print("\nDBSCAN execution completed successfully!")


if __name__ == "__main__":
    main()
