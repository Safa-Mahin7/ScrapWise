
from pathlib import Path
import json

import numpy as np
import pandas as pd


# --------------------------------------------------
# 1. PROJECT SETTINGS
# --------------------------------------------------

SEED = 42
N_PICKUP_REQUESTS = 5000

N_LOCALITIES = 12
N_WEEKS = 104

AS_OF_DATE = pd.Timestamp("2026-11-07")

PROJECT_DIR = Path(__file__).resolve().parent
DATA_DIR = PROJECT_DIR / "data"

SYNTHETIC_DIR = DATA_DIR / "synthetic"
SYNTHETIC_DIR.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(SEED)


# Standard ScrapWise material identifiers
MATERIALS = [
    "newspaper",
    "old_books",
    "cardboard",
    "PET_plastic",
    "mixed_plastic",
    "iron",
    "steel",
    "aluminium",
    "copper",
    "glass",
    "clothes",
    "other",
]

LOCALITIES = [
    f"DEMO_AREA_{i:02d}"
    for i in range(1, N_LOCALITIES + 1)
]

COLLECTORS = [
    f"DEMO_COLLECTOR_{i:03d}"
    for i in range(1, 31)
]

TIME_SLOTS = ["morning", "afternoon", "evening"]


# --------------------------------------------------
# 2. SYNTHETIC LOCALITY COORDINATES
# --------------------------------------------------

# These are fictional coordinate clusters for testing.
# They are NOT actual Ballari locality locations.

LOCALITY_CENTERS = {}

for i, locality in enumerate(LOCALITIES):
    row = i // 4
    column = i % 4

    center_lat = 15.10 + (row * 0.035)
    center_lon = 76.90 + (column * 0.035)

    LOCALITY_CENTERS[locality] = (
        center_lat,
        center_lon
    )


# --------------------------------------------------
# 3. GENERATE 5,000 PICKUP REQUESTS
# --------------------------------------------------

def generate_pickup_requests():

    records = []

    household_ids = [
        f"DEMO_HOUSE_{i:04d}"
        for i in range(1, 1801)
    ]

    for i in range(1, N_PICKUP_REQUESTS + 1):

        locality = rng.choice(LOCALITIES)

        center_lat, center_lon = (
            LOCALITY_CENTERS[locality]
        )

        # Small random movement around a demo centre
        latitude = center_lat + rng.normal(0, 0.00065)
        longitude = center_lon + rng.normal(0, 0.00065)

        household_id = rng.choice(household_ids)

        number_of_materials = int(
            rng.choice([1, 2, 3], p=[0.55, 0.30, 0.15])
        )

        selected_materials = rng.choice(
            MATERIALS,
            size=number_of_materials,
            replace=False
        )

        preferred_date = (
            AS_OF_DATE
            + pd.Timedelta(days=int(rng.integers(0, 30)))
        )

        created_at = (
            preferred_date
            - pd.Timedelta(days=int(rng.integers(1, 8)))
        )

        status = rng.choice(
            ["pending", "assigned"],
            p=[0.70, 0.30]
        )

        assignment_preference = rng.choice(
            ["selected", "automatic"],
            p=[0.40, 0.60]
        )

        selected_collector = ""

        if status == "assigned" or assignment_preference == "selected":
            selected_collector = str(rng.choice(COLLECTORS))

        records.append({
            "request_id": f"SYN_REQ_{i:05d}",
            "household_id": household_id,
            "locality_id": locality,
            "requested_materials": ";".join(selected_materials),
            "preferred_date": preferred_date.strftime("%Y-%m-%d"),
            "preferred_time_slot": str(rng.choice(TIME_SLOTS)),
            "latitude": round(latitude, 6),
            "longitude": round(longitude, 6),
            "address": f"SYNTHETIC_LOCATION_{locality}",
            "assignment_preference": assignment_preference,
            "selected_kabadiwala_id": selected_collector,
            "status": str(status),
            "created_at": created_at.isoformat(),
            "data_source": "synthetic",
            "coordinate_type": "synthetic_demo"
        })

    return pd.DataFrame(records)


# --------------------------------------------------
# 4. SYNTHETIC MATERIAL SCENARIO PARAMETERS
# --------------------------------------------------

# These are adjustable simulation assumptions,
# NOT measured Ballari collection statistics.

MATERIAL_PROFILES = {
    "newspaper":    (0.62, 0.55, 0.12),
    "old_books":    (0.25, 0.30, 0.10),
    "cardboard":    (0.48, 0.45, 0.13),
    "PET_plastic":  (0.42, 0.14, 0.10),
    "mixed_plastic":(0.32, 0.16, 0.12),
    "iron":         (0.15, 0.28, 0.08),
    "steel":        (0.12, 0.20, 0.08),
    "aluminium":    (0.08, 0.05, 0.08),
    "copper":       (0.04, 0.015, 0.08),
    "glass":        (0.15, 0.18, 0.10),
    "clothes":      (0.25, 0.20, 0.15),
    "other":        (0.10, 0.08, 0.10),
}


# --------------------------------------------------
# 5. GENERATE 14,976 WEEKLY RECORDS
# --------------------------------------------------

def generate_weekly_records():

    weeks = pd.date_range(
        start="2024-11-04",
        periods=N_WEEKS,
        freq="W-MON"
    )

    records = []

    for locality in LOCALITIES:

        base_participation = int(
            rng.integers(25, 101)
        )

        locality_multiplier = rng.uniform(0.75, 1.35)
        locality_phase = rng.uniform(0, 2 * np.pi)

        for week_index, week_start in enumerate(weeks):

            participation_variation = (
                1
                + 0.10 * np.sin(
                    2 * np.pi * week_index / 26
                    + locality_phase
                )
                + rng.normal(0, 0.06)
            )

            participating_households = max(
                5,
                int(round(
                    base_participation
                    * participation_variation
                ))
            )

            for material in MATERIALS:

                participation_probability, kg_per_household, amplitude = (
                    MATERIAL_PROFILES[material]
                )

                contributors = int(
                    rng.binomial(
                        participating_households,
                        participation_probability
                    )
                )

                seasonality = (
                    1
                    + amplitude * np.sin(
                        2 * np.pi * week_index / 52
                        + locality_phase
                    )
                )

                gradual_trend = (
                    1 + 0.12 * week_index / (N_WEEKS - 1)
                )

                random_variation = rng.lognormal(
                    mean=-(0.25 ** 2) / 2,
                    sigma=0.25
                )

                collected_kg = (
                    contributors
                    * kg_per_household
                    * locality_multiplier
                    * seasonality
                    * gradual_trend
                    * random_variation
                )

                # Simulate occasional weeks without a collection
                if rng.random() < 0.02:
                    collected_kg = 0
                    contributors = 0

                transactions = int(
                    rng.binomial(contributors, 0.85)
                )

                records.append({
                    "locality_id": locality,
                    "material_type": material,
                    "week_start_date": week_start.strftime("%Y-%m-%d"),
                    "actual_collected_kg": round(
                        float(collected_kg), 2
                    ),
                    "participating_households_count": contributors,
                    "confirmed_transaction_count": transactions,
                    "data_source": "synthetic"
                })

    return pd.DataFrame(records)


# --------------------------------------------------
# 6. CREATE HISTORICAL ML FEATURES
# --------------------------------------------------

def add_forecasting_features(df):

    df = df.sort_values(
        ["locality_id", "material_type", "week_start_date"]
    ).reset_index(drop=True)

    group_columns = ["locality_id", "material_type"]

    grouped = df.groupby(group_columns, sort=False)

    date_values = pd.to_datetime(df["week_start_date"])

    df["week_of_year"] = (
        date_values.dt.isocalendar().week.astype(int)
    )

    df["month"] = date_values.dt.month

    for lag in [1, 2, 4]:
        df[f"qty_lag_{lag}_week_kg"] = (
            grouped["actual_collected_kg"].shift(lag)
        )

    df["avg_qty_last_4_weeks_kg"] = (
        grouped["actual_collected_kg"].transform(
            lambda s: s.shift(1).rolling(
                window=4,
                min_periods=4
            ).mean()
        )
    )

    df["participating_households_last_4_weeks"] = (
        grouped["participating_households_count"].transform(
            lambda s: s.shift(1).rolling(
                window=4,
                min_periods=4
            ).mean()
        )
    )

    def calculate_days_since_collection(series):

        values = series.to_numpy(dtype=float)
        result = np.full(len(values), np.nan)

        last_collection_index = None

        for i, value in enumerate(values):

            if last_collection_index is not None:
                result[i] = (
                    i - last_collection_index
                ) * 7

            if value > 0:
                last_collection_index = i

        return pd.Series(result, index=series.index)

    df["days_since_last_collection"] = (
        grouped["actual_collected_kg"].transform(
            calculate_days_since_collection
        )
    )

    # Target is the actual quantity collected during
    # the seven-day week identified by week_start_date.
    # All input features use only earlier weeks.

    df["next_7_days_confirmed_collection_kg"] = (
        df["actual_collected_kg"]
    )

    return df


# --------------------------------------------------
# 7. RUN GENERATION AND SAVE FILES
# --------------------------------------------------

def main():

    print("\nGenerating synthetic pickup requests...")

    pickup_df = generate_pickup_requests()

    pickup_path = (
        SYNTHETIC_DIR / "pickup_requests_5000.csv"
    )

    pickup_df.to_csv(pickup_path, index=False)

    print("Pickup requests:", len(pickup_df))

    print("\nGenerating synthetic weekly collection data...")

    weekly_df = generate_weekly_records()

    weekly_df = add_forecasting_features(weekly_df)

    weekly_path = (
        SYNTHETIC_DIR / "weekly_forecasting_14976.csv"
    )

    weekly_df.to_csv(weekly_path, index=False)

    print("Weekly records:", len(weekly_df))

    feature_columns = [
        "qty_lag_1_week_kg",
        "qty_lag_2_week_kg",
        "qty_lag_4_week_kg",
        "avg_qty_last_4_weeks_kg",
        "participating_households_last_4_weeks",
        "days_since_last_collection"
    ]

    model_ready_rows = weekly_df.dropna(
        subset=feature_columns
    )

    metadata = {
        "project": "ScrapWise",
        "version": "1.0",
        "random_seed": SEED,
        "data_classification": "synthetic",
        "pickup_request_records": len(pickup_df),
        "weekly_records": len(weekly_df),
        "model_ready_feature_rows": len(model_ready_rows),
        "localities": N_LOCALITIES,
        "materials": len(MATERIALS),
        "weeks_per_locality_material": N_WEEKS,
        "survey_169_responses_included": False,
        "survey_note": (
            "Keep the original 169 actual survey responses "
            "as a separate source. They must not be replaced "
            "or falsely labelled as synthetic collection weights."
        ),
        "coordinate_note": (
            "Coordinates are fictional demo points, "
            "not real Ballari household locations."
        ),
        "forecasting_note": (
            "Synthetic data is for pipeline development "
            "and testing, not proof of real-world accuracy."
        ),
        "generation_assumptions": MATERIAL_PROFILES
    }

    metadata_path = (
        SYNTHETIC_DIR / "synthetic_data_metadata.json"
    )

    with open(metadata_path, "w", encoding="utf-8") as file:
        json.dump(metadata, file, indent=4)

    # Basic data-quality checks
    assert pickup_df["request_id"].is_unique
    assert len(pickup_df) == N_PICKUP_REQUESTS

    assert not weekly_df.duplicated(
        ["locality_id", "material_type", "week_start_date"]
    ).any()

    assert len(weekly_df) == (
        N_LOCALITIES * len(MATERIALS) * N_WEEKS
    )

    assert (
        weekly_df["actual_collected_kg"] >= 0
    ).all()

    print("\n-------------------------------------")
    print("SCRAPWISE DATA GENERATION COMPLETED")
    print("-------------------------------------")
    print("Pickup records:", len(pickup_df))
    print("Weekly records:", len(weekly_df))
    print("Model-ready rows:", len(model_ready_rows))
    print("Unique pickup IDs:", pickup_df["request_id"].nunique())
    print("Data source: SYNTHETIC")
    print("Output folder:", SYNTHETIC_DIR)
    print("-------------------------------------")


if __name__ == "__main__":
    main()
