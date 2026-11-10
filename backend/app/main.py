
from fastapi import FastAPI, HTTPException
from pymongo.errors import PyMongoError

from backend.app.database import client, DATABASE_NAME
from backend.app.routers.collection_transactions import router
from backend.app.routers.pickup_requests import router as pickup_router
from backend.app.routers.forecast import router as forecast_router
app = FastAPI(
    title="ScrapWise API",
    description="Smart Scrap Value Chain Analysis System",
    version="1.0.0",
)

app.include_router(router)
app.include_router(pickup_router)
app.include_router(forecast_router)

@app.get("/")
def home():
    return {
        "message": "Welcome to ScrapWise API",
        "status": "running",
    }


@app.get("/health")
def health_check():
    try:
        client.admin.command("ping")

        return {
            "status": "healthy",
            "database": DATABASE_NAME,
            "mongodb": "connected",
        }

    except PyMongoError as error:
        raise HTTPException(
            status_code=503,
            detail="MongoDB connection unavailable.",
        ) from error
