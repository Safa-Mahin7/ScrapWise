"""Offline pickup and transaction regressions using the real auth dependency."""
from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
from datetime import timedelta
from threading import Barrier, RLock
from types import SimpleNamespace
from uuid import uuid4

import pytest
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pymongo.errors import DuplicateKeyError, PyMongoError

from backend.app.auth.dependencies import get_auth_db
from backend.app.auth.security import now_utc, random_secret, token_digest
from backend.app.routers.collection_transactions import (
    create_transaction,
    router as transaction_router,
)
from backend.app.routers.pickup_requests import router as pickup_router
from backend.app.schemas.collection_transaction import CollectionTransactionCreate
from backend.app.services.collection_transaction_index import (
    ensure_collection_transaction_index,
    verify_collection_transaction_index,
)
from backend.app.services.collection_service import (
    get_confirmed_weekly_collection_data,
)


class FakeCursor:
    def __init__(self, documents):
        self.documents = documents

    def sort(self, field, direction=1):
        self.documents.sort(
            key=lambda item: item.get(field),
            reverse=direction == -1,
        )
        return self

    def __iter__(self):
        return iter(self.documents)


class FakeCollection:
    def __init__(self):
        self.items = []
        self.indexes = []
        self.update_lock = RLock()

    def create_index(self, *args, **kwargs):
        self.indexes.append((args, kwargs))
        return kwargs.get('name', 'index')

    def index_information(self):
        indexes = {
            '_id_': {'key': [('_id', 1)], 'unique': True},
        }
        for args, options in self.indexes:
            keys = args[0]
            if isinstance(keys, str):
                keys = [(keys, 1)]
            indexes[options.get('name', str(keys))] = {
                'key': list(keys),
                'unique': options.get('unique', False),
            }
        return indexes

    def _match(self, document, query):
        for key, expected in query.items():
            if key == '$expr':
                for comparison in expected['$and']:
                    field_path, literal = comparison['$eq']
                    if document.get(field_path[1:]) != literal['$literal']:
                        return False
                continue
            if key == '$or':
                if not any(self._match(document, clause) for clause in expected):
                    return False
                continue
            current = document.get(key)
            if isinstance(expected, dict):
                for op, bound in expected.items():
                    if op == '$gt' and (current is None or current <= bound):
                        return False
                    if op == '$lt' and (current is None or current >= bound):
                        return False
                    if op == '$lte' and (current is None or current > bound):
                        return False
                    if op == '$ne' and current == bound:
                        return False
                    if op == '$in' and current not in bound:
                        return False
                    if op == '$exists' and (key in document) is not bound:
                        return False
            elif isinstance(current, list) and not isinstance(expected, list):
                if expected not in current:
                    return False
            elif current != expected:
                return False
        return True

    def find_one(self, query, projection=None):
        document = next(
            (deepcopy(x) for x in self.items if self._match(x, query)),
            None,
        )
        if document is None or not projection:
            return document
        if projection.get('_id') == 0:
            document.pop('_id', None)
        included = [key for key, value in projection.items() if value == 1]
        if included:
            document = {key: document[key] for key in included if key in document}
        return document

    def find(self, query, projection=None):
        documents = [
            deepcopy(item)
            for item in self.items
            if self._match(item, query)
        ]
        if projection:
            included = [
                key for key, value in projection.items()
                if value == 1
            ]
            if included:
                documents = [
                    {key: item[key] for key in included if key in item}
                    for item in documents
                ]
            elif projection.get('_id') == 0:
                for item in documents:
                    item.pop('_id', None)
        return FakeCursor(documents)

    def insert_one(self, doc, session=None):
        del session
        data = deepcopy(doc)
        data.setdefault('_id', str(uuid4()))
        if any(item.get('_id') == data['_id'] for item in self.items):
            raise DuplicateKeyError('duplicate document id')
        if self is db['users'] and any(
                x.get('mobile') == data.get('mobile') for x in self.items):
            raise DuplicateKeyError('duplicate mobile')
        for args, options in self.indexes:
            keys = args[0]
            if isinstance(keys, str):
                keys = [(keys, 1)]
            if options.get('sparse') and all(key not in data for key, _ in keys):
                continue
            if (
                options.get('unique') is True
                and any(
                    all(item.get(key) == data.get(key) for key, _ in keys)
                    for item in self.items
                )
            ):
                raise DuplicateKeyError('duplicate index key')
        self.items.append(data)
        return SimpleNamespace(inserted_id=data['_id'])

    def update_one(self, query, update, session=None):
        del session
        with self.update_lock:
            for item in self.items:
                if self._match(item, query):
                    item.update(deepcopy(update.get('$set', {})))
                    return SimpleNamespace(matched_count=1)
        return SimpleNamespace(matched_count=0)


class FakeSession:
    def __init__(self, database):
        self.database = database

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        del exc_type, exc_value, traceback
        return False

    def with_transaction(self, callback):
        with self.database.transaction_lock:
            before = {
                name: deepcopy(collection.items)
                for name, collection in self.database.items()
            }
            try:
                return callback(self)
            except Exception:
                for name, documents in before.items():
                    self.database[name].items = documents
                raise


class FakeMongoClient:
    def __init__(self, database):
        self.database = database

    def start_session(self):
        return FakeSession(self.database)


class FakeDB(dict):
    def __init__(self):
        super().__init__()
        self.transaction_lock = RLock()
        self.client = FakeMongoClient(self)

    def __getitem__(self, collection):
        if collection not in self:
            self[collection] = FakeCollection()
        return super().__getitem__(collection)


db = FakeDB()


@pytest.fixture
def environment():
    global db
    db = FakeDB()
    app = FastAPI()
    app.include_router(pickup_router)
    app.include_router(transaction_router)
    app.dependency_overrides[get_auth_db] = lambda: db
    ensure_collection_transaction_index(
        db['collection_transactions'],
        apply=True,
    )
    verify_collection_transaction_index(db['collection_transactions'])
    with TestClient(app) as client:
        yield client


def bearer(token):
    return {'Authorization': f'Bearer {token}'}


def issue_test_session(
    role,
    user_id,
    *,
    invited_by_user_id=None,
    permissions=None,
):
    db['users'].insert_one({
        'user_id': user_id,
        'mobile': f'+919{len(db["users"].items):09d}',
        'full_name': user_id,
        'role': role,
        'status': 'active',
        'phone_verified': True,
        'permissions': permissions or [],
        **(
            {'invited_by_user_id': invited_by_user_id}
            if invited_by_user_id is not None
            else {}
        ),
    })
    token = random_secret()
    db['auth_sessions'].insert_one({
        'user_id': user_id,
        'token_hash': token_digest(token),
        'expires_at': now_utc() + timedelta(hours=1),
        'revoked': False,
    })
    return token


def pickup_payload(household_id, **overrides):
    return {
        'household_id': household_id,
        'locality_id': 'cowl_bazar',
        'latitude': 15.13649,
        'longitude': 76.89829,
        'preferred_date': '2026-11-25',
        'preferred_time_slot': 'morning',
        'materials': ['newspaper'],
        **overrides,
    }


def transaction_payload(
    request_id,
    household_id,
    collector_id,
    recorded_by_user_id,
    entry_mode,
    **overrides,
):
    return {
        'request_id': request_id,
        'household_id': household_id,
        'locality_id': 'cowl_bazar',
        'collector_id': collector_id,
        'recorded_by_user_id': recorded_by_user_id,
        'entry_mode': entry_mode,
        'materials': [{
            'material_type': 'newspaper',
            'actual_weight_kg': 2.5,
            'agreed_rate_per_kg': 10,
        }],
        'weighed_at': now_utc().isoformat(),
        **overrides,
    }


def seed_pickup(request_id, household_id, *, collector_id=None):
    document = {
        'request_id': request_id,
        'household_id': household_id,
        'locality_id': 'cowl_bazar',
        'latitude': 15.13649,
        'longitude': 76.89829,
        'preferred_date': '2026-11-25',
        'preferred_time_slot': 'morning',
        'materials': ['newspaper'],
        'status': 'pending',
        'created_at': now_utc(),
    }
    if collector_id is not None:
        document['assigned_collector_id'] = collector_id
    db['pickup_requests'].insert_one(document)


def seed_transaction(transaction_id, household_id):
    db['collection_transactions'].insert_one({
        'transaction_id': transaction_id,
        'request_id': f'request-{transaction_id}',
        'household_id': household_id,
        'locality_id': 'cowl_bazar',
        'collector_id': 'collector-1',
        'recorded_by_user_id': 'collector-1',
        'entry_mode': 'collector_self',
        'materials': [{
            'material_type': 'newspaper',
            'actual_weight_kg': 2.5,
            'agreed_rate_per_kg': 10,
        }],
        'weighed_at': now_utc(),
        'total_amount': 25,
        'transaction_status': 'awaiting_household_confirmation',
    })


def test_pickup_and_transaction_routes_reject_missing_and_invalid_sessions(environment):
    client = environment
    payload = pickup_payload('household-1')

    assert client.get('/api/pickups/pending').status_code == 401
    assert client.post('/api/pickups', json=payload).status_code == 401
    assert client.get('/api/transactions/my').status_code == 401
    assert client.post(
        '/api/transactions/tx-1/confirm',
        json={'household_id': 'household-1'},
    ).status_code == 401

    invalid = bearer('not-a-valid-session')
    assert client.get('/api/pickups/my', headers=invalid).status_code == 401
    assert client.get('/api/transactions/my', headers=invalid).status_code == 401


def test_household_identity_and_role_are_not_client_controlled(environment):
    client = environment
    token = issue_test_session('household', 'household-1')

    spoofed_identity = client.post(
        '/api/pickups',
        headers=bearer(token),
        json=pickup_payload('household-2', role='admin'),
    )
    assert spoofed_identity.status_code == 403

    created = client.post(
        '/api/pickups',
        headers=bearer(token),
        json=pickup_payload('household-1', role='admin'),
    )
    assert created.status_code == 201
    assert created.json()['household_id'] == 'household-1'
    stored = db['pickup_requests'].find_one({
        'request_id': created.json()['request_id'],
    })
    assert stored['household_id'] == 'household-1'
    assert 'role' not in stored

    assert client.get('/api/pickups/pending', headers=bearer(token)).status_code == 403
    assert client.post(
        '/api/pickups/cluster',
        headers=bearer(token),
        json={},
    ).status_code == 403


def test_household_pickup_and_transaction_access_is_account_scoped(environment):
    client = environment
    household_1 = issue_test_session('household', 'household-1')
    household_2 = issue_test_session('household', 'household-2')
    seed_pickup('pickup-1', 'household-1')
    seed_pickup('pickup-2', 'household-2')
    seed_transaction('transaction-1', 'household-1')
    seed_transaction('transaction-2', 'household-2')

    pickup_response = client.get('/api/pickups/my', headers=bearer(household_1))
    assert [item['request_id'] for item in pickup_response.json()] == ['pickup-1']

    transaction_response = client.get(
        '/api/transactions/my',
        headers=bearer(household_1),
    )
    assert [item['transaction_id'] for item in transaction_response.json()] == [
        'transaction-1',
    ]

    assert client.post(
        '/api/transactions/transaction-2/confirm',
        headers=bearer(household_1),
        json={'household_id': 'household-1'},
    ).status_code == 404
    assert client.post(
        '/api/transactions/transaction-2/confirm',
        headers=bearer(household_1),
        json={'household_id': 'household-2'},
    ).status_code == 403
    assert client.post(
        '/api/transactions/transaction-1/confirm',
        headers=bearer(household_1),
        json={'household_id': 'household-1'},
    ).status_code == 200
    assert client.get(
        '/api/pickups/my',
        headers=bearer(household_2),
    ).json()[0]['request_id'] == 'pickup-2'


def test_collector_can_only_access_and_record_assigned_pickups(environment):
    client = environment
    collector_1 = issue_test_session('collector', 'collector-1')
    issue_test_session('collector', 'collector-2')
    seed_pickup('pickup-1', 'household-1', collector_id='collector-1')
    seed_pickup('pickup-2', 'household-2', collector_id='collector-2')

    pending = client.get('/api/pickups/pending', headers=bearer(collector_1))
    assert [item['request_id'] for item in pending.json()] == ['pickup-1']

    spoofed = transaction_payload(
        'pickup-1',
        'household-1',
        'collector-2',
        'collector-1',
        'collector_self',
        role='admin',
    )
    assert client.post(
        '/api/transactions',
        headers=bearer(collector_1),
        json=spoofed,
    ).status_code == 403

    valid = transaction_payload(
        'pickup-1',
        'household-1',
        'collector-1',
        'collector-1',
        'collector_self',
    )
    created = client.post(
        '/api/transactions',
        headers=bearer(collector_1),
        json=valid,
    )
    assert created.status_code == 201
    assert created.json()['collector_id'] == 'collector-1'
    assert created.json()['recorded_by_user_id'] == 'collector-1'


def test_repeated_transaction_submission_returns_conflict(environment):
    client = environment
    collector = issue_test_session('collector', 'collector-1')
    seed_pickup('pickup-1', 'household-1', collector_id='collector-1')
    payload = transaction_payload(
        'pickup-1',
        'household-1',
        'collector-1',
        'collector-1',
        'collector_self',
    )

    created = client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=payload,
    )
    repeated = client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=payload,
    )

    assert created.status_code == 201
    assert repeated.status_code == 409
    assert len(db['collection_transactions'].items) == 1
    pickup = db['pickup_requests'].find_one({'request_id': 'pickup-1'})
    assert pickup['collection_transaction_id'] == created.json()['transaction_id']
    assert client.get(
        '/api/pickups/pending',
        headers=bearer(collector),
    ).json() == []


def test_concurrent_transaction_submission_claims_pickup_once(environment):
    client = environment
    collector = issue_test_session('collector', 'collector-1')
    seed_pickup('pickup-1', 'household-1', collector_id='collector-1')
    payload = CollectionTransactionCreate(**transaction_payload(
        'pickup-1',
        'household-1',
        'collector-1',
        'collector-1',
        'collector_self',
    ))
    user = {'user_id': 'collector-1', 'role': 'collector'}
    barrier = Barrier(2)

    def submit():
        barrier.wait()
        try:
            response = create_transaction(payload, db, user)
            return response['transaction_id']
        except HTTPException as error:
            return error.status_code

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(lambda _: submit(), range(2)))

    assert sum(isinstance(result, str) for result in results) == 1
    assert results.count(409) == 1
    assert len(db['collection_transactions'].items) == 1
    assert client.get(
        '/api/pickups/pending',
        headers=bearer(collector),
    ).json() == []


def test_failed_transaction_insert_rolls_back_pickup_claim(environment, monkeypatch):
    client = environment
    collector = issue_test_session('collector', 'collector-1')
    seed_pickup('pickup-1', 'household-1', collector_id='collector-1')
    payload = transaction_payload(
        'pickup-1',
        'household-1',
        'collector-1',
        'collector-1',
        'collector_self',
    )
    transactions = db['collection_transactions']
    insert_one = transactions.insert_one
    fail_once = True

    def fail_first_insert(document, session=None):
        nonlocal fail_once
        if fail_once:
            fail_once = False
            raise PyMongoError('simulated transaction insert failure')
        return insert_one(document, session=session)

    monkeypatch.setattr(transactions, 'insert_one', fail_first_insert)
    failed = client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=payload,
    )

    assert failed.status_code == 503
    pickup_after_failure = db['pickup_requests'].find_one(
        {'request_id': 'pickup-1'}
    )
    assert 'collection_transaction_id' not in pickup_after_failure
    assert pickup_after_failure['status'] == 'pending'
    assert db['collection_transactions'].items == []

    retried = client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=payload,
    )
    assert retried.status_code == 201
    assert db['pickup_requests'].find_one(
        {'request_id': 'pickup-1'}
    )['collection_transaction_id'] == retried.json()['transaction_id']


def test_household_and_unrelated_trader_cannot_record_collection(environment):
    client = environment
    household = issue_test_session('household', 'household-1')
    trader = issue_test_session('trader', 'trader-1')
    issue_test_session(
        'collector',
        'collector-2',
        invited_by_user_id='trader-2',
    )
    seed_pickup('pickup-1', 'household-1', collector_id='collector-2')
    payload = transaction_payload(
        'pickup-1',
        'household-1',
        'collector-2',
        'trader-1',
        'staff_on_behalf',
    )

    assert client.post(
        '/api/transactions',
        headers=bearer(trader),
        json=payload,
    ).status_code == 403
    assert client.post(
        '/api/transactions',
        headers=bearer(household),
        json=payload,
    ).status_code == 403
    assert db['collection_transactions'].items == []
    assert 'collection_transaction_id' not in db['pickup_requests'].find_one(
        {'request_id': 'pickup-1'}
    )


def test_transaction_claim_prevents_reassignment_and_duplicate_after_decision(
    environment,
):
    client = environment
    trader = issue_test_session('trader', 'trader-1')
    collector = issue_test_session(
        'collector',
        'collector-1',
        invited_by_user_id='trader-1',
    )
    issue_test_session(
        'collector',
        'collector-2',
        invited_by_user_id='trader-1',
    )
    household = issue_test_session('household', 'household-1')
    seed_pickup('pickup-1', 'household-1', collector_id='collector-1')
    payload = transaction_payload(
        'pickup-1',
        'household-1',
        'collector-1',
        'collector-1',
        'collector_self',
    )
    created = client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=payload,
    )
    assert created.status_code == 201

    reassigned = client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(trader),
        json={'collector_id': 'collector-2'},
    )
    assert reassigned.status_code == 409
    assert client.post(
        f"/api/transactions/{created.json()['transaction_id']}/confirm",
        headers=bearer(household),
        json={'household_id': 'household-1'},
    ).status_code == 200
    assert client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=payload,
    ).status_code == 409
    assert len(db['collection_transactions'].items) == 1

    seed_pickup('pickup-2', 'household-1', collector_id='collector-1')
    disputed_payload = {
        **payload,
        'request_id': 'pickup-2',
    }
    disputed = client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=disputed_payload,
    )
    assert disputed.status_code == 201
    transaction_id = disputed.json()['transaction_id']
    assert client.post(
        f'/api/transactions/{transaction_id}/dispute',
        headers=bearer(household),
        json={'household_id': 'household-1'},
    ).status_code == 200
    assert client.post(
        f'/api/transactions/{transaction_id}/confirm',
        headers=bearer(household),
        json={'household_id': 'household-1'},
    ).status_code == 409
    assert client.post(
        '/api/transactions',
        headers=bearer(collector),
        json=disputed_payload,
    ).status_code == 409
    assert len(db['collection_transactions'].items) == 2
    weekly = get_confirmed_weekly_collection_data(
        db['collection_transactions']
    )
    assert len(weekly) == 1
    assert weekly[0]['confirmed_transaction_count'] == 1


def test_trader_assignment_is_limited_to_own_collectors_and_admin_permissions(environment):
    client = environment
    trader_1 = issue_test_session('trader', 'trader-1')
    trader_2 = issue_test_session('trader', 'trader-2')
    issue_test_session(
        'collector',
        'collector-1',
        invited_by_user_id='trader-1',
    )
    issue_test_session(
        'collector',
        'collector-2',
        invited_by_user_id='trader-2',
    )
    admin_without_permissions = issue_test_session('admin', 'admin-1')
    seed_pickup('pickup-1', 'household-1')

    assert client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(trader_1),
        json={'collector_id': 'collector-2'},
    ).status_code == 403
    assert client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(trader_1),
        json={'collector_id': 'collector-1'},
    ).status_code == 200
    assert client.get('/api/pickups/pending', headers=bearer(trader_1)).json()[0][
        'request_id'
    ] == 'pickup-1'
    assert client.get('/api/pickups/pending', headers=bearer(trader_2)).json() == []
    assert client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(trader_2),
        json={'collector_id': 'collector-2'},
    ).status_code == 403
    assert client.get(
        '/api/pickups/pending',
        headers=bearer(admin_without_permissions),
    ).status_code == 403

    admin_with_permissions = issue_test_session(
        'admin',
        'admin-2',
        permissions=['pickups:read_all', 'pickups:cluster'],
    )
    assert client.get(
        '/api/pickups/pending',
        headers=bearer(admin_with_permissions),
    ).status_code == 200


def test_concurrent_pickup_assignment_has_one_winner(environment, monkeypatch):
    client = environment
    traders = [
        issue_test_session('trader', f'trader-{number}') for number in (1, 2)
    ]
    for number in (1, 2):
        issue_test_session(
            'collector', f'collector-{number}', invited_by_user_id=f'trader-{number}'
        )
    seed_pickup('pickup-1', 'household-1')
    pickups = db['pickup_requests']
    update_one = pickups.update_one
    before_write = Barrier(2, timeout=10)

    def synchronized_update(*args, **kwargs):
        before_write.wait()
        return update_one(*args, **kwargs)

    def assign(number):
        return client.post(
            '/api/pickups/pickup-1/assignment',
            headers=bearer(traders[number - 1]),
            json={'collector_id': f'collector-{number}'},
        )

    with monkeypatch.context() as patch:
        patch.setattr(pickups, 'update_one', synchronized_update)
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(assign, (1, 2)))

    statuses = [response.status_code for response in responses]
    assert sorted(statuses) == [200, 409]
    winner = statuses.index(200) + 1
    loser = statuses.index(409) + 1
    assert responses[loser - 1].json() == {'detail': 'Pickup assignment changed'}
    assert responses[winner - 1].json() == {
        'message': 'Pickup assigned',
        'request_id': 'pickup-1',
        'collector_id': f'collector-{winner}',
    }
    stored = pickups.find_one({'request_id': 'pickup-1'})
    assert stored['assigned_collector_id'] == f'collector-{winner}'
    assert stored['assigned_by_user_id'] == f'trader-{winner}'
    assert assign(loser).status_code == 403
    assert pickups.find_one({'request_id': 'pickup-1'}) == stored
    assert db['collection_transactions'].items == []


@pytest.mark.parametrize('state', [
    {},
    {'assigned_collector_id': None, 'assigned_by_user_id': None},
    {'assigned_collector_id': None},
    {'assigned_by_user_id': None},
    {'assigned_collector_id': 'old-collector', 'assigned_by_user_id': 'trader-1'},
    {'assigned_collector_id': 'old-collector'},
    {'assigned_by_user_id': {'legacy': '$trader-1'}},
])
def test_pickup_assignment_accepts_unchanged_state(environment, state):
    client = environment
    trader = issue_test_session('trader', 'trader-1')
    for collector in ('old-collector', 'new-collector'):
        issue_test_session('collector', collector, invited_by_user_id='trader-1')
    seed_pickup('pickup-1', 'household-1')
    pickups = db['pickup_requests']
    key = {'request_id': 'pickup-1'}
    pickups.update_one(key, {'$set': state})

    response = client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(trader),
        json={'collector_id': 'new-collector'},
    )
    assert response.status_code == 200
    stored = pickups.find_one(key)
    assert stored['assigned_collector_id'] == 'new-collector'
    assert stored['assigned_by_user_id'] == 'trader-1'


@pytest.mark.parametrize('field, before, after', [
    ('assigned_collector_id', {}, {'assigned_collector_id': None}),
    ('assigned_collector_id', {'assigned_collector_id': None}, {}),
    ('assigned_by_user_id', {}, {'assigned_by_user_id': None}),
    ('assigned_by_user_id', {'assigned_by_user_id': None}, {}),
    ('assigned_by_user_id', {'assigned_by_user_id': 'old'}, {'assigned_by_user_id': ['old']}),
    ('assigned_by_user_id', {'assigned_by_user_id': 'old'}, {'assigned_by_user_id': 'other'}),
])
def test_pickup_assignment_rejects_changed_state(environment, monkeypatch, field, before, after):
    client = environment
    trader = issue_test_session('trader', 'trader-1')
    issue_test_session('collector', 'collector-1', invited_by_user_id='trader-1')
    seed_pickup('pickup-1', 'household-1')
    pickups = db['pickup_requests']
    document = pickups.items[0]
    document.update(before)
    update_one = pickups.update_one

    def update_after_state_change(*args, **kwargs):
        document.pop(field, None)
        document.update(after)
        return update_one(*args, **kwargs)

    monkeypatch.setattr(pickups, 'update_one', update_after_state_change)
    response = client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(trader),
        json={'collector_id': 'collector-1'},
    )
    assert response.status_code == 409
    stored_assignment = {
        key: value for key, value in document.items() if key.startswith('assigned_')
    }
    assert stored_assignment == after


def test_household_cannot_assign_pickup(environment):
    client = environment
    household = issue_test_session('household', 'household-1')
    issue_test_session('collector', 'collector-1', invited_by_user_id='trader-1')
    seed_pickup('pickup-1', 'household-1')
    pickups = db['pickup_requests']
    key = {'request_id': 'pickup-1'}
    before = pickups.find_one(key)

    response = client.post(
        '/api/pickups/pickup-1/assignment',
        headers=bearer(household),
        json={'collector_id': 'collector-1'},
    )
    assert response.status_code == 403
    assert pickups.find_one(key) == before
    assert db['collection_transactions'].items == []


def test_transaction_index_preflight_reports_duplicates_without_changes():
    collection = FakeCollection()
    collection.insert_one({
        'transaction_id': 'transaction-1',
        'request_id': 'pickup-1',
    })
    collection.insert_one({
        'transaction_id': 'transaction-2',
        'request_id': 'pickup-1',
    })
    records_before = deepcopy(collection.items)
    indexes_before = deepcopy(collection.indexes)

    with pytest.raises(ValueError, match='pickup-1'):
        ensure_collection_transaction_index(collection, apply=True)

    assert collection.items == records_before
    assert collection.indexes == indexes_before


def test_transaction_index_preflight_dry_run_and_explicit_apply():
    collection = FakeCollection()
    collection.insert_one({
        'transaction_id': 'transaction-1',
        'request_id': 'pickup-1',
    })

    assert ensure_collection_transaction_index(collection) is None
    assert collection.indexes == []
    index_name = ensure_collection_transaction_index(collection, apply=True)
    assert index_name == 'collection_transactions_unique_request_id'
    verify_collection_transaction_index(collection)
    with pytest.raises(DuplicateKeyError):
        collection.insert_one({
            'transaction_id': 'transaction-2',
            'request_id': 'pickup-1',
        })
