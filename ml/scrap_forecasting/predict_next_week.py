
from pathlib import Path
from datetime import timedelta

import joblib
import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[2]

DATA_PATH = ROOT / "ml/scrap_forecasting/data/synthetic/weekly_forecasting_14976.csv"
MODEL_PATH = ROOT / "ml/scrap_forecasting/models/scrap_forecasting_pipeline.joblib"
OUTPUT_PATH = ROOT / "ml/scrap_forecasting/evaluation/next_week_forecasts.csv"

FEATURES = [
    "locality_id",
    "material_type",
    "qty_lag_1_week_kg",
    "qty_lag_2_week_kg",
    "qty_lag_4_week_kg",
    "avg_qty_last_4_weeks_kg",
    "participating_households_last_4_weeks",
    "days_since_last_collection",
    "week_sin",
    "week_cos",
    "month",
]


def main():

    print("\n======= SCRAPWISE UPCOMING WEEK FORECAST =======")

    df = pd.read_csv(DATA_PATH)
    df["week_start_date"] = pd.to_datetime(df["week_start_date"])

    model = joblib.load(MODEL_PATH)

    # Next Monday in Indian Standard Time.
    today = pd.Timestamp.now(tz="Asia/Kolkata").date()
    target_start = pd.Timestamp(
        today + timedelta(days=7 - today.weekday())
    )

    target_end = target_start + pd.Timedelta(days=6)

    results = []
    bridge_predictions = 0

    for (locality, material), group in df.groupby(
        ["locality_id", "material_type"]
    ):

        group = group.sort_values("week_start_date")

        quantities = group["actual_collected_kg"].astype(float).tolist()
        households = group["participating_households_count"].astype(float).tolist()

        last_date = group["week_start_date"].iloc[-1]
        forecast_date = last_date + pd.Timedelta(days=7)

        if forecast_date > target_start:
            raise ValueError(
                f"Unexpected future dataset date for {locality}, {material}."
            )

        while forecast_date <= target_start:

            recent_quantities = quantities[-4:]
            recent_households = households[-4:]

            positive_indices = [
                i for i, value in enumerate(quantities)
                if value > 0
            ]

            if positive_indices:
                days_since = (
                    len(quantities) - positive_indices[-1]
                ) * 7
            else:
                days_since = np.nan

            week_number = forecast_date.isocalendar().week

            features = {
                "locality_id": locality,
                "material_type": material,
                "qty_lag_1_week_kg": quantities[-1],
                "qty_lag_2_week_kg": quantities[-2],
                "qty_lag_4_week_kg": quantities[-4],
                "avg_qty_last_4_weeks_kg": np.mean(recent_quantities),
                "participating_households_last_4_weeks": np.mean(recent_households),
                "days_since_last_collection": days_since,
                "week_sin": np.sin(2 * np.pi * week_number / 52),
                "week_cos": np.cos(2 * np.pi * week_number / 52),
                "month": forecast_date.month,
            }

            input_df = pd.DataFrame([features], columns=FEATURES)

            prediction = max(
                0.0,
                float(model.predict(input_df)[0])
            )

            # Save only the requested upcoming week.
            if forecast_date == target_start:

                results.append({
                    "locality_id": locality,
                    "material_type": material,
                    "forecast_week_start": forecast_date.date().isoformat(),
                    "forecast_week_end": target_end.date().isoformat(),
                    "predicted_collection_kg_next_7_days": round(prediction, 2),
                    "data_source": "synthetic_prototype",
                })

            else:
                bridge_predictions += 1

            # Use the model's estimate as a recursive historical
            # quantity for the next forecast week.
            quantities.append(prediction)

            # No future household count is available.
            # Carry forward the latest four-week mean as an assumption.
            households.append(float(np.mean(recent_households)))

            forecast_date += pd.Timedelta(days=7)

    forecast_df = pd.DataFrame(results)

    if forecast_df.empty:
        raise ValueError("No upcoming forecasts generated.")

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    forecast_df.to_csv(OUTPUT_PATH, index=False)

    print("As-of date:", today)
    print("Forecast period:", target_start.date(), "to", target_end.date())
    print("Localities:", forecast_df["locality_id"].nunique())
    print("Materials:", forecast_df["material_type"].nunique())
    print("Forecast records:", len(forecast_df))
    print("Intermediate estimated weeks:", bridge_predictions)

    print("\nSAMPLE FORECASTS:")
    print(forecast_df.head(10).to_string(index=False))

    print("\nFORECAST TOTALS BY LOCALITY:")
    print(
        forecast_df.groupby("locality_id")[
            "predicted_collection_kg_next_7_days"
        ].sum().round(2).to_string()
    )

    print("\nSaved:", OUTPUT_PATH)
    print("Data classification: SYNTHETIC PROTOTYPE")
    print("\nFORECAST GENERATION COMPLETED!")


if __name__ == "__main__":
    main()
