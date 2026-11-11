"""Offline auth API tests: no MongoDB Atlas, SMS provider, or network required.

Run from repository root: python -m pytest backend/tests/test_auth_offline.py -q
"""
from copy import deepcopy
from datetime import timedelta
from types import SimpleNamespace
from uuid import uuid4
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from backend.app.auth import sms
from backend.app.auth.dependencies import get_auth_db
from backend.app.auth.security import hash_password, now_utc, random_secret, token_digest
from backend.app.routers.auth import initialize_auth_indexes, router


class FakeCollection:
    def __init__(self):
        self.items = []

    def create_index(self, *args, **kwargs):
        return 'index'

    def _match(self, document, query):
        for key, expected in query.items():
            current = document.get(key)
            if isinstance(expected, dict):
                for op, bound in expected.items():
                    if current is None or not {
                        '$gt': lambda: current > bound,
                        '$lt': lambda: current < bound,
                    }[op]():
                        return False
            elif current != expected:
                return False
        return True

    def find_one(self, query):
        return next((deepcopy(x) for x in self.items if self._match(x, query)), None)

    def insert_one(self, doc):
        data = deepcopy(doc)
        data.setdefault('_id', str(uuid4()))
        if self is db['users'] and any(
                x.get('mobile') == data.get('mobile') for x in self.items):
            from pymongo.errors import DuplicateKeyError
            raise DuplicateKeyError('duplicate mobile')
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

    def _update(self, item, update):
        for key, value in update.get('$set', {}).items():
            item[key] = value
        for key, value in update.get('$inc', {}).items():
            item[key] = item.get(key, 0) + value

    def update_one(self, query, update):
        for item in self.items:
            if self._match(item, query):
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

    def find_one_and_update(self, query, update, return_document=None):
        for item in self.items:
            if self._match(item, query):
                old = deepcopy(item)
                self._update(item, update)
                return old
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


def test_household_register_verify_login_and_logout(environment):
    client, codes = environment
    assert client.get('/api/auth/me').status_code == 401
    assert login(client).status_code == 401
    registered = register_household(client)
    assert registered.status_code == 202
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
    token = login(client).json()['access_token']
    request = client.post('/api/auth/mobile/change/request', headers=bearer(token), json={
        'new_mobile': '9555555555',
    })
    assert request.status_code == 202
    confirmed = client.post('/api/auth/mobile/change/confirm', headers=bearer(token), json={
        'new_mobile': '9555555555', 'code': codes[-1][1],
    })
    assert confirmed.status_code == 200
    assert client.get('/api/auth/me', headers=bearer(token)).status_code == 401
    assert login(client).status_code == 401
    assert login(client, '9555555555').status_code == 200


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
