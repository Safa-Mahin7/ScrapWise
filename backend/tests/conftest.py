"""Prevent application database connections before test modules are imported."""

import os
import sys
from unittest.mock import patch


class DisabledApplicationDatabase:
    """Allow collection handles to be bound at import time without a client."""

    def __getitem__(self, name):
        return self

    def __getattr__(self, name):
        raise RuntimeError(f"Application MongoDB is disabled during tests ({name})")


if "backend.app.database" in sys.modules:
    raise RuntimeError("Application database was imported before test isolation")

os.environ["PYTHON_DOTENV_DISABLED"] = "1"
os.environ["MONGODB_URI"] = "disabled-during-backend-tests"
os.environ["DATABASE_NAME"] = "disabled_backend_tests"
with (
    patch("dotenv.load_dotenv", return_value=False),
    patch("pymongo.MongoClient", return_value=DisabledApplicationDatabase()),
):
    from backend.app import database

if not isinstance(database.client, DisabledApplicationDatabase):
    raise RuntimeError("Application MongoDB was not isolated")

print("Isolation active: project dotenv disabled and application MongoDB client blocked")
