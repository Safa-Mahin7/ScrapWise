
from pathlib import Path

import pandas as pd
import matplotlib.pyplot as plt


# -----------------------------------------
# 1. FILE LOCATIONS
# -----------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parents[2]

DATA_DIR = (
    PROJECT_ROOT
    / "ml"
    / "scrap_forecasting"
    / "data"
)

SYNTHETIC_DIR = DATA_DIR / "synthetic"
PROCESSED_DIR = DATA_DIR / "processed"

assignments_path = (
    PROCESSED_DIR / "dbscan_assignments_5000.csv"
)

summary_path = (
    PROCESSED_DIR / "dbscan_cluster_summary_5000.csv"
)

output_path = (
    PROCESSED_DIR / "dbscan_map_example.png"
)


# -----------------------------------------
# 2. LOAD CLUSTER RESULTS
# -----------------------------------------

if not assignments_path.exists():
    raise FileNotFoundError(
        "Run run_clustering_5000.py first."
    )

assignments = pd.read_csv(assignments_path)
summaries = pd.read_csv(summary_path)

# Remove rows without valid coordinates
assignments = assignments.dropna(
    subset=["latitude", "longitude"]
).copy()


# -----------------------------------------
# 3. SELECT THE BUSIEST PICKUP WINDOW
# -----------------------------------------

window_counts = (
    assignments.groupby(
        ["preferred_date", "preferred_time_slot"]
    )
    .size()
    .sort_values(ascending=False)
)

selected_date, selected_slot = window_counts.index[0]

window = assignments[
    (assignments["preferred_date"] == selected_date)
    &
    (assignments["preferred_time_slot"] == selected_slot)
].copy()

print("\n========== MAP VISUALISATION ==========")

print("Selected date:", selected_date)
print("Selected time:", selected_slot)
print("Requests in this window:", len(window))


# -----------------------------------------
# 4. SEPARATE CLUSTERS AND NOISE
# -----------------------------------------

clustered = window[
    window["cluster_status"] == "clustered"
].copy()

noise = window[
    window["cluster_status"] == "noise"
].copy()

# Give each cluster a numeric plotting identifier
cluster_codes, unique_clusters = pd.factorize(
    clustered["cluster_id"],
    sort=True
)


# -----------------------------------------
# 5. GET CLUSTER CENTRES
# -----------------------------------------

window_summaries = summaries[
    (summaries["preferred_date"] == selected_date)
    &
    (summaries["preferred_time_slot"] == selected_slot)
].copy()


# -----------------------------------------
# 6. CREATE TWO-PANEL VISUALISATION
# -----------------------------------------

fig, axes = plt.subplots(
    1,
    2,
    figsize=(15, 6)
)

map_ax = axes[0]
hist_ax = axes[1]

# Plot clustered requests
if not clustered.empty:

    cmap = plt.get_cmap(
        "turbo",
        max(len(unique_clusters), 1)
    )

    map_ax.scatter(
        clustered["longitude"],
        clustered["latitude"],
        c=cluster_codes,
        cmap=cmap,
        s=35,
        alpha=0.8,
        label="Clustered requests"
    )

# Plot noise requests
if not noise.empty:

    map_ax.scatter(
        noise["longitude"],
        noise["latitude"],
        color="black",
        marker="x",
        s=55,
        label="Noise requests"
    )

# Plot cluster centres
if not window_summaries.empty:

    map_ax.scatter(
        window_summaries["centre_longitude"],
        window_summaries["centre_latitude"],
        color="red",
        marker="*",
        s=120,
        edgecolors="black",
        label="Cluster centres"
    )

map_ax.set_title(
    f"ScrapWise Pickup Clusters\n{selected_date} - {selected_slot}"
)

map_ax.set_xlabel("Longitude")
map_ax.set_ylabel("Latitude")
map_ax.legend()
map_ax.grid(alpha=0.25)


# -----------------------------------------
# 7. CLUSTER SIZE DISTRIBUTION
# -----------------------------------------

cluster_sizes = (
    clustered.groupby("cluster_id")
    .size()
)

if not cluster_sizes.empty:

    maximum_size = int(cluster_sizes.max())

    hist_ax.hist(
        cluster_sizes,
        bins=range(1, maximum_size + 2),
        align="left",
        edgecolor="black"
    )

hist_ax.set_title("Number of Requests per Cluster")
hist_ax.set_xlabel("Requests in one cluster")
hist_ax.set_ylabel("Number of clusters")
hist_ax.grid(axis="y", alpha=0.25)


# -----------------------------------------
# 8. SAVE AND DISPLAY
# -----------------------------------------

plt.tight_layout()

plt.savefig(
    output_path,
    dpi=180,
    bbox_inches="tight"
)

plt.show()

print("\nTotal clusters in selected window:",
      len(unique_clusters))

print("Grouped requests:", len(clustered))
print("Noise requests:", len(noise))

print("\nMap saved at:")
print(output_path)

print("\nVisualisation completed!")
