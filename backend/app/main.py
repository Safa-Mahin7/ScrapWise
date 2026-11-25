from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from pymongo.errors import PyMongoError

from backend.app.database import client, DATABASE_NAME
from backend.app.routers.collection_transactions import router
from backend.app.routers.pickup_requests import router as pickup_router
from backend.app.routers.forecast import router as forecast_router
from backend.app.routers.auth import router as auth_router, initialize_auth_indexes
from backend.app.services.collection_transaction_index import (
    verify_collection_transaction_index,
)

@asynccontextmanager
async def lifespan(app: FastAPI):
    initialize_auth_indexes()
    verify_collection_transaction_index(
        client[DATABASE_NAME]["collection_transactions"]
    )
    yield
app = FastAPI(
    title="ScrapWise API",
    description="Smart Scrap Value Chain Analysis System",
    version="1.0.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)
app.include_router(router)
app.include_router(pickup_router)
app.include_router(forecast_router)
app.include_router(auth_router)

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
