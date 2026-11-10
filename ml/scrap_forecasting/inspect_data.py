
from pathlib import Path
import pandas as pd

# Locate generated datasets
PROJECT_DIR = Path(__file__).resolve().parent
DATA_DIR = PROJECT_DIR / "data" / "synthetic"

pickup_path = DATA_DIR / "pickup_requests_5000.csv"
weekly_path = DATA_DIR / "weekly_forecasting_14976.csv"

# Load datasets
pickup_df = pd.read_csv(pickup_path)
weekly_df = pd.read_csv(weekly_path)

print("\n========== SCRAPWISE DATA QUALITY REPORT ==========\n")

# ---------------------------------
# 1. PICKUP REQUEST DATASET
# ---------------------------------

print("1. PICKUP REQUEST DATASET")

print("Total records:", len(pickup_df))
print("Unique request IDs:", pickup_df["request_id"].nunique())
print("Duplicate request IDs:", pickup_df["request_id"].duplicated().sum())
print("Unique localities:", pickup_df["locality_id"].nunique())

print("\nRequest status distribution:")
print(pickup_df["status"].value_counts())

print("\nPickup time distribution:")
print(pickup_df["preferred_time_slot"].value_counts())

print("\nPickup coordinates:")
print(
    pickup_df[["latitude", "longitude"]]
    .describe()
    .round(5)
)

print("\nMissing values:")
print(pickup_df.isnull().sum())

# ---------------------------------
# 2. WEEKLY FORECASTING DATASET
# ---------------------------------

print("\n2. WEEKLY FORECASTING DATASET")

print("Total records:", len(weekly_df))

print("Unique localities:", weekly_df["locality_id"].nunique())

print("Unique materials:", weekly_df["material_type"].nunique())

print(
    "Unique weeks:",
    weekly_df["week_start_date"].nunique()
)

print(
    "\nDuplicate locality-material-week records:",
    weekly_df.duplicated(
        ["locality_id", "material_type", "week_start_date"]
    ).sum()
)

print("\nMaterial distribution:")
print(weekly_df["material_type"].value_counts())

print("\nCollection quantity statistics:")
print(
    weekly_df["actual_collected_kg"]
    .describe()
    .round(2)
)

print("\nData source distribution:")
print(weekly_df["data_source"].value_counts())

# ---------------------------------
# 3. ML FEATURE VALIDATION
# ---------------------------------

feature_columns = [
    "qty_lag_1_week_kg",
    "qty_lag_2_week_kg",
    "qty_lag_4_week_kg",
    "avg_qty_last_4_weeks_kg",
    "participating_households_last_4_weeks",
    "days_since_last_collection"
]

target_column = "next_7_days_confirmed_collection_kg"

model_ready = weekly_df.dropna(
    subset=feature_columns + [target_column]
)

print("\n3. ML MODEL READINESS")

print("Total historical records:", len(weekly_df))
print("Rows ready for modelling:", len(model_ready))
print("Rows excluded due to missing required features:",
      len(weekly_df) - len(model_ready))

print("\nFeature missing values:")
print(weekly_df[feature_columns].isnull().sum())

print("\nTarget missing values:")
print(weekly_df[target_column].isnull().sum())

print("\nNegative collection weights:",
      (weekly_df["actual_collected_kg"] < 0).sum())

print("\nSynthetic-only dataset:",
      weekly_df["data_source"].eq("synthetic").all())

print("\n========== INSPECTION COMPLETED ==========\n")
