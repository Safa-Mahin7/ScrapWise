
from pathlib import Path
import json

import joblib
import numpy as np
import pandas as pd

from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.impute import SimpleImputer
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder


# --------------------------------------------------
# PATHS AND CONFIGURATION
# --------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parents[2]

DATA_PATH = (
    PROJECT_ROOT
    / "ml/scrap_forecasting/data/synthetic"
    / "weekly_forecasting_14976.csv"
)

MODEL_DIR = PROJECT_ROOT / "ml/scrap_forecasting/models"
EVALUATION_DIR = PROJECT_ROOT / "ml/scrap_forecasting/evaluation"

TARGET = "next_7_days_confirmed_collection_kg"

LAG_COLUMNS = [
    "qty_lag_1_week_kg",
    "qty_lag_2_week_kg",
    "qty_lag_4_week_kg",
    "avg_qty_last_4_weeks_kg",
]

NUMERIC_FEATURES = [
    *LAG_COLUMNS,
    "participating_households_last_4_weeks",
    "days_since_last_collection",
    "week_sin",
    "week_cos",
    "month",
]

CATEGORICAL_FEATURES = [
    "locality_id",
    "material_type",
]


# --------------------------------------------------
# LOAD AND VALIDATE DATA
# --------------------------------------------------

def load_data():

    if not DATA_PATH.exists():
        raise FileNotFoundError(
            f"Forecasting dataset not found: {DATA_PATH}"
        )

    df = pd.read_csv(DATA_PATH)

    required = [
        "locality_id",
        "material_type",
        "week_start_date",
        "actual_collected_kg",
        "data_source",
        "week_of_year",
        "month",
        *LAG_COLUMNS,
        "participating_households_last_4_weeks",
        "days_since_last_collection",
        TARGET,
    ]

    missing = [col for col in required if col not in df.columns]

    if missing:
        raise ValueError(f"Missing columns: {missing}")

    df["week_start_date"] = pd.to_datetime(
        df["week_start_date"],
        errors="coerce",
    )

    numeric_columns = [
        "actual_collected_kg",
        "week_of_year",
        "month",
        *LAG_COLUMNS,
        "participating_households_last_4_weeks",
        "days_since_last_collection",
        TARGET,
    ]

    for col in numeric_columns:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    df = df.dropna(
        subset=["week_start_date", TARGET, "week_of_year"]
    ).copy()

    # Cyclical encoding for seasonal week patterns.
    df["week_sin"] = np.sin(
        2 * np.pi * df["week_of_year"] / 52
    )

    df["week_cos"] = np.cos(
        2 * np.pi * df["week_of_year"] / 52
    )

    df["locality_id"] = df["locality_id"].astype(str)
    df["material_type"] = df["material_type"].astype(str)

    # Keep rows with the necessary historical lag features.
    # Missing days_since_last_collection will be imputed.
    df = df.dropna(subset=LAG_COLUMNS).copy()

    if df.empty:
        raise ValueError("No usable historical records remain.")

    # Confirm that we have one row per locality/material/week.
    duplicate_count = df.duplicated(
        subset=["locality_id", "material_type", "week_start_date"]
    ).sum()

    if duplicate_count:
        raise ValueError(
            f"Found {duplicate_count} duplicate locality/material/week records."
        )

    return df


# --------------------------------------------------
# MODEL EVALUATION
# --------------------------------------------------

def calculate_metrics(actual, predicted):

    return {
        "MAE": round(
            float(mean_absolute_error(actual, predicted)), 4
        ),
        "RMSE": round(
            float(np.sqrt(mean_squared_error(actual, predicted))), 4
        ),
        "R2": round(
            float(r2_score(actual, predicted)), 4
        ),
    }


# --------------------------------------------------
# TRAINING
# --------------------------------------------------

def main():

    print("\n========== SCRAPWISE FORECASTING ==========\n")

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    EVALUATION_DIR.mkdir(parents=True, exist_ok=True)

    df = load_data()

    # Inspect whether the seven-day target equals the
    # current row's actual quantity in the supplied dataset.
    target_match_rate = float(
        np.isclose(
            df[TARGET].to_numpy(),
            df["actual_collected_kg"].to_numpy(),
        ).mean()
    )

    print("Usable records:", len(df))
    print("Localities:", df["locality_id"].nunique())
    print("Materials:", df["material_type"].nunique())
    print("Target matches current actual rate:",
          round(target_match_rate * 100, 2), "%")

    sources = sorted(
        df["data_source"].dropna().astype(str).unique().tolist()
    )

    print("Data sources:", sources)

    if not set(sources).issubset({"synthetic", "real_collector_transaction"}):
        raise ValueError("Unexpected data source values found.")

    if set(sources) == {"synthetic"}:
        print(
            "NOTE: This is a synthetic-data prototype. "
            "Results are not real-world Ballari performance."
        )

    # Chronological 80/20 split.
    # The latest weeks are kept completely out of training.
    unique_dates = sorted(df["week_start_date"].unique())

    if len(unique_dates) < 5:
        raise ValueError("Not enough weekly dates for time-based evaluation.")

    split_index = int(len(unique_dates) * 0.80)
    split_index = max(1, min(split_index, len(unique_dates) - 1))

    split_date = unique_dates[split_index]

    train_df = df[df["week_start_date"] < split_date].copy()
    test_df = df[df["week_start_date"] >= split_date].copy()

    print("\nTraining records:", len(train_df))
    print("Testing records:", len(test_df))
    print("Test begins:", pd.Timestamp(split_date).date())

    if train_df.empty or test_df.empty:
        raise ValueError("Chronological split produced an empty dataset.")

    feature_columns = (
        CATEGORICAL_FEATURES + NUMERIC_FEATURES
    )

    X_train = train_df[feature_columns]
    X_test = test_df[feature_columns]

    y_train = train_df[TARGET]
    y_test = test_df[TARGET]

    # Categorical and numeric preprocessing.
    categorical_pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="most_frequent")),
        ("encoder", OneHotEncoder(handle_unknown="ignore")),
    ])

    numeric_pipeline = Pipeline([
        ("imputer", SimpleImputer(
            strategy="median",
            add_indicator=True,
        )),
    ])

    preprocessing = ColumnTransformer([
        ("categorical", categorical_pipeline, CATEGORICAL_FEATURES),
        ("numeric", numeric_pipeline, NUMERIC_FEATURES),
    ])

    # Random Forest model.
    pipeline = Pipeline([
        ("preprocessing", preprocessing),
        ("model", RandomForestRegressor(
            n_estimators=300,
            max_features=0.8,
            min_samples_leaf=2,
            random_state=42,
            n_jobs=-1,
        )),
    ])

    print("\nTraining Random Forest...")

    pipeline.fit(X_train, y_train)

    model_predictions = np.maximum(
        pipeline.predict(X_test), 0
    )

    # Previous-week quantity as a simple baseline.
    baseline_predictions = test_df[
        "qty_lag_1_week_kg"
    ].to_numpy()

    model_metrics = calculate_metrics(
        y_test, model_predictions
    )

    baseline_metrics = calculate_metrics(
        y_test, baseline_predictions
    )

    print("\n========== EVALUATION ==========\n")

    print("Previous-week baseline:", baseline_metrics)
    print("Random Forest:", model_metrics)

    # Save trained pipeline.
    model_path = MODEL_DIR / "scrap_forecasting_pipeline.joblib"
    joblib.dump(pipeline, model_path)

    # Save evaluation predictions.
    prediction_output = test_df[
        [
            "locality_id",
            "material_type",
            "week_start_date",
            TARGET,
        ]
    ].copy()

    prediction_output["previous_week_baseline_kg"] = (
        baseline_predictions
    )

    prediction_output["random_forest_prediction_kg"] = (
        model_predictions
    )

    prediction_path = (
        EVALUATION_DIR / "forecast_test_predictions.csv"
    )

    prediction_output.to_csv(
        prediction_path,
        index=False,
    )

    # Save metrics and training metadata.
    results = {
        "dataset": str(DATA_PATH.relative_to(PROJECT_ROOT)),
        "data_sources": sources,
        "synthetic_data_warning": sources == ["synthetic"],
        "target": TARGET,
        "target_matches_current_actual_percentage": round(
            target_match_rate * 100, 2
        ),
        "usable_records": len(df),
        "training_records": len(train_df),
        "testing_records": len(test_df),
        "test_start_date": str(pd.Timestamp(split_date).date()),
        "baseline_metrics": baseline_metrics,
        "random_forest_metrics": model_metrics,
        "features": feature_columns,
    }

    metrics_path = EVALUATION_DIR / "forecast_metrics.json"

    with open(metrics_path, "w", encoding="utf-8") as file:
        json.dump(results, file, indent=4)

    print("\nSaved model:", model_path)
    print("Saved predictions:", prediction_path)
    print("Saved metrics:", metrics_path)

    print("\nSCRAPWISE FORECASTING TRAINING COMPLETED!")


if __name__ == "__main__":
    main()
