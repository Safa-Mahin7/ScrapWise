import argparse
import sys

from pymongo import MongoClient
from pymongo.errors import PyMongoError

from backend.app.database import DATABASE_NAME, MONGODB_URI
from backend.app.services.collection_transaction_index import (
    ensure_collection_transaction_index,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Preflight and optionally create the unique collection transaction "
            "request_id index. Dry-run is the default."
        )
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Create the index after a clean preflight; does not modify records.",
    )
    args = parser.parse_args()

    client = MongoClient(MONGODB_URI, serverSelectionTimeoutMS=5000)
    try:
        collection = client[DATABASE_NAME]["collection_transactions"]
        index_name = ensure_collection_transaction_index(
            collection,
            apply=args.apply,
        )
    except (PyMongoError, RuntimeError, ValueError) as error:
        print(
            f"Collection transaction index setup stopped: {error}",
            file=sys.stderr,
        )
        return 1
    finally:
        client.close()

    if index_name is not None:
        print(f"Unique request_id index is ready: {index_name}")
    elif args.apply:
        print("Unique request_id index created.")
    else:
        print(
            "Dry run passed. No records or indexes changed. "
            "Use --apply only after reviewing this environment and backup."
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
