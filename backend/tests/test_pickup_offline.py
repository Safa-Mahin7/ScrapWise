
from copy import deepcopy
from uuid import uuid4

from backend.app.schemas.pickup_request import PickupRequestCreate
from backend.app.services.pickup_service import (
    create_pickup_request,
    generate_pickup_clusters,
)


class FakeCursor:
    def __init__(self, documents):
        self.documents = documents

    def sort(self, field, direction=1):
        self.documents.sort(
            key=lambda item: item.get(field),
            reverse=(direction == -1),
        )
        return self

    def __iter__(self):
        return iter(self.documents)


class FakeCollection:
    """In-memory collection. Does not connect to MongoDB."""

    def __init__(self):
        self.documents = []

    def insert_one(self, document):
        stored = deepcopy(document)
        stored["_id"] = str(uuid4())
        self.documents.append(stored)

    def find(self, query, projection=None):
        results = [
            deepcopy(doc)
            for doc in self.documents
            if self._matches(doc, query)
        ]

        if projection and projection.get("_id") == 0:
            for doc in results:
                doc.pop("_id", None)

        return FakeCursor(results)

    def update_one(self, query, update):
        for doc in self.documents:
            if self._matches(doc, query):
                doc.update(update.get("$set", {}))
                return type("Result", (), {"matched_count": 1})()

        return type("Result", (), {"matched_count": 0})()

    @staticmethod
    def _matches(document, query):
        for key, expected in query.items():
            if isinstance(expected, dict):
                for operator, value in expected.items():
                    if operator == "$exists" and (key in document) is not value:
                        return False
            elif document.get(key) != expected:
                return False
        return True

    def insert_many(self, documents):
        self.documents.extend(
            deepcopy(doc) for doc in documents
        )


def main():
    pickups = FakeCollection()
    clusters = FakeCollection()

    # Create two nearby household pickup requests.
    demo_requests = [
        ("DEMO-REQ-1", 15.1394, 76.9214),
        ("DEMO-REQ-2", 15.1400, 76.9218),
    ]

    for request_id, latitude, longitude in demo_requests:
        payload = PickupRequestCreate(
            household_id=request_id,
            locality_id="DEMO-BALLARI-1",
            latitude=latitude,
            longitude=longitude,
            preferred_date="2026-11-09",
            preferred_time_slot="morning",
            materials=["paper", "plastic"],
        )

        create_pickup_request(pickups, payload)

    print("Pickup requests created:", len(pickups.documents))

    result = generate_pickup_clusters(
        pickups,
        clusters,
        eps_metres=500,
        min_samples=2,
    )

    print("Requests processed:", result["total_requests"])
    print("Clusters created:", result["total_clusters"])
    print("Clustered requests:", result["clustered_requests"])
    print("Noise requests:", result["noise_requests"])

    assert len(pickups.documents) == 2
    assert result["total_requests"] == 2
    assert result["total_clusters"] == 1
    assert result["clustered_requests"] == 2
    assert len(clusters.documents) == 1

    print("\nPICKUP WORKFLOW TEST PASSED!")


def test_standalone_pickup_workflow():
    main()


if __name__ == "__main__":
    main()
