import os
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from threading import Barrier
from uuid import uuid4

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from pymongo import MongoClient
from pymongo.collection import Collection

from backend.app.auth.dependencies import get_auth_db
from backend.app.auth.security import token_digest
from backend.app.main import app
from backend.app.routers.collection_transactions import create_transaction
from backend.app.schemas.collection_transaction import CollectionTransactionCreate
from backend.app.services.collection_transaction_index import (
    ensure_collection_transaction_index,
)

TEST_URI = "mongodb://127.0.0.1:27028/?replicaSet=scrapwiseTestRs&directConnection=true"


@pytest.fixture
def replica_set_database():
    uri = os.environ.get("SCRAPWISE_TEST_MONGODB_URI")
    if not uri:
        pytest.skip(
            "Set SCRAPWISE_TEST_MONGODB_URI to a local MongoDB replica set "
            "to run database atomicity tests."
        )
    if uri != TEST_URI:
        pytest.fail("MongoDB tests require the approved direct loopback URI")

    client = MongoClient(uri, serverSelectionTimeoutMS=2000)
    try:
        hello = client.admin.command("hello")
        if (
            hello.get("setName") != "scrapwiseTestRs"
            or hello.get("me") != "127.0.0.1:27028"
            or hello.get("isWritablePrimary") is not True
        ):
            pytest.fail("The approved MongoDB endpoint is not a writable primary")

        database = client[f"scrapwise_tx_test_{uuid4().hex}"]
        print(f"MongoDB {hello['setName']} primary {hello['me']} using {database.name}")
        database.create_collection("pickup_requests")
        database.create_collection("users")
        database.create_collection("collection_transactions")
        ensure_collection_transaction_index(
            database["collection_transactions"],
            apply=True,
        )
        yield database
    finally:
        try:
            if "database" in locals():
                client.drop_database(database.name)
                assert database.name not in client.list_database_names()
                print(f"Cleanup verified: {database.name}")
        finally:
            client.close()


def _seed_collection(database):
    database["users"].insert_one({
        "user_id": "collector-1",
        "role": "collector",
        "status": "active",
        "phone_verified": True,
    })
    database["pickup_requests"].insert_one({
        "request_id": "pickup-1",
        "household_id": "household-1",
        "locality_id": "locality-1",
        "assigned_collector_id": "collector-1",
        "status": "pending",
    })


def _payload():
    return CollectionTransactionCreate(
        request_id="pickup-1",
        household_id="household-1",
        locality_id="locality-1",
        collector_id="collector-1",
        recorded_by_user_id="collector-1",
        entry_mode="collector_self",
        materials=[{
            "material_type": "newspaper",
            "actual_weight_kg": 2.5,
            "agreed_rate_per_kg": 10,
        }],
        weighed_at=datetime.now(timezone.utc),
    )


def _collector():
    return {"user_id": "collector-1", "role": "collector"}


def test_replica_set_allows_only_one_concurrent_transaction(replica_set_database):
    database = replica_set_database
    _seed_collection(database)
    barrier = Barrier(2, timeout=10)

    def submit():
        barrier.wait()
        try:
            result = create_transaction(_payload(), database, _collector())
            return result["transaction_id"]
        except HTTPException as error:
            return error.status_code

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(lambda _: submit(), range(2)))

    print(f"Transaction concurrency results (created ID or HTTP status): {results}")
    assert sum(isinstance(result, str) for result in results) == 1
    assert results.count(409) == 1
    assert database["collection_transactions"].count_documents(
        {"request_id": "pickup-1"}
    ) == 1
    pickup = database["pickup_requests"].find_one({"request_id": "pickup-1"})
    assert pickup["collection_transaction_id"] in results


def test_replica_set_rolls_back_pickup_claim_when_insert_fails(replica_set_database):
    database = replica_set_database
    database.drop_collection("collection_transactions")
    database.create_collection(
        "collection_transactions",
        validator={
            "$jsonSchema": {
                "bsonType": "object",
                "required": ["test_only_rejected"],
            },
        },
    )
    ensure_collection_transaction_index(
        database["collection_transactions"],
        apply=True,
    )
    _seed_collection(database)

    with pytest.raises(HTTPException) as failure:
        create_transaction(_payload(), database, _collector())

    assert failure.value.status_code == 503
    pickup = database["pickup_requests"].find_one({"request_id": "pickup-1"})
    assert "collection_transaction_id" not in pickup
    assert database["collection_transactions"].count_documents({}) == 0
    print("Transaction insert failure returned 503 and rolled back the claim")

    database.command("collMod", "collection_transactions", validator={})
    created = create_transaction(_payload(), database, _collector())
    assert database["pickup_requests"].find_one(
        {"request_id": "pickup-1"}
    )["collection_transaction_id"] == created["transaction_id"]
    assert database["collection_transactions"].count_documents(
        {"request_id": "pickup-1"}
    ) == 1
    print(f"Transaction retry created {created['transaction_id']}")


def test_replica_set_assignment_has_one_http_winner(replica_set_database, monkeypatch):
    database = replica_set_database
    for number in (1, 2):
        trader = f"trader-{number}"
        database.users.insert_many([
            {"user_id": trader, "role": "trader", "status": "active", "phone_verified": True},
            {"user_id": f"collector-{number}", "role": "collector", "status": "active",
             "phone_verified": True, "invited_by_user_id": trader},
        ])
        database.auth_sessions.insert_one({
            "user_id": trader,
            "token_hash": token_digest(f"test-trader-{number}"),
            "revoked": False,
            "expires_at": datetime.now(timezone.utc) + timedelta(minutes=10),
        })
    database.pickup_requests.insert_one({"request_id": "pickup-1", "status": "pending"})
    monkeypatch.setitem(app.dependency_overrides, get_auth_db, lambda: database)
    before_write = Barrier(2, timeout=10)
    original_update = Collection.update_one

    def synchronized_update(collection, query, *args, **kwargs):
        if collection.full_name == database.pickup_requests.full_name:
            assert query["assigned_collector_id"] == {"$exists": False}
            assert query["assigned_by_user_id"] == {"$exists": False}
            before_write.wait()
        return original_update(collection, query, *args, **kwargs)

    def assign(number):
        return TestClient(app).post(
            "/api/pickups/pickup-1/assignment",
            headers={"Authorization": f"Bearer test-trader-{number}"},
            json={"collector_id": f"collector-{number}"},
        )

    with monkeypatch.context() as patch:
        patch.setattr(Collection, "update_one", synchronized_update)
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(assign, (1, 2)))

    statuses = [response.status_code for response in responses]
    print(f"Assignment HTTP responses: {[(r.status_code, r.json()) for r in responses]}")
    assert sorted(statuses) == [200, 409]
    winner = statuses.index(200) + 1
    loser = statuses.index(409) + 1
    assert responses[winner - 1].json() == {
        "message": "Pickup assigned", "request_id": "pickup-1",
        "collector_id": f"collector-{winner}",
    }
    assert responses[loser - 1].json() == {"detail": "Pickup assignment changed"}
    stored = database.pickup_requests.find_one({"request_id": "pickup-1"}, {"_id": 0})
    assert stored == {
        "request_id": "pickup-1", "status": "pending",
        "assigned_collector_id": f"collector-{winner}", "assigned_by_user_id": f"trader-{winner}",
    }
    retry = assign(loser)
    assert retry.status_code == 403
    assert database.pickup_requests.find_one({"request_id": "pickup-1"}, {"_id": 0}) == stored
    count = database.collection_transactions.count_documents({})
    assert count == 0
    print(f"Stored assignment: {stored}; losing retry: {retry.status_code}; transactions: {count}")
