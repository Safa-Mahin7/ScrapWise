
from pathlib import Path
import sys

import pandas as pd

# Add the main ScrapWise folder to Python's import path
PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT_ROOT))

from backend.app.services.clustering import cluster_pickup_requests


def main():

    data_dir = (
        PROJECT_ROOT
        / "ml"
        / "scrap_forecasting"
        / "data"
        / "synthetic"
    )

    output_dir = (
        PROJECT_ROOT
        / "ml"
        / "scrap_forecasting"
        / "data"
        / "processed"
    )

    input_path = data_dir / "pickup_requests_5000.csv"
    output_dir.mkdir(parents=True, exist_ok=True)

    if not input_path.exists():
        raise FileNotFoundError(
            f"Dataset not found: {input_path}"
        )

    # Load all 5,000 generated requests
    requests = pd.read_csv(input_path)

    print("\n========== SCRAPWISE: 5,000 REQUEST TEST ==========")

    print("Total requests:", len(requests))

    print(
        "Pending requests:",
        (requests["status"] == "pending").sum()
    )

    print(
        "Assigned requests excluded:",
        (requests["status"] != "pending").sum()
    )

    # Run DBSCAN on pending requests
    assignments, summaries = cluster_pickup_requests(
        requests,
        eps_metres=500,
        min_samples=2
    )

    # Save detailed assignments
    assignment_path = (
        output_dir / "dbscan_assignments_5000.csv"
    )

    assignments.to_csv(assignment_path, index=False)

    # Save cluster summaries
    summary_path = (
        output_dir / "dbscan_cluster_summary_5000.csv"
    )

    summaries.to_csv(summary_path, index=False)

    # Calculate results
    total_pending = len(assignments)

    clustered = assignments[
        assignments["cluster_status"] == "clustered"
    ]

    noise = assignments[
        assignments["cluster_status"] == "noise"
    ]

    invalid = assignments[
        assignments["cluster_status"]
        == "missing_or_invalid_coordinates"
    ]

    print("\n---------- DBSCAN RESULTS ----------")

    print("Pending requests processed:", total_pending)

    print("Clusters identified:", len(summaries))

    print("Requests grouped:", len(clustered))

    print("Noise requests:", len(noise))

    print("Invalid-coordinate requests:", len(invalid))

    print(
        "Unique processed request IDs:",
        assignments["request_id"].nunique()
    )

    # Verify every pending request is represented once
    assert total_pending == (
        requests["status"].eq("pending").sum()
    )

    assert assignments["request_id"].is_unique

    print("\n---------- LOCALITY SUMMARY ----------")

    if not summaries.empty:

        locality_summary = (
            summaries.groupby("locality_id")
            .agg(
                cluster_count=("cluster_id", "count"),
                grouped_requests=("number_of_requests", "sum")
            )
            .reset_index()
        )

        print(locality_summary.to_string(index=False))

    else:
        print("No clusters found with current parameters.")

    print("\n---------- OUTPUT FILES ----------")

    print(assignment_path)
    print(summary_path)

    print("\n5,000-request DBSCAN test completed!")


if __name__ == "__main__":
    main()
