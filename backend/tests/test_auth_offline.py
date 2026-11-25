"""Offline auth API tests: no MongoDB Atlas, SMS provider, or network required.

Run from repository root: python -m pytest backend/tests/test_auth_offline.py -q
"""
from copy import deepcopy
from datetime import timedelta
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier, BoundedSemaphore, Event, RLock
from types import SimpleNamespace
from uuid import uuid4
import pytest
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.testclient import TestClient
from pymongo.errors import PyMongoError

from backend.app.auth import security, sms
from backend.app.auth.dependencies import get_auth_db
from backend.app.auth.security import hash_password, now_utc, random_secret, token_digest
import backend.app.routers.auth as auth_module
from backend.app.routers.auth import (
    OTP_RATE_LIMITS, _enforce_otp_rate_limits, initialize_auth_indexes, router,
)


class FakeCollection:
    def __init__(self):
        self.items = []
        self.lock = RLock()

    def create_index(self, *args, **kwargs):
        return 'index'

    def _match(self, document, query):
        for key, expected in query.items():
            if key == '$or':
                if not any(self._match(document, option) for option in expected):
                    return False
                continue
            current = document.get(key)
            if isinstance(expected, dict):
                for op, bound in expected.items():
                    if op == '$exists':
                        matches = (key in document) is bound
                    elif current is None:
                        matches = False
                    elif op == '$gt':
                        matches = current > bound
                    elif op == '$lt':
                        matches = current < bound
                    elif op == '$lte':
                        matches = current <= bound
                    else:
                        raise AssertionError(f'Unsupported fake query operator: {op}')
                    if not matches:
                        return False
            elif isinstance(current, list):
                if expected not in current:
                    return False
            elif current != expected:
                return False
        return True

    def find_one(self, query):
        return next((deepcopy(x) for x in self.items if self._match(x, query)), None)

    def insert_one(self, doc):
        from pymongo.errors import DuplicateKeyError
        with self.lock:
            data = deepcopy(doc)
            data.setdefault('_id', str(uuid4()))
            if self is db['users'] and any(
                    x.get('mobile') == data.get('mobile') for x in self.items):
                raise DuplicateKeyError('duplicate mobile')
            if self is db['users'] and data.get('google_sub') and any(
                    x.get('google_sub') == data['google_sub'] for x in self.items):
                raise DuplicateKeyError('duplicate Google subject')
            if self is db['auth_otp_challenges'] and any(
                    all(x.get(key) == data.get(key) for key in ('purpose', 'mobile', 'subject'))
                    for x in self.items):
                raise DuplicateKeyError('duplicate OTP challenge key')
            if self is db['auth_mobile_changes'] and any(
                    x.get('user_id') == data.get('user_id') for x in self.items):
                raise DuplicateKeyError('duplicate pending mobile change')
            if self is db['auth_sessions'] and (
                    any(x.get('token_hash') == data.get('token_hash') for x in self.items)
                    or any(x.get('refresh_token_hash') == data.get('refresh_token_hash')
                           for x in self.items)):
                raise DuplicateKeyError('duplicate session credential')
            self.items.append(data)
            return SimpleNamespace(inserted_id=data['_id'])

    def replace_one(self, query, replacement, upsert=False):
        for i, doc in enumerate(self.items):
            if self._match(doc, query):
                data = deepcopy(replacement)
                data['_id'] = doc['_id']
                self.items[i] = data
                return SimpleNamespace(matched_count=1)
        if upsert:
            self.insert_one(replacement)
        return SimpleNamespace(matched_count=0)

    def _update(self, item, update, *, is_insert=False):
        if is_insert:
            for key, value in update.get('$setOnInsert', {}).items():
                item[key] = value
        for key, value in update.get('$set', {}).items():
            item[key] = value
        for key, value in update.get('$inc', {}).items():
            item[key] = item.get(key, 0) + value
        for key, value in update.get('$push', {}).items():
            item.setdefault(key, []).append(value)

    def update_one(self, query, update):
        from pymongo.errors import DuplicateKeyError
        for item in self.items:
            if self._match(item, query):
                new_mobile = update.get('$set', {}).get('mobile')
                if self is db['users'] and new_mobile is not None and any(
                        other is not item and other.get('mobile') == new_mobile
                        for other in self.items):
                    raise DuplicateKeyError('duplicate mobile')
                self._update(item, update)
                return SimpleNamespace(matched_count=1)
        return SimpleNamespace(matched_count=0)

    def update_many(self, query, update):
        count = 0
        for item in self.items:
            if self._match(item, query):
                self._update(item, update)
                count += 1
        return SimpleNamespace(matched_count=count)

    def find_one_and_update(self, query, update, return_document=None, upsert=False):
        with self.lock:
            for item in self.items:
                if self._match(item, query):
                    old = deepcopy(item)
                    self._update(item, update)
                    return deepcopy(item) if return_document else old
            if upsert:
                data = {
                    key: value for key, value in query.items()
                    if not key.startswith('$') and not isinstance(value, dict)
                }
                self._update(data, update, is_insert=True)
                inserted = self.insert_one(data)
                return self.find_one({'_id': inserted.inserted_id})
            return None

    def delete_one(self, query):
        for i, item in enumerate(self.items):
            if self._match(item, query):
                self.items.pop(i)
                return SimpleNamespace(deleted_count=1)
        return SimpleNamespace(deleted_count=0)

    def find_one_and_delete(self, query):
        for i, item in enumerate(self.items):
            if self._match(item, query):
                return self.items.pop(i)
        return None

    def delete_many(self, query):
        before = len(self.items)
        self.items = [item for item in self.items if not self._match(item, query)]
        return SimpleNamespace(deleted_count=before - len(self.items))


class FakeDB(dict):
    def __getitem__(self, collection):
        if collection not in self:
            self[collection] = FakeCollection()
        return super().__getitem__(collection)


db = FakeDB()


@pytest.fixture
def environment(monkeypatch):
    global db
    db = FakeDB()
    codes = []
    monkeypatch.setenv('AUTH_OTP_SECRET', 'test_secret_please_do_not_use_in_real_deployments_123456')
    monkeypatch.setattr(sms, 'require_sms_provider', lambda: None)
    monkeypatch.setattr(sms, 'send_verification_code', lambda mobile, code, purpose: codes.append((mobile, code, purpose)))
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_auth_db] = lambda: db
    initialize_auth_indexes(db)
    with TestClient(app) as client:
        yield client, codes


def register_household(client):
    return client.post('/api/auth/register/household', json={
        'full_name': 'Test User', 'mobile': '9876543210',
        'locality_id': 'cowl_bazar', 'password': 'TestPass123456!',
    })


def verified_household(client, codes):
    result = register_household(client)
    assert result.status_code == 202, result.text
    code = codes[-1][1]
    result = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'registration', 'code': code,
    })
    assert result.status_code == 200, result.text
    return result


def login(client, mobile='9876543210', password='TestPass123456!'):
    return client.post('/api/auth/login', json={'mobile': mobile, 'password': password})


def bearer(token):
    return {'Authorization': f'Bearer {token}'}


@pytest.fixture
def login_clock(monkeypatch):
    now = now_utc()
    window = auth_module.LOGIN_RATE_WINDOW_SECONDS
    clock = SimpleNamespace(now=now - timedelta(
        seconds=int(now.timestamp()) % window, microseconds=now.microsecond,
    ))
    monkeypatch.setattr(auth_module, 'now_utc', lambda: clock.now)
    return clock


@pytest.mark.parametrize(
    'fields',
    [
        None,
        {},
        {'password_hash': ''},
        {'password_hash': None},
        {'google_sub': 'synthetic-linked-identity'},
    ],
    ids=['missing-account', 'missing-hash', 'empty-hash', 'null-hash', 'google-only'],
)
def test_successful_dummy_comparison_never_authenticates(environment, monkeypatch, fields):
    client, _ = environment
    if fields is not None:
        db['users'].insert_one({
            'user_id': 'synthetic-account', 'mobile': '+919876543210',
            'role': 'household', 'status': 'active', 'phone_verified': True, **fields,
        })
    checked = []

    def successful_comparison(digest, _password):
        checked.append(digest == security._DUMMY_HASH)
        return True

    monkeypatch.setattr(security, '_passwords', SimpleNamespace(verify=successful_comparison))
    response = login(client)
    assert checked == [True]
    assert response.status_code == 401
    assert response.json() == {'detail': 'Invalid mobile number or password'}
    assert not db['auth_sessions'].items


def test_malformed_hash_cannot_authenticate(environment):
    client, _ = environment
    db['users'].insert_one({
        'user_id': 'synthetic-account', 'mobile': '+919876543210',
        'role': 'household', 'status': 'active', 'phone_verified': True,
        'password_hash': 'malformed',
    })
    assert login(client).status_code == 401
    assert not db['auth_sessions'].items


def test_stored_dummy_hash_cannot_authenticate(environment, monkeypatch):
    client, _ = environment
    db['users'].insert_one({
        'user_id': 'synthetic-account', 'mobile': '+919876543210',
        'role': 'household', 'status': 'active', 'phone_verified': True,
        'password_hash': security._DUMMY_HASH,
    })
    monkeypatch.setattr(security, '_passwords', SimpleNamespace(verify=lambda *_: True))
    assert login(client).status_code == 401
    assert not db['auth_sessions'].items


@pytest.mark.parametrize('role', ['household', 'collector', 'trader', 'admin'])
def test_password_login_checks_real_hash_and_returns_server_role(environment, role):
    client, _ = environment
    db['users'].insert_one({
        'user_id': 'synthetic-account', 'mobile': '+919876543210',
        'role': role, 'status': 'active', 'phone_verified': True,
        'password_hash': hash_password('TestPass123456!'),
    })
    wrong = login(client, password='SyntheticWrongPass123!')
    assert wrong.status_code == 401
    assert wrong.json() == {'detail': 'Invalid mobile number or password'}
    assert not db['auth_sessions'].items
    response = login(client)
    assert response.status_code == 200
    assert response.headers['Cache-Control'] == 'no-store'
    assert response.json()['user']['role'] == role
    assert len(db['auth_sessions'].items) == 1


def test_login_account_budget_spans_clients_and_recovers_next_window(environment, login_clock):
    client, codes = environment
    verified_household(client, codes)
    for _ in range(auth_module.LOGIN_ACCOUNT_LIMIT):
        assert login(client, password='SyntheticWrongPass123!').status_code == 401

    with TestClient(client.app, client=('192.0.2.25', 50000)) as other_client:
        blocked = login(other_client, mobile='+919876543210')
        assert blocked.status_code == 429
        assert int(blocked.headers['Retry-After']) == auth_module.LOGIN_RATE_WINDOW_SECONDS
        login_clock.now += timedelta(seconds=auth_module.LOGIN_RATE_WINDOW_SECONDS)
        assert login(other_client).status_code == 200


def test_login_client_budget_spans_accounts_and_ignores_forwarding_headers(
    environment, monkeypatch,
):
    client, _ = environment
    monkeypatch.setattr(auth_module, 'LOGIN_CLIENT_LIMIT', 2)
    verified = []
    monkeypatch.setattr(auth_module, 'verify_password', lambda *_: verified.append(True) or False)
    for index in range(3):
        response = client.post(
            '/api/auth/login',
            json={'mobile': f'987654320{index}', 'password': 'SyntheticPassword'},
            headers={'X-Forwarded-For': f'192.0.2.{index + 1}'},
        )
        assert response.status_code == (401 if index < 2 else 429)
    assert len(verified) == 2
    with TestClient(client.app, client=('192.0.2.25', 50000)) as other_client:
        assert login(other_client, mobile='9876543202').status_code == 401
    assert len(verified) == 3


def test_concurrent_login_attempts_cannot_exceed_account_budget(environment, monkeypatch):
    client, _ = environment
    monkeypatch.setattr(auth_module, 'LOGIN_ACCOUNT_LIMIT', 3)
    monkeypatch.setattr(auth_module, 'PASSWORD_VERIFICATION_SLOTS', BoundedSemaphore(6))
    checked = []
    monkeypatch.setattr(auth_module, 'verify_password', lambda *_: checked.append(True) or False)
    start = Barrier(6)

    def attempt(_):
        start.wait(timeout=5)
        return login(client).status_code

    with ThreadPoolExecutor(max_workers=6) as pool:
        assert sorted(pool.map(attempt, range(6))) == [401] * 3 + [429] * 3
    assert len(checked) == 3


def test_password_verification_slots_reject_excess_and_become_available(environment, monkeypatch):
    client, _ = environment
    entered = Barrier(3)
    release = Event()

    def occupy_slot(*_):
        entered.wait(timeout=5)
        if not release.wait(timeout=5):
            raise RuntimeError('Verification test did not release the slots')
        return False

    monkeypatch.setattr(auth_module, 'verify_password', occupy_slot)
    with ThreadPoolExecutor(max_workers=2) as pool:
        pending = [pool.submit(login, client) for _ in range(2)]
        try:
            entered.wait(timeout=5)
            blocked = login(client)
            assert blocked.status_code == 429
            assert blocked.headers['Retry-After'] == '1'
        finally:
            release.set()
        assert all(response.result().status_code == 401 for response in pending)
    monkeypatch.setattr(auth_module, 'verify_password', lambda *_: False)
    assert login(client).status_code == 401


def test_login_throttle_fails_closed_if_counters_are_unavailable(environment, monkeypatch):
    client, _ = environment

    def unavailable(*_args, **_kwargs):
        raise PyMongoError('synthetic database failure')

    monkeypatch.setattr(db['auth_login_attempts'], 'find_one_and_update', unavailable)
    monkeypatch.setattr(auth_module, 'verify_password', lambda *_: pytest.fail('Unexpected verification'))
    response = login(client)
    assert response.status_code == 503
    assert response.headers['Retry-After'] == '1'
    assert response.json() == {'detail': 'Login temporarily unavailable'}


@pytest.mark.parametrize(
    ('path', 'field', 'length', 'extra'),
    [
        ('/login', 'password', 129, {'mobile': '9876543210'}),
        ('/refresh', 'refresh_token', 513, {}),
        ('/logout', 'refresh_token', 513, {}),
        ('/otp/verify', 'code', 6, {'mobile': '9876543210', 'purpose': 'registration'}),
        ('/password/reset', 'reset_token', 15, {'mobile': '9876543210', 'new_password': 'SyntheticValid12!'}),
        ('/collector/activate/request-otp', 'invitation_token', 15, {'mobile': '9876543210'}),
    ],
)
def test_auth_validation_does_not_echo_sensitive_values(
    environment, caplog, path, field, length, extra,
):
    client, _ = environment
    marker = 'Q' * length
    response = client.post(f'/api/auth{path}', json={**extra, field: marker})
    assert response.status_code == 422
    assert response.headers['Cache-Control'] == 'no-store'
    assert marker not in response.text and marker not in caplog.text
    detail = response.json()['detail']
    assert detail[0]['loc'] == ['body', field]
    assert set(detail[0]) == {'loc', 'msg', 'type'}


def test_malformed_auth_json_does_not_echo_body(environment, caplog):
    client, _ = environment
    marker = 'synthetic-credential-marker'
    response = client.post(
        '/api/auth/login', content=f'{{"password":"{marker}",',
        headers={'Content-Type': 'application/json'},
    )
    assert response.status_code == 422
    assert marker not in response.text and marker not in caplog.text
    assert response.json()['detail'][0]['msg'] == 'Malformed JSON'



@pytest.mark.parametrize('changes', [
    {'status': 'disabled'},
    {'phone_verified': False},
    {'auth_version': 1},
])
def test_bearer_and_refresh_share_account_eligibility(environment, changes):
    client, codes = environment
    verified_household(client, codes)
    session = login(client).json()
    db['users'].update_one({'user_id': session['user']['user_id']}, {'$set': changes})
    if 'auth_version' not in changes:
        denied = login(client)
        assert denied.status_code == 403
        assert denied.json() == {'detail': 'Account is not eligible to sign in'}

    denied = client.get('/api/auth/me', headers=bearer(session['access_token']))
    assert denied.status_code == 401
    assert denied.json() == {'detail': 'Invalid or expired session'}
    assert denied.headers['WWW-Authenticate'] == 'Bearer'

    denied = client.post('/api/auth/refresh', json={'refresh_token': session['refresh_token']})
    assert denied.status_code == 401
    assert denied.json() == {'detail': 'Invalid or expired refresh token'}
    assert db['auth_sessions'].items[0]['revoked'] is True


@pytest.mark.parametrize('expiry_field', ['access_expires_at', 'expires_at'])
def test_expired_session_cannot_authorize_access(environment, expiry_field):
    client, codes = environment
    verified_household(client, codes)
    session = login(client).json()
    db['auth_sessions'].update_one(
        {'token_hash': token_digest(session['access_token'])},
        {'$set': {expiry_field: now_utc() - timedelta(seconds=1)}},
    )
    denied = client.get('/api/auth/me', headers=bearer(session['access_token']))
    assert denied.status_code == 401
    assert denied.json() == {'detail': 'Invalid or expired session'}
    refreshed = client.post('/api/auth/refresh', json={'refresh_token': session['refresh_token']})
    assert refreshed.status_code == (200 if expiry_field == 'access_expires_at' else 401)


def test_household_register_verify_login_and_logout(environment):
    client, codes = environment
    assert client.get('/api/auth/me').status_code == 401
    assert login(client).status_code == 401
    registered = register_household(client)
    assert registered.status_code == 202
    assert len(codes[-1][1]) == 6 and codes[-1][1].isdigit()
    assert codes[-1][1] not in registered.text
    assert login(client).status_code == 403
    bad = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'registration', 'code': '000000',
    })
    assert bad.status_code == 400
    good = verified_otp = client.post('/api/auth/otp/verify', json={
        'mobile': '+919876543210', 'purpose': 'registration', 'code': codes[-1][1],
    })
    assert good.status_code == 200
    auth = login(client)
    assert auth.status_code == 200
    payload = auth.json()
    assert payload['user']['role'] == 'household'
    token = payload['access_token']
    assert client.get('/api/auth/me', headers=bearer(token)).status_code == 200
    assert client.post('/api/auth/logout', headers=bearer(token)).status_code == 200
    assert client.get('/api/auth/me', headers=bearer(token)).status_code == 401
    assert client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'registration', 'code': codes[-1][1],
    }).status_code == 400


def test_refresh_rotates_credentials_and_replay_revokes_session(environment):
    client, codes = environment
    verified_household(client, codes)
    original = login(client).json()
    rotated = client.post('/api/auth/refresh', json={
        'refresh_token': original['refresh_token'],
    })
    assert rotated.status_code == 200
    renewed = rotated.json()
    assert renewed['refresh_token'] != original['refresh_token']
    assert renewed['access_token'] != original['access_token']
    assert renewed['user']['role'] == 'household'
    assert client.get('/api/auth/me', headers=bearer(original['access_token'])).status_code == 401
    assert client.get('/api/auth/me', headers=bearer(renewed['access_token'])).status_code == 200

    replay = client.post('/api/auth/refresh', json={
        'refresh_token': original['refresh_token'],
    })
    assert replay.status_code == 401
    assert client.get('/api/auth/me', headers=bearer(renewed['access_token'])).status_code == 401
    assert client.post('/api/auth/refresh', json={
        'refresh_token': renewed['refresh_token'],
    }).status_code == 401


def test_refresh_rejects_and_revokes_disabled_account_session(environment):
    client, codes = environment
    verified_household(client, codes)
    session = login(client).json()
    db['users'].update_one(
        {'mobile': '+919876543210'},
        {'$set': {'status': 'suspended'}},
    )
    assert client.post('/api/auth/refresh', json={
        'refresh_token': session['refresh_token'],
    }).status_code == 401
    stored = db['auth_sessions'].find_one({
        'user_id': session['user']['user_id'],
    })
    assert stored['revoked'] is True


def test_logout_with_refresh_token_revokes_after_access_expiration(environment):
    client, codes = environment
    verified_household(client, codes)
    session = login(client).json()
    db['auth_sessions'].update_one(
        {'token_hash': token_digest(session['access_token'])},
        {'$set': {'access_expires_at': now_utc() - timedelta(seconds=1)}},
    )
    result = client.post('/api/auth/logout', json={
        'refresh_token': session['refresh_token'],
    })
    assert result.status_code == 200
    assert client.post('/api/auth/refresh', json={
        'refresh_token': session['refresh_token'],
    }).status_code == 401


def test_registration_unavailable_when_no_sms_and_no_user_created(environment, monkeypatch):
    client, _ = environment
    from fastapi import HTTPException
    monkeypatch.setattr(sms, 'require_sms_provider', lambda: (_ for _ in ()).throw(HTTPException(status_code=503, detail='unconfigured')))
    assert register_household(client).status_code == 503
    assert len(db['users'].items) == 0


def test_password_reset_revokes_old_session(environment):
    client, codes = environment
    verified_household(client, codes)
    token = login(client).json()['access_token']
    response = client.post('/api/auth/password/forgot', json={'mobile': '9876543210'})
    assert response.status_code == 202
    verify = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'password_reset', 'code': codes[-1][1],
    })
    assert verify.status_code == 200
    grant = verify.json()['reset_token']
    changed = client.post('/api/auth/password/reset', json={
        'mobile': '9876543210', 'reset_token': grant, 'new_password': 'NewPassword12345!',
    })
    assert changed.status_code == 200
    assert client.get('/api/auth/me', headers=bearer(token)).status_code == 401
    assert login(client).status_code == 401
    assert login(client, password='NewPassword12345!').status_code == 200
    assert client.post('/api/auth/password/reset', json={
        'mobile': '9876543210', 'reset_token': grant, 'new_password': 'AnotherPassword1234',
    }).status_code == 400


def test_password_reset_rejects_wrong_expired_and_reused_credentials(environment):
    client, codes = environment
    verified_household(client, codes)
    assert client.post('/api/auth/password/forgot', json={
        'mobile': '9876543210',
    }).status_code == 202
    valid_code = codes[-1][1]
    wrong_code = '000000' if valid_code != '000000' else '000001'
    assert client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'password_reset', 'code': wrong_code,
    }).status_code == 400

    db['auth_otp_challenges'].update_one(
        {'mobile': '+919876543210', 'purpose': 'password_reset'},
        {'$set': {'expires_at': now_utc() - timedelta(seconds=1)}},
    )
    assert client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'password_reset', 'code': valid_code,
    }).status_code == 400


def test_expired_password_reset_grant_is_rejected(environment):
    client, codes = environment
    verified_household(client, codes)
    client.post('/api/auth/password/forgot', json={'mobile': '9876543210'})
    verified = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'password_reset', 'code': codes[-1][1],
    })
    grant = verified.json()['reset_token']
    db['auth_reset_grants'].update_one(
        {'token_hash': token_digest(grant)},
        {'$set': {'expires_at': now_utc() - timedelta(seconds=1)}},
    )
    assert client.post('/api/auth/password/reset', json={
        'mobile': '9876543210',
        'reset_token': grant,
        'new_password': 'NewPassword12345!',
    }).status_code == 400


def test_password_reset_attempts_are_rate_limited(environment, monkeypatch):
    client, _ = environment
    monkeypatch.setitem(OTP_RATE_LIMITS['reset'], 'mobile', 1)
    request = {
        'mobile': '9876543210',
        'reset_token': random_secret(),
        'new_password': 'NewPassword12345!',
    }
    assert client.post('/api/auth/password/reset', json=request).status_code == 400
    assert client.post('/api/auth/password/reset', json=request).status_code == 429


def test_google_only_account_recovery_does_not_create_password_or_send_otp(environment):
    client, codes = environment
    db['users'].insert_one({
        'user_id': str(uuid4()), 'mobile': '+919876543210',
        'full_name': 'Google Household', 'google_sub': 'google-subject-1',
        'role': 'household', 'status': 'active', 'phone_verified': True,
    })
    initial_codes = len(codes)
    response = client.post('/api/auth/password/forgot', json={
        'mobile': '9876543210',
    })
    assert response.status_code == 202
    assert len(codes) == initial_codes
    assert client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'password_reset', 'code': '123456',
    }).status_code == 400
    assert db['auth_reset_grants'].items == []
    assert 'password_hash' not in db['users'].find_one({
        'mobile': '+919876543210',
    })


def test_concurrent_recovery_requests_reserve_one_otp(environment):
    client, codes = environment
    verified_household(client, codes)

    def request_code(_):
        return client.post('/api/auth/password/forgot', json={
            'mobile': '9876543210',
        }).status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        statuses = list(pool.map(request_code, range(2)))

    assert sorted(statuses) == [202, 429]
    assert len([code for code in codes if code[2] == 'password_reset']) == 1


def test_password_reset_invalidates_other_outstanding_grants(environment):
    client, codes = environment
    verified_household(client, codes)

    assert client.post('/api/auth/password/forgot', json={
        'mobile': '9876543210',
    }).status_code == 202
    verified = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210',
        'purpose': 'password_reset',
        'code': codes[-1][1],
    })
    assert verified.status_code == 200
    first_token = verified.json()['reset_token']

    # Simulate another valid, unexpired grant for the same account.
    # The first successful password reset must invalidate both grants.
    user = db['users'].find_one({'mobile': '+919876543210'})
    other_token = random_secret()
    db['auth_reset_grants'].insert_one({
        'user_id': user['user_id'],
        'token_hash': token_digest(other_token),
        'created_at': now_utc(),
        'expires_at': now_utc() + timedelta(minutes=10),
    })
    assert len(db['auth_reset_grants'].items) == 2

    reset = client.post('/api/auth/password/reset', json={
        'mobile': '9876543210',
        'reset_token': first_token,
        'new_password': 'UpdatedPass12345!',
    })
    assert reset.status_code == 200, reset.text
    assert db['auth_reset_grants'].find_one({
        'token_hash': token_digest(other_token),
    }) is None
    assert client.post('/api/auth/password/reset', json={
        'mobile': '9876543210',
        'reset_token': other_token,
        'new_password': 'InvalidSecondPass123!',
    }).status_code == 400
    assert login(client, password='UpdatedPass12345!').status_code == 200


def test_trader_approval_and_collector_invitation(environment):
    client, codes = environment
    applied = client.post('/api/auth/trader/apply', json={
        'mobile': '9888888888', 'full_name': 'Trader One',
        'business_name': 'Scrap Traders', 'business_address': 'Ballari Karnataka',
        'password': 'TraderPass123!',
    })
    assert applied.status_code == 202
    verified = client.post('/api/auth/otp/verify', json={
        'mobile': '9888888888', 'purpose': 'registration', 'code': codes[-1][1],
    })
    assert verified.json()['account_status'] == 'pending_approval'
    assert login(client, '9888888888', 'TraderPass123!').status_code == 403
    verified_household(client, codes)
    household_token = login(client).json()['access_token']
    trader_id = db['users'].find_one({'mobile': '+919888888888'})['user_id']
    assert client.post(f'/api/auth/admin/traders/{trader_id}/approve', headers=bearer(household_token)).status_code == 403
    db['users'].insert_one({
        'user_id': str(uuid4()), 'mobile': '+919777777777', 'full_name': 'Provisioned Admin',
        'role': 'admin', 'status': 'active', 'phone_verified': True,
        'password_hash': hash_password('AdminPass12345!'),
    })
    admin_token = login(client, '9777777777', 'AdminPass12345!').json()['access_token']
    assert client.post(f'/api/auth/admin/traders/{trader_id}/approve', headers=bearer(admin_token)).status_code == 200
    trader_token = login(client, '9888888888', 'TraderPass123!').json()['access_token']
    invite = client.post('/api/auth/collector/invitations', headers=bearer(trader_token), json={
        'mobile': '9666666666', 'full_name': 'Collector One',
    })
    assert invite.status_code == 201
    invite_token = invite.json()['invitation_token']
    assert client.post('/api/auth/collector/activate/request-otp', json={
        'mobile': '9666666666', 'invitation_token': invite_token,
    }).status_code == 202
    activated = client.post('/api/auth/collector/activate', json={
        'mobile': '9666666666', 'invitation_token': invite_token,
        'code': codes[-1][1], 'password': 'CollectorPass123!',
    })
    assert activated.status_code == 201
    collector = login(client, '9666666666', 'CollectorPass123!')
    assert collector.status_code == 200
    assert collector.json()['user']['role'] == 'collector'
    assert client.post('/api/auth/collector/activate', json={
        'mobile': '9666666666', 'invitation_token': invite_token,
        'code': codes[-1][1], 'password': 'CollectorPass123!',
    }).status_code == 400


def test_mobile_change_revokes_sessions(environment):
    client, codes = environment
    verified_household(client, codes)
    session = login(client).json()
    token = session['access_token']
    request = client.post('/api/auth/mobile/change/request', headers=bearer(token), json={
        'new_mobile': '9555555555',
        'current_password': 'TestPass123456!',
    })
    assert request.status_code == 202
    confirmed = client.post('/api/auth/mobile/change/confirm', headers=bearer(token), json={
        'new_mobile': '9555555555', 'code': codes[-1][1],
    })
    assert confirmed.status_code == 200
    assert client.get('/api/auth/me', headers=bearer(token)).status_code == 401
    assert login(client).status_code == 401
    assert login(client, '9555555555').status_code == 200


def test_mobile_change_rejects_bad_reauthentication_and_duplicate_number(environment):
    client, codes = environment
    verified_household(client, codes)
    auth_token = login(client).json()['access_token']

    bad_password = client.post(
        '/api/auth/mobile/change/request',
        headers=bearer(auth_token),
        json={'new_mobile': '9555555555', 'current_password': 'wrong-password'},
    )
    assert bad_password.status_code == 401
    assert not [item for item in codes if item[2] == 'mobile_change']

    client.post('/api/auth/register/household', json={
        'full_name': 'Second Household', 'mobile': '9888888888',
        'locality_id': 'cowl_bazar', 'password': 'OtherPass123456!',
    })
    duplicate = client.post(
        '/api/auth/mobile/change/request',
        headers=bearer(auth_token),
        json={
            'new_mobile': '9888888888',
            'current_password': 'TestPass123456!',
        },
    )
    assert duplicate.status_code == 409
    assert not [item for item in codes if item[2] == 'mobile_change']


def test_mobile_change_preserves_role_and_linked_google_identity(environment):
    client, codes = environment
    db['users'].insert_one({
        'user_id': str(uuid4()), 'mobile': '+919666666666',
        'full_name': 'Collector User', 'password_hash': hash_password('CollectorPass123!'),
        'google_sub': 'collector-google-sub', 'role': 'collector',
        'status': 'active', 'phone_verified': True,
    })
    session = login(client, '9666666666', 'CollectorPass123!').json()
    request = client.post('/api/auth/mobile/change/request', headers=bearer(
        session['access_token'],
    ), json={
        'new_mobile': '9555555555',
        'current_password': 'CollectorPass123!',
    })
    assert request.status_code == 202
    changed = client.post('/api/auth/mobile/change/confirm', headers=bearer(
        session['access_token'],
    ), json={
        'new_mobile': '9555555555',
        'code': codes[-1][1],
    })
    assert changed.status_code == 200
    user = db['users'].find_one({'mobile': '+919555555555'})
    assert user['role'] == 'collector'
    assert user['google_sub'] == 'collector-google-sub'
    assert user['phone_verified'] is True


def test_google_only_user_can_reauthenticate_for_mobile_change(environment, monkeypatch):
    client, codes = environment
    user_id = str(uuid4())
    db['users'].insert_one({
        'user_id': user_id, 'mobile': '+919876543210',
        'full_name': 'Google Household', 'google_sub': 'google-subject-1',
        'role': 'household', 'status': 'active', 'phone_verified': True,
    })
    issued_at = int(now_utc().timestamp())
    monkeypatch.setattr(
        auth_module, '_verify_google_id_token',
        lambda token: {'sub': 'google-subject-1', 'iat': issued_at},
    )
    session = client.post('/api/auth/google/login', json={
        'id_token': 'a-valid-google-id-token-for-tests',
    }).json()
    request = client.post('/api/auth/mobile/change/request', headers=bearer(
        session['access_token'],
    ), json={
        'new_mobile': '9555555555',
        'google_id_token': 'fresh-google-id-token',
    })
    assert request.status_code == 202
    changed = client.post('/api/auth/mobile/change/confirm', headers=bearer(
        session['access_token'],
    ), json={
        'new_mobile': '9555555555',
        'code': codes[-1][1],
    })
    assert changed.status_code == 200
    user = db['users'].find_one({'user_id': user_id})
    assert user['role'] == 'household'
    assert user['google_sub'] == 'google-subject-1'
    assert 'password_hash' not in user


def test_concurrent_mobile_changes_allow_only_one_pending_number(environment):
    client, _ = environment
    verified_household(client, _)
    token = login(client).json()['access_token']

    def request_change(new_mobile):
        return client.post(
            '/api/auth/mobile/change/request',
            headers=bearer(token),
            json={
                'new_mobile': new_mobile,
                'current_password': 'TestPass123456!',
            },
        ).status_code

    with ThreadPoolExecutor(max_workers=2) as pool:
        statuses = list(pool.map(
            request_change, ['9555555555', '9666666666'],
        ))

    assert sorted(statuses) == [202, 409]
    assert len(db['auth_mobile_changes'].items) == 1


def test_public_role_field_cannot_create_admin(environment):
    client, codes = environment
    request = {
        'full_name': 'Test User', 'mobile': '9876543210',
        'locality_id': 'cowl_bazar', 'password': 'TestPass123456!',
        'role': 'admin', 'status': 'active', 'phone_verified': True,
    }
    result = client.post('/api/auth/register/household', json=request)
    assert result.status_code == 202
    pending = db['users'].find_one({'mobile': '+919876543210'})
    assert pending['role'] == 'household'
    assert pending['status'] == 'pending_phone'
    assert pending['phone_verified'] is False


def test_otp_lockout_after_five_invalid_attempts(environment):
    client, codes = environment
    assert register_household(client).status_code == 202
    correct_code = codes[-1][1]
    wrong_code = '000000' if correct_code != '000000' else '000001'
    for _ in range(5):
        response = client.post('/api/auth/otp/verify', json={
            'mobile': '9876543210', 'purpose': 'registration', 'code': wrong_code,
        })
        assert response.status_code == 400
    assert client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'registration', 'code': correct_code,
    }).status_code == 400
    assert login(client).status_code == 403


def test_duplicate_mobile_and_otp_resend_cooldown(environment):
    client, codes = environment
    assert register_household(client).status_code == 202
    assert register_household(client).status_code == 409
    assert client.post('/api/auth/otp/resend', json={'mobile': '9876543210'}).status_code == 429


def test_expired_otp_cannot_activate_household(environment):
    client, codes = environment
    assert register_household(client).status_code == 202
    db['auth_otp_challenges'].update_one(
        {'mobile': '+919876543210', 'purpose': 'registration'},
        {'$set': {'expires_at': now_utc() - timedelta(seconds=1)}},
    )
    result = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210', 'purpose': 'registration', 'code': codes[-1][1],
    })
    assert result.status_code == 400
    assert login(client).status_code == 403


def test_otp_send_rate_limit_applies_across_accounts_and_ip(environment, monkeypatch):
    client, _ = environment
    monkeypatch.setitem(OTP_RATE_LIMITS['send'], 'ip', 1)
    first = client.post('/api/auth/register/household', json={
        'full_name': 'First User', 'mobile': '9876543210',
        'locality_id': 'cowl_bazar', 'password': 'TestPass123456!',
    })
    assert first.status_code == 202
    second = client.post('/api/auth/register/household', json={
        'full_name': 'Second User', 'mobile': '9876543211',
        'locality_id': 'cowl_bazar', 'password': 'TestPass123456!',
    })
    assert second.status_code == 429


def test_otp_resend_ip_limit_counts_ineligible_requests(environment, monkeypatch):
    client, _ = environment
    monkeypatch.setitem(OTP_RATE_LIMITS['send'], 'ip', 1)

    first = client.post('/api/auth/otp/resend', json={'mobile': '9876543210'})
    second = client.post('/api/auth/otp/resend', json={'mobile': '9876543211'})

    assert first.status_code == 202
    assert second.status_code == 429


def test_provider_rejection_does_not_leave_activated_account(environment, monkeypatch):
    client, _ = environment

    def reject_delivery(mobile, code, purpose):
        raise HTTPException(status_code=503, detail='SMS delivery unavailable')

    monkeypatch.setattr(sms, 'send_verification_code', reject_delivery)
    response = register_household(client)

    assert response.status_code == 503
    assert db['users'].find_one({'mobile': '+919876543210'}) is None
    assert db['auth_otp_challenges'].find_one({
        'mobile': '+919876543210', 'purpose': 'registration',
    }) is None
    assert 'code' not in response.text.lower()


def test_otp_verify_rate_limit_applies_per_mobile_and_ip(environment):
    _, _ = environment
    for _ in range(10):
        _enforce_otp_rate_limits(
            db, action='verify', mobile='+919876543210', client_ip='192.0.2.1',
        )
    with pytest.raises(HTTPException) as mobile_limit:
        _enforce_otp_rate_limits(
            db, action='verify', mobile='+919876543210', client_ip='192.0.2.2',
        )
    assert mobile_limit.value.status_code == 429

    for index in range(100):
        _enforce_otp_rate_limits(
            db, action='verify', mobile=f'+91987654{index:04d}',
            client_ip='192.0.2.3',
        )
    with pytest.raises(HTTPException) as ip_limit:
        _enforce_otp_rate_limits(
            db, action='verify', mobile='+919876543210', client_ip='192.0.2.3',
        )
    assert ip_limit.value.status_code == 429


def test_msg91_sends_local_otp_with_approved_template(monkeypatch):
    monkeypatch.setenv('AUTH_SMS_PROVIDER', 'msg91')
    monkeypatch.setenv('AUTH_SMS_MSG91_AUTH_KEY', 'test-auth-key')
    monkeypatch.setenv('AUTH_SMS_MSG91_TEMPLATE_ID', 'test-template')
    requests = []

    def post(url, **kwargs):
        requests.append((url, kwargs))
        return httpx.Response(
            200,
            json={'type': 'success', 'message': 'accepted'},
            request=httpx.Request('POST', url),
        )

    monkeypatch.setattr(sms.httpx, 'post', post)
    sms.send_verification_code('+919876543210', '012345', 'registration')

    url, request = requests[0]
    assert url == sms.MSG91_FLOW_URL
    assert request['headers']['authkey'] == 'test-auth-key'
    assert request['json'] == {
        'template_id': 'test-template',
        'realTimeResponse': '1',
        'recipients': [{'mobiles': '919876543210', 'VAR1': '012345'}],
    }


def test_msg91_rejection_timeout_and_missing_configuration_fail(monkeypatch):
    monkeypatch.setenv('AUTH_SMS_PROVIDER', 'msg91')
    monkeypatch.setenv('AUTH_SMS_MSG91_AUTH_KEY', 'test-auth-key')
    monkeypatch.setenv('AUTH_SMS_MSG91_TEMPLATE_ID', 'test-template')
    code = '654321'
    monkeypatch.setattr(
        sms.httpx,
        'post',
        lambda url, **kwargs: httpx.Response(
            200,
            json={'type': 'error', 'message': code},
            request=httpx.Request('POST', url),
        ),
    )
    with pytest.raises(HTTPException) as rejection:
        sms.send_verification_code('+919876543210', code, 'registration')
    assert rejection.value.status_code == 503
    assert code not in rejection.value.detail

    def timeout(url, **kwargs):
        raise httpx.TimeoutException('provider timeout')

    monkeypatch.setattr(sms.httpx, 'post', timeout)
    with pytest.raises(HTTPException) as timeout_error:
        sms.send_verification_code('+919876543210', code, 'registration')
    assert timeout_error.value.status_code == 503
    assert code not in timeout_error.value.detail

    monkeypatch.delenv('AUTH_SMS_MSG91_TEMPLATE_ID')
    with pytest.raises(HTTPException) as missing_config:
        sms.require_sms_provider()
    assert missing_config.value.status_code == 503


def test_msg91_rejects_non_indian_numbers(monkeypatch):
    monkeypatch.setenv('AUTH_SMS_PROVIDER', 'msg91')
    monkeypatch.setenv('AUTH_SMS_MSG91_AUTH_KEY', 'test-auth-key')
    monkeypatch.setenv('AUTH_SMS_MSG91_TEMPLATE_ID', 'test-template')
    with pytest.raises(HTTPException) as invalid_mobile:
        sms.send_verification_code('+12025550123', '123456', 'registration')
    assert invalid_mobile.value.status_code == 422


def test_mocked_google_household_registration_requires_mobile_verification(
        environment, monkeypatch):
    client, codes = environment
    monkeypatch.setattr(
        auth_module, '_verify_google_id_token',
        lambda token: {'sub': 'google-sub-household'},
    )

    registered = client.post('/api/auth/google/register', json={
        'id_token': 'mocked-google-id-token-value',
        'full_name': 'Google Household',
        'mobile': '9876543210',
        'locality_id': 'cowl_bazar',
        'role': 'admin',
        'status': 'active',
    })

    assert registered.status_code == 202, registered.text
    pending = db['users'].find_one({'mobile': '+919876543210'})
    assert pending['role'] == 'household'
    assert pending['status'] == 'pending_phone'
    assert pending['phone_verified'] is False
    assert 'password_hash' not in pending
    assert client.post('/api/auth/google/login', json={
        'id_token': 'mocked-google-id-token-value',
    }).status_code == 403
    assert db['auth_sessions'].items == []
    assert codes[-1][2] == 'registration'

    verified = client.post('/api/auth/otp/verify', json={
        'mobile': '9876543210',
        'purpose': 'registration',
        'code': codes[-1][1],
    })
    assert verified.status_code == 200
    assert verified.json()['account_status'] == 'active'

    logged_in = client.post('/api/auth/google/login', json={
        'id_token': 'mocked-google-id-token-value',
    })
    assert logged_in.status_code == 200, logged_in.text
    assert logged_in.json()['user']['role'] == 'household'
    assert client.get(
        '/api/auth/me',
        headers=bearer(logged_in.json()['access_token']),
    ).json()['role'] == 'household'


def test_mocked_google_registration_rejects_duplicate_mobile_and_subject(
        environment, monkeypatch):
    client, codes = environment
    verified_household(client, codes)
    monkeypatch.setattr(
        auth_module, '_verify_google_id_token',
        lambda token: {'sub': 'google-sub-duplicate'},
    )

    same_mobile = client.post('/api/auth/google/register', json={
        'id_token': 'mocked-google-id-token-value',
        'full_name': 'Other User',
        'mobile': '9876543210',
        'locality_id': 'cowl_bazar',
    })
    assert same_mobile.status_code == 409
    assert db['users'].find_one({'mobile': '+919876543210'}).get('google_sub') is None

    first_identity = client.post('/api/auth/google/register', json={
        'id_token': 'mocked-google-id-token-value',
        'full_name': 'Google User',
        'mobile': '9888888888',
        'locality_id': 'cowl_bazar',
    })
    assert first_identity.status_code == 202
    duplicate_identity = client.post('/api/auth/google/register', json={
        'id_token': 'mocked-google-id-token-value',
        'full_name': 'Another Google User',
        'mobile': '9777777777',
        'locality_id': 'cowl_bazar',
    })
    assert duplicate_identity.status_code == 409
    assert db['users'].find_one({'mobile': '+919777777777'}) is None


def test_mocked_google_link_reauthenticates_and_preserves_role(
        environment, monkeypatch):
    client, codes = environment
    trader_mobile = '+919888888888'
    db['users'].insert_one({
        'user_id': str(uuid4()),
        'mobile': trader_mobile,
        'full_name': 'Verified Trader',
        'password_hash': hash_password('TraderPass123!'),
        'role': 'trader',
        'status': 'active',
        'phone_verified': True,
    })
    trader_token = login(client, '9888888888', 'TraderPass123!').json()['access_token']
    monkeypatch.setattr(
        auth_module, '_verify_google_id_token',
        lambda token: {'sub': 'google-sub-trader'},
    )

    wrong_password = client.post(
        '/api/auth/google/link',
        headers=bearer(trader_token),
        json={
            'id_token': 'mocked-google-id-token-value',
            'password': 'WrongPassword123!',
        },
    )
    assert wrong_password.status_code == 401

    linked = client.post(
        '/api/auth/google/link',
        headers=bearer(trader_token),
        json={
            'id_token': 'mocked-google-id-token-value',
            'password': 'TraderPass123!',
        },
    )
    assert linked.status_code == 200
    assert db['users'].find_one({'mobile': trader_mobile})['google_sub'] == 'google-sub-trader'

    google_login = client.post('/api/auth/google/login', json={
        'id_token': 'mocked-google-id-token-value',
    })
    assert google_login.status_code == 200
    assert google_login.json()['user']['role'] == 'trader'

    verified_household(client, codes)
    household_token = login(client).json()['access_token']
    conflict = client.post(
        '/api/auth/google/link',
        headers=bearer(household_token),
        json={
            'id_token': 'mocked-google-id-token-value',
            'password': 'TestPass123456!',
        },
    )
    assert conflict.status_code == 409
    assert db['users'].find_one({'mobile': '+919876543210'}).get('google_sub') is None

    db['users'].update_one(
        {'mobile': trader_mobile},
        {'$set': {'status': 'suspended'}},
    )
    assert client.post('/api/auth/google/login', json={
        'id_token': 'mocked-google-id-token-value',
    }).status_code == 403


def test_mocked_google_token_verification_checks_configured_audiences_and_failures(
        monkeypatch):
    monkeypatch.setenv(
        'AUTH_GOOGLE_CLIENT_IDS',
        'web-client.apps.googleusercontent.com, android-client.apps.googleusercontent.com',
    )
    verified = {}

    def accept_token(token, request, audience):
        verified['token'] = token
        verified['audience'] = audience
        return {'sub': 'stable-google-sub'}

    monkeypatch.setattr(
        auth_module.google_id_token,
        'verify_oauth2_token',
        accept_token,
    )
    assert auth_module._verify_google_id_token('mocked-google-id-token-value')['sub'] == 'stable-google-sub'
    assert verified['audience'] == [
        'web-client.apps.googleusercontent.com',
        'android-client.apps.googleusercontent.com',
    ]

    def reject_expired_token(token, request, audience):
        raise ValueError('expired')

    monkeypatch.setattr(
        auth_module.google_id_token,
        'verify_oauth2_token',
        reject_expired_token,
    )
    with pytest.raises(HTTPException) as expired:
        auth_module._verify_google_id_token('mocked-google-id-token-value')
    assert expired.value.status_code == 401

    def verification_unavailable(token, request, audience):
        raise auth_module.TransportError('network unavailable')

    monkeypatch.setattr(
        auth_module.google_id_token,
        'verify_oauth2_token',
        verification_unavailable,
    )
    with pytest.raises(HTTPException) as unavailable:
        auth_module._verify_google_id_token('mocked-google-id-token-value')
    assert unavailable.value.status_code == 503

    monkeypatch.delenv('AUTH_GOOGLE_CLIENT_IDS')
    with pytest.raises(HTTPException) as missing_config:
        auth_module._verify_google_id_token('mocked-google-id-token-value')
    assert missing_config.value.status_code == 503
