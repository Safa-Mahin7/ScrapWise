
from pathlib import Path

import pandas as pd
from fastapi import APIRouter, HTTPException

router = APIRouter(
    prefix="/api/forecast",
    tags=["Scrap Forecasting"],
)

PROJECT_ROOT = Path(__file__).resolve().parents[3]

FORECAST_FILE = (
    PROJECT_ROOT
    / "ml"
    / "scrap_forecasting"
    / "evaluation"
    / "next_week_forecasts.csv"
)


def load_forecasts():
    if not FORECAST_FILE.exists():
        raise HTTPException(
            status_code=503,
            detail="Forecast file not found. Run the prediction script first.",
        )

    try:
        return pd.read_csv(FORECAST_FILE)
    except (OSError, pd.errors.ParserError) as error:
        raise HTTPException(
            status_code=503,
            detail="Could not read forecast results.",
        ) from error


@router.get("")
def get_all_forecasts():
    """Return forecast totals for all demo localities."""

    df = load_forecasts()

    summaries = (
        df.groupby(
            ["locality_id", "forecast_week_start", "forecast_week_end"],
            as_index=False,
        )["predicted_collection_kg_next_7_days"]
        .sum()
    )

    summaries["predicted_collection_kg_next_7_days"] = (
        summaries["predicted_collection_kg_next_7_days"].round(2)
    )

    return {
        "data_source": "synthetic_prototype",
        "forecast_type": "demo_forecast",
        "localities": summaries.to_dict(orient="records"),
    }


@router.get("/{locality_id}")
def get_locality_forecast(locality_id: str):
    """Return material-wise forecasts for one locality."""

    df = load_forecasts()

    filtered = df[
        df["locality_id"].str.upper() == locality_id.upper()
    ]

    if filtered.empty:
        raise HTTPException(
            status_code=404,
            detail=f"No forecasts found for locality: {locality_id}",
        )

    first = filtered.iloc[0]

    materials = [
        {
            "material_type": str(row["material_type"]),
            "predicted_collection_kg_next_7_days": round(
                float(row["predicted_collection_kg_next_7_days"]), 2
            ),
        }
        for _, row in filtered.iterrows()
    ]

    total = round(
        sum(
            item["predicted_collection_kg_next_7_days"]
            for item in materials
        ),
        2,
    )

    return {
        "locality_id": str(first["locality_id"]),
        "forecast_week_start": str(first["forecast_week_start"]),
        "forecast_week_end": str(first["forecast_week_end"]),
        "total_predicted_collection_kg_next_7_days": total,
        "materials": materials,
        "data_source": "synthetic_prototype",
    }
