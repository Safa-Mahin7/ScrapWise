import os
from pathlib import Path

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import PyMongoError


# Load environment variables from ScrapWise root folder
PROJECT_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(PROJECT_ROOT / ".env")

MONGODB_URI = os.getenv(
    "MONGODB_URI",
    "mongodb://localhost:27017"
)

DATABASE_NAME = os.getenv(
    "DATABASE_NAME",
    "scrapwise"
)

# Create MongoDB client
client = MongoClient(
    MONGODB_URI,
    serverSelectionTimeoutMS=5000
)

# Select database and collection
db = client[DATABASE_NAME]

collection_transactions = db["collection_transactions"]


def check_database_connection():

    try:
        client.admin.command("ping")
        print("MongoDB connected successfully!")
        print(f"Database: {DATABASE_NAME}")

        return True

    except PyMongoError as error:
        print("MongoDB connection failed!")
        print(f"Reason: {error}")

        return False


def get_collection_transactions():
    return collection_transactions