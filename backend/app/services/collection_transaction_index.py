from pymongo.collection import Collection


REQUEST_ID_INDEX_NAME = "collection_transactions_unique_request_id"


def _request_id_index(collection: Collection) -> tuple[str, dict] | None:
    for name, metadata in collection.index_information().items():
        if metadata.get("key") != [("request_id", 1)]:
            continue
        if (
            metadata.get("unique") is True
            and metadata.get("sparse") is not True
            and "partialFilterExpression" not in metadata
        ):
            return name, metadata
        raise RuntimeError(
            "An incompatible index already exists for collection transaction "
            "request_id; it was not modified or removed."
        )
    return None


def verify_collection_transaction_index(collection: Collection) -> None:
    if _request_id_index(collection) is None:
        raise RuntimeError(
            "The unique collection transaction request_id index is missing. "
            "Run the documented dry-run and explicit index setup before "
            "starting the API."
        )


def ensure_collection_transaction_index(
    collection: Collection,
    *,
    apply: bool = False,
) -> str | None:
    references: dict[str, list[str]] = {}
    missing_references: list[str] = []

    for transaction in collection.find(
        {},
        {"_id": 1, "request_id": 1, "transaction_id": 1},
    ):
        request_id = transaction.get("request_id")
        transaction_id = str(
            transaction.get("transaction_id", transaction.get("_id", "unknown"))
        )
        if not isinstance(request_id, str) or not request_id.strip():
            missing_references.append(transaction_id)
            continue
        references.setdefault(request_id, []).append(transaction_id)

    duplicates = {
        request_id: transaction_ids
        for request_id, transaction_ids in references.items()
        if len(transaction_ids) > 1
    }
    if duplicates or missing_references:
        details = []
        if duplicates:
            duplicate_report = "; ".join(
                f"{request_id}: {', '.join(transaction_ids)}"
                for request_id, transaction_ids in sorted(duplicates.items())
            )
            details.append(f"duplicate request_id values [{duplicate_report}]")
        if missing_references:
            details.append(
                "transactions missing a non-empty request_id "
                f"[{', '.join(missing_references)}]"
            )
        raise ValueError(
            "Unique transaction index preflight failed: "
            + "; ".join(details)
            + ". No records or indexes were changed."
        )

    existing_index = _request_id_index(collection)
    if existing_index is not None:
        return existing_index[0]
    if not apply:
        return None

    return collection.create_index(
        "request_id",
        unique=True,
        name=REQUEST_ID_INDEX_NAME,
    )
