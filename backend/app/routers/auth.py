"""Authentication APIs for the EXISTING ScrapWise FastAPI application.

No public role selection or admin registration. SMS delivery is disabled until
an actual provider is configured. API clients never choose their own roles.
"""
from datetime import datetime, timedelta
from functools import partial
import os
import secrets
from threading import BoundedSemaphore
from uuid import uuid4

from google.auth.exceptions import GoogleAuthError, TransportError
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.routing import APIRoute
from pymongo import ASCENDING, ReturnDocument
from pymongo.errors import DuplicateKeyError, PyMongoError

from backend.app.auth import sms
from backend.app.auth.dependencies import (
    bearer, current_user, get_auth_db, require_roles, session_account_is_active,
)
from backend.app.auth.schemas import (
    ChangeMobileConfirm, ChangeMobileRequest, CollectorActivation,
    GoogleHouseholdRegistration, GoogleLinkRequest, GoogleTokenRequest,
    HouseholdRegistration, InvitationOtpRequest, InviteCollector,
    LoginRequest, LoginResponse, LogoutRequest, MobileRequest, PasswordReset,
    RefreshRequest, ResendOtp, TraderApplication, UserResponse, VerifyOtp,
)
from backend.app.auth.security import (
    aware_utc, compare_digest, hash_password, now_utc, otp_digest, random_secret,
    token_digest, verify_password,
)

_VALIDATION_MESSAGES = {
    'missing': 'Field required',
    'string_type': 'Expected a string',
    'string_too_short': 'Value is too short',
    'string_too_long': 'Value is too long',
    'string_pattern_mismatch': 'Invalid format',
    'literal_error': 'Unsupported value',
    'json_invalid': 'Malformed JSON',
}


class AuthRoute(APIRoute):
    def get_route_handler(self):
        handle = super().get_route_handler()

        async def handle_auth(request: Request):
            try:
                return await handle(request)
            except RequestValidationError as error:
                # Error inputs, context, and custom messages can contain credentials.
                detail = [
                    {
                        'loc': item['loc'],
                        'msg': _VALIDATION_MESSAGES.get(item['type'], 'Invalid value'),
                        'type': item['type'],
                    }
                    for item in error.errors()
                ]
                return JSONResponse(
                    status_code=422, content={'detail': detail},
                    headers={'Cache-Control': 'no-store'},
                )

        return handle_auth


router = APIRouter(prefix='/api/auth', tags=['Authentication'], route_class=AuthRoute)
OTP_EXPIRY = timedelta(minutes=5)
OTP_COOLDOWN = timedelta(seconds=60)
OTP_ATTEMPTS = 5
OTP_RATE_WINDOW = timedelta(hours=1)
OTP_RATE_LIMITS = {
    'send': {'mobile': 5, 'ip': 30},
    'verify': {'mobile': 10, 'ip': 100},
    'reset': {'mobile': 10, 'ip': 100},
}
LOGIN_RATE_WINDOW_SECONDS = 900
LOGIN_ACCOUNT_LIMIT = 10
LOGIN_CLIENT_LIMIT = 50
PASSWORD_VERIFICATION_SLOTS = BoundedSemaphore(2)
SESSION_EXPIRY = timedelta(hours=1)
REFRESH_EXPIRY = timedelta(days=30)
RESET_EXPIRY = timedelta(minutes=10)
INVITATION_EXPIRY = timedelta(days=7)
GOOGLE_TOKEN_VERIFY_TIMEOUT_SECONDS = 5


def initialize_auth_indexes(database=None) -> None:
    """Call once at startup. Existing user records must be checked before unique indexes."""
    if database is None:
        from backend.app.database import db
        database = db
    database['users'].create_index('mobile', unique=True, name='users_unique_mobile')
    database['users'].create_index('user_id', unique=True, name='users_unique_id')
    database['users'].create_index(
        'google_sub', unique=True, sparse=True, name='users_unique_google_sub',
    )
    database['auth_sessions'].create_index('token_hash', unique=True)
    database['auth_sessions'].create_index(
        'refresh_token_hash', unique=True, sparse=True,
    )
    database['auth_sessions'].create_index('used_refresh_token_hashes')
    database['auth_sessions'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_login_attempts'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_otp_challenges'].create_index(
        [('purpose', ASCENDING), ('mobile', ASCENDING), ('subject', ASCENDING)],
        unique=True, name='otp_unique_purpose_mobile_subject',
    )
    database['auth_otp_challenges'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_reset_grants'].create_index('token_hash', unique=True)
    database['auth_reset_grants'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_mobile_changes'].create_index('user_id', unique=True)
    database['auth_mobile_changes'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_collector_invitations'].create_index('token_hash', unique=True)
    database['auth_collector_invitations'].create_index('expires_at', expireAfterSeconds=0)


def _public_user(user: dict) -> UserResponse:
    return UserResponse(
        user_id=user['user_id'], mobile=user['mobile'], role=user['role'],
        status=user['status'], phone_verified=bool(user.get('phone_verified')),
        full_name=user.get('full_name'),
    )


def _client_ip(request: Request) -> str:
    return request.client.host if request.client else 'unknown'


def _enforce_otp_rate_limits(
    database,
    *,
    action: str,
    mobile: str,
    client_ip: str,
) -> None:
    """Apply fixed UTC-hour limits using the existing TTL-indexed OTP collection."""
    now = now_utc()
    bucket = int(now.timestamp()) // int(OTP_RATE_WINDOW.total_seconds())
    retry_after = (bucket + 1) * int(OTP_RATE_WINDOW.total_seconds()) - int(now.timestamp())
    exceeded = False
    collection = database['auth_otp_challenges']

    for scope, value in (('mobile', mobile), ('ip', client_ip or 'unknown')):
        purpose = f'__rate_{action}_{scope}'
        query = {
            'purpose': purpose,
            'mobile': otp_digest(purpose, value, str(bucket)),
            'subject': str(bucket),
        }
        update = {
            '$inc': {'count': 1},
            '$setOnInsert': {
                'record_type': 'rate_limit',
                'created_at': now,
                'expires_at': now + timedelta(seconds=retry_after + 60),
            },
        }
        try:
            record = collection.find_one_and_update(
                query,
                update,
                upsert=True,
                return_document=ReturnDocument.AFTER,
            )
        except DuplicateKeyError:
            record = collection.find_one_and_update(
                query,
                {'$inc': {'count': 1}},
                return_document=ReturnDocument.AFTER,
            )
        if record is None:
            raise HTTPException(
                status_code=503,
                detail='OTP rate limiting is temporarily unavailable',
            )
        exceeded = exceeded or record['count'] > OTP_RATE_LIMITS[action][scope]

    if exceeded:
        raise HTTPException(
            status_code=429,
            detail='Too many OTP requests. Please try again later',
            headers={'Retry-After': str(retry_after)},
        )


def _create_pending_user(database, *, mobile: str, name: str, password: str,
                         role: str, extra: dict):
    if database['users'].find_one({'mobile': mobile}):
        raise HTTPException(status_code=409, detail='Mobile number already registered')
    now = now_utc()
    user = {
        'user_id': str(uuid4()), 'mobile': mobile, 'full_name': name.strip(),
        'password_hash': hash_password(password), 'role': role,
        'status': 'pending_phone', 'phone_verified': False,
        'created_at': now, 'updated_at': now, **extra,
    }
    try:
        database['users'].insert_one(user)
    except DuplicateKeyError as exc:
        raise HTTPException(status_code=409, detail='Mobile number already registered') from exc
    return user


def _google_client_ids() -> list[str]:
    client_ids = [
        value.strip()
        for value in os.getenv('AUTH_GOOGLE_CLIENT_IDS', '').split(',')
        if value.strip()
    ]
    if not client_ids:
        raise HTTPException(status_code=503, detail='Google sign-in is not configured')
    return client_ids


def _verify_google_id_token(token: str) -> dict:
    try:
        claims = google_id_token.verify_oauth2_token(
            token,
            partial(
                google_requests.Request(),
                timeout=GOOGLE_TOKEN_VERIFY_TIMEOUT_SECONDS,
            ),
            audience=_google_client_ids(),
        )
    except TransportError as exc:
        raise HTTPException(
            status_code=503,
            detail='Google identity verification is temporarily unavailable',
        ) from exc
    except (GoogleAuthError, ValueError) as exc:
        raise HTTPException(status_code=401, detail='Invalid Google identity token') from exc

    subject = claims.get('sub') if isinstance(claims, dict) else None
    if not isinstance(subject, str) or not subject:
        raise HTTPException(status_code=401, detail='Invalid Google identity token')
    return claims


def _issue_otp(database, mobile: str, purpose: str, *, subject: str = ''):
    """Persist a digest, deliver, and roll back the challenge on provider failure."""
    sms.require_sms_provider()
    now = now_utc()
    code = f'{secrets.randbelow(1_000_000):06d}'
    digest = otp_digest(purpose, mobile, code, subject)
    challenge_id = str(uuid4())
    challenge = {
        'challenge_id': challenge_id, 'mobile': mobile,
        'purpose': purpose, 'subject': subject,
        'code_hash': digest, 'attempts': 0,
        'created_at': now, 'expires_at': now + OTP_EXPIRY,
    }
    try:
        reserved = database['auth_otp_challenges'].find_one_and_update(
            {
                'mobile': mobile,
                'purpose': purpose,
                'subject': subject,
                'created_at': {'$lte': now - OTP_COOLDOWN},
            },
            {'$set': challenge},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
    except DuplicateKeyError as exc:
        raise HTTPException(
            status_code=429,
            detail='Please wait before requesting another code',
            headers={'Retry-After': str(int(OTP_COOLDOWN.total_seconds()))},
        ) from exc
    if reserved is None:
        raise HTTPException(
            status_code=503,
            detail='OTP challenge could not be reserved',
        )
    try:
        sms.send_verification_code(mobile, code, purpose)
    except HTTPException:
        database['auth_otp_challenges'].delete_one({'challenge_id': challenge_id})
        raise


def _consume_otp(database, mobile: str, purpose: str, code: str, *, subject: str = ''):
    now = now_utc()
    challenge = database['auth_otp_challenges'].find_one_and_update(
        {
            'mobile': mobile, 'purpose': purpose, 'subject': subject,
            'expires_at': {'$gt': now}, 'attempts': {'$lt': OTP_ATTEMPTS},
        },
        {'$inc': {'attempts': 1}},
        return_document=ReturnDocument.BEFORE,
    )
    if not challenge:
        raise HTTPException(status_code=400, detail='Invalid or expired verification code')
    digest = otp_digest(purpose, mobile, code, subject)
    if not compare_digest(digest, challenge['code_hash']):
        raise HTTPException(status_code=400, detail='Invalid or expired verification code')
    consumed = database['auth_otp_challenges'].delete_one({'challenge_id': challenge['challenge_id']})
    if consumed.deleted_count != 1:
        raise HTTPException(status_code=409, detail='Verification code already used')


def _make_session(database, user: dict) -> LoginResponse:
    access_token = random_secret()
    refresh_token = random_secret()
    now = now_utc()
    database['auth_sessions'].insert_one({
        'session_id': str(uuid4()), 'user_id': user['user_id'],
        'auth_version': user.get('auth_version', 0),
        'token_hash': token_digest(access_token),
        'access_expires_at': now + SESSION_EXPIRY,
        'refresh_token_hash': token_digest(refresh_token),
        'used_refresh_token_hashes': [],
        'created_at': now,
        'expires_at': now + REFRESH_EXPIRY,
        'revoked': False,
    })
    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=int(SESSION_EXPIRY.total_seconds()),
        refresh_expires_in=int(REFRESH_EXPIRY.total_seconds()),
        user=_public_user(user),
    )


@router.post('/register/household', status_code=202)
def register_household(payload: HouseholdRegistration, request: Request,
                       database=Depends(get_auth_db)):
    sms.require_sms_provider()  # Fail before creating an unusable account.
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    user = _create_pending_user(
        database, mobile=payload.mobile, name=payload.full_name,
        password=payload.password, role='household',
        extra={'locality_id': payload.locality_id.strip()},
    )
    try:
        _issue_otp(database, user['mobile'], 'registration')
    except Exception:
        database['users'].delete_one({'user_id': user['user_id'], 'status': 'pending_phone'})
        raise
    return {'message': 'Verification code request accepted', 'status': 'pending_phone'}


@router.post('/google/register', status_code=202)
def register_google_household(
    payload: GoogleHouseholdRegistration,
    request: Request,
    database=Depends(get_auth_db),
):
    claims = _verify_google_id_token(payload.id_token)
    subject = claims['sub']
    if database['users'].find_one({'google_sub': subject}):
        raise HTTPException(status_code=409, detail='Google identity already registered')
    if database['users'].find_one({'mobile': payload.mobile}):
        raise HTTPException(status_code=409, detail='Mobile number already registered')

    sms.require_sms_provider()
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    now = now_utc()
    user = {
        'user_id': str(uuid4()),
        'mobile': payload.mobile,
        'full_name': payload.full_name.strip(),
        'role': 'household',
        'status': 'pending_phone',
        'phone_verified': False,
        'locality_id': payload.locality_id.strip(),
        'google_sub': subject,
        'created_at': now,
        'updated_at': now,
    }
    try:
        database['users'].insert_one(user)
    except DuplicateKeyError as exc:
        raise HTTPException(
            status_code=409,
            detail='Google identity or mobile number already registered',
        ) from exc

    try:
        _issue_otp(database, user['mobile'], 'registration')
    except Exception:
        database['users'].delete_one({
            'user_id': user['user_id'],
            'status': 'pending_phone',
        })
        raise
    return {'message': 'Verification code request accepted', 'status': 'pending_phone'}


@router.post('/trader/apply', status_code=202)
def apply_trader(payload: TraderApplication, request: Request,
                 database=Depends(get_auth_db)):
    sms.require_sms_provider()
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    user = _create_pending_user(
        database, mobile=payload.mobile, name=payload.full_name,
        password=payload.password, role='trader', extra={
            'business_name': payload.business_name.strip(),
            'business_address': payload.business_address.strip(),
        },
    )
    try:
        _issue_otp(database, user['mobile'], 'registration')
    except Exception:
        database['users'].delete_one({'user_id': user['user_id'], 'status': 'pending_phone'})
        raise
    return {'message': 'Verification code request accepted', 'status': 'pending_phone'}


@router.post('/otp/resend', status_code=202)
def resend_otp(payload: ResendOtp, request: Request, database=Depends(get_auth_db)):
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    user = database['users'].find_one({'mobile': payload.mobile, 'status': 'pending_phone'})
    if user:
        _issue_otp(database, payload.mobile, 'registration')
    return {'message': 'If eligible, the verification code request was accepted'}


@router.post('/otp/verify')
def verify_otp(payload: VerifyOtp, request: Request, database=Depends(get_auth_db)):
    _enforce_otp_rate_limits(
        database, action='verify', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    if payload.purpose == 'registration':
        user = database['users'].find_one({'mobile': payload.mobile, 'status': 'pending_phone'})
        if not user:
            raise HTTPException(status_code=400, detail='Account is not awaiting verification')
        _consume_otp(database, payload.mobile, 'registration', payload.code)
        next_status = 'pending_approval' if user['role'] == 'trader' else 'active'
        result = database['users'].update_one({'user_id': user['user_id'], 'status': 'pending_phone'}, {
            '$set': {'phone_verified': True, 'status': next_status, 'updated_at': now_utc()},
        })
        if not result.matched_count:
            raise HTTPException(status_code=409, detail='Account status changed during verification')
        return {'message': 'Mobile verified', 'account_status': next_status}
    user = database['users'].find_one({
        'mobile': payload.mobile, 'phone_verified': True,
    })
    if not user or not user.get('password_hash'):
        raise HTTPException(status_code=400, detail='Invalid verification request')
    _consume_otp(database, payload.mobile, 'password_reset', payload.code)
    token = random_secret()
    now = now_utc()
    database['auth_reset_grants'].insert_one({
        'user_id': user['user_id'], 'mobile': user['mobile'],
        'token_hash': token_digest(token),
        'created_at': now, 'expires_at': now + RESET_EXPIRY,
    })
    return {'reset_token': token, 'expires_in': 600}


def _increment_rate_counter(collection, key: dict, expires_at: datetime) -> dict | None:
    increment = {'$inc': {'count': 1}}
    try:
        return collection.find_one_and_update(
            key,
            {**increment, '$setOnInsert': {'expires_at': expires_at}},
            upsert=True,
            return_document=ReturnDocument.AFTER,
        )
    except DuplicateKeyError:
        return collection.find_one_and_update(
            key, increment, return_document=ReturnDocument.AFTER,
        )


def _enforce_login_rate_limits(database, request: Request, mobile: str) -> None:
    now = now_utc()
    bucket, elapsed = divmod(int(now.timestamp()), LOGIN_RATE_WINDOW_SECONDS)
    retry_after = LOGIN_RATE_WINDOW_SECONDS - elapsed
    expires_at = now + timedelta(seconds=retry_after + 60)
    client_ip = request.client.host if request.client else 'unknown'
    collection = database['auth_login_attempts']

    # Check the client first so a blocked client cannot create account counters.
    for scope, value, limit in (
        ('client', client_ip, LOGIN_CLIENT_LIMIT),
        ('account', mobile, LOGIN_ACCOUNT_LIMIT),
    ):
        key = {'_id': token_digest(f'login|{scope}|{bucket}|{value}')}
        try:
            record = _increment_rate_counter(collection, key, expires_at)
        except PyMongoError:
            record = None
        if record is None:
            raise HTTPException(
                status_code=503, detail='Login temporarily unavailable',
                headers={'Retry-After': '1'},
            )
        if record['count'] > limit:
            raise HTTPException(
                status_code=429, detail='Too many login attempts. Please try again later',
                headers={'Retry-After': str(retry_after)},
            )


@router.post('/login', response_model=LoginResponse)
def login(payload: LoginRequest, request: Request, response: Response,
          database=Depends(get_auth_db)):
    _enforce_login_rate_limits(database, request, payload.mobile)
    user = database['users'].find_one({'mobile': payload.mobile})
    if not PASSWORD_VERIFICATION_SLOTS.acquire(blocking=False):
        raise HTTPException(
            status_code=429, detail='Login is busy. Please try again shortly',
            headers={'Retry-After': '1'},
        )
    try:
        # The verifier performs dummy work for missing accounts and hashes.
        verified = verify_password(payload.password, user.get('password_hash') if user else None)
    finally:
        PASSWORD_VERIFICATION_SLOTS.release()
    if not verified:
        raise HTTPException(status_code=401, detail='Invalid mobile number or password')
    if not user or user.get('status') != 'active' or not user.get('phone_verified'):
        raise HTTPException(status_code=403, detail='Account is not eligible to sign in')
    response.headers['Cache-Control'] = 'no-store'
    return _make_session(database, user)


@router.post('/google/login', response_model=LoginResponse)
def login_with_google(
    payload: GoogleTokenRequest,
    database=Depends(get_auth_db),
):
    claims = _verify_google_id_token(payload.id_token)
    user = database['users'].find_one({'google_sub': claims['sub']})
    if not user:
        raise HTTPException(status_code=404, detail='Google identity is not linked')
    if user.get('status') != 'active' or not user.get('phone_verified'):
        raise HTTPException(status_code=403, detail='Account is not active or verified')
    return _make_session(database, user)


@router.post('/refresh', response_model=LoginResponse)
def refresh_session(payload: RefreshRequest, database=Depends(get_auth_db)):
    now = now_utc()
    old_digest = token_digest(payload.refresh_token)
    access_token = random_secret()
    refresh_token = random_secret()
    session = database['auth_sessions'].find_one_and_update(
        {
            'refresh_token_hash': old_digest,
            'expires_at': {'$gt': now},
            'revoked': False,
        },
        {
            '$set': {
                'token_hash': token_digest(access_token),
                'access_expires_at': now + SESSION_EXPIRY,
                'refresh_token_hash': token_digest(refresh_token),
                'rotated_at': now,
            },
            '$push': {'used_refresh_token_hashes': old_digest},
        },
        return_document=ReturnDocument.AFTER,
    )
    if session is None:
        reused = database['auth_sessions'].find_one({
            'used_refresh_token_hashes': old_digest,
            'expires_at': {'$gt': now},
            'revoked': False,
        })
        if reused:
            database['auth_sessions'].update_one(
                {'session_id': reused['session_id'], 'revoked': False},
                {'$set': {'revoked': True}},
            )
        raise HTTPException(status_code=401, detail='Invalid or expired refresh token')

    user = database['users'].find_one({'user_id': session['user_id']})
    if not session_account_is_active(session, user):
        database['auth_sessions'].update_one(
            {'session_id': session['session_id']},
            {'$set': {'revoked': True}},
        )
        raise HTTPException(status_code=401, detail='Invalid or expired refresh token')

    return LoginResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=int(SESSION_EXPIRY.total_seconds()),
        refresh_expires_in=max(
            0, int((aware_utc(session['expires_at']) - now).total_seconds()),
        ),
        user=_public_user(user),
    )


@router.post('/google/link')
def link_google_identity(
    payload: GoogleLinkRequest,
    database=Depends(get_auth_db),
    user=Depends(current_user),
):
    if user.get('status') != 'active' or not user.get('phone_verified'):
        raise HTTPException(status_code=403, detail='Account is not active or verified')
    if not verify_password(payload.password, user.get('password_hash')):
        raise HTTPException(status_code=401, detail='Reauthentication failed')

    subject = _verify_google_id_token(payload.id_token)['sub']
    linked_user = database['users'].find_one({'google_sub': subject})
    if linked_user and linked_user['user_id'] != user['user_id']:
        raise HTTPException(status_code=409, detail='Google identity is already linked')
    if user.get('google_sub'):
        if user['google_sub'] == subject:
            return {'message': 'Google identity already linked'}
        raise HTTPException(status_code=409, detail='Another Google identity is already linked')

    try:
        result = database['users'].update_one(
            {
                'user_id': user['user_id'],
                'status': 'active',
                'phone_verified': True,
                'google_sub': {'$exists': False},
            },
            {'$set': {'google_sub': subject, 'updated_at': now_utc()}},
        )
    except DuplicateKeyError as exc:
        raise HTTPException(status_code=409, detail='Google identity is already linked') from exc

    if not result.matched_count:
        latest = database['users'].find_one({'user_id': user['user_id']})
        if latest and latest.get('google_sub') == subject:
            return {'message': 'Google identity already linked'}
        raise HTTPException(status_code=409, detail='Account changed; sign in again')
    return {'message': 'Google identity linked'}


@router.get('/me', response_model=UserResponse)
def me(user=Depends(current_user)):
    return _public_user(user)


@router.post('/logout')
def logout(
    payload: LogoutRequest | None = None,
    credentials=Depends(bearer),
    database=Depends(get_auth_db),
):
    session_filters = []
    if credentials and credentials.scheme.lower() == 'bearer':
        session_filters.append({
            'token_hash': token_digest(credentials.credentials),
        })
    if payload and payload.refresh_token:
        refresh_digest = token_digest(payload.refresh_token)
        session_filters.append({
            '$or': [
                {'refresh_token_hash': refresh_digest},
                {'used_refresh_token_hashes': refresh_digest},
            ],
        })
    if session_filters:
        database['auth_sessions'].update_many(
            {'$or': session_filters, 'revoked': False},
            {'$set': {'revoked': True}},
        )
    return {'message': 'Signed out'}


@router.post('/password/forgot', status_code=202)
def forgot_password(payload: MobileRequest, request: Request,
                    database=Depends(get_auth_db)):
    sms.require_sms_provider()
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    user = database['users'].find_one({'mobile': payload.mobile, 'phone_verified': True})
    if user and user.get('password_hash'):
        _issue_otp(database, payload.mobile, 'password_reset')
    return {'message': 'If the account exists, recovery instructions will be sent'}


@router.post('/password/reset')
def reset_password(
    payload: PasswordReset,
    request: Request,
    database=Depends(get_auth_db),
):
    _enforce_otp_rate_limits(
        database, action='reset', mobile=payload.mobile,
        client_ip=_client_ip(request),
    )
    grant = database['auth_reset_grants'].find_one_and_delete({
        'token_hash': token_digest(payload.reset_token),
        'mobile': payload.mobile,
        'expires_at': {'$gt': now_utc()},
    })
    if not grant:
        raise HTTPException(status_code=400, detail='Invalid or expired reset token')
    result = database['users'].update_one({
        'user_id': grant['user_id'],
        'mobile': grant['mobile'],
        'phone_verified': True,
        'password_hash': {'$exists': True},
    }, {
        '$set': {'password_hash': hash_password(payload.new_password), 'updated_at': now_utc()},
        '$inc': {'auth_version': 1},
    })
    if not result.matched_count:
        raise HTTPException(status_code=400, detail='Invalid or expired reset token')
    # Invalidate every other outstanding password-reset grant for this account.
    database['auth_reset_grants'].delete_many({'user_id': grant['user_id']})
    database['auth_sessions'].update_many({'user_id': grant['user_id']}, {'$set': {'revoked': True}})
    return {'message': 'Password changed. Sign in again'}


@router.post('/collector/invitations', status_code=201)
def invite_collector(payload: InviteCollector, database=Depends(get_auth_db),
                     trader=Depends(require_roles('trader'))):
    if database['users'].find_one({'mobile': payload.mobile}):
        raise HTTPException(status_code=409, detail='Mobile number already registered')
    token = random_secret()
    now = now_utc()
    database['auth_collector_invitations'].insert_one({
        'invitation_id': str(uuid4()), 'token_hash': token_digest(token),
        'mobile': payload.mobile, 'full_name': payload.full_name.strip(),
        'invited_by_user_id': trader['user_id'], 'created_at': now,
        'expires_at': now + INVITATION_EXPIRY,
    })
    return {'invitation_token': token, 'expires_in': 7 * 24 * 3600,
            'note': 'Deliver this one-time invitation through a trusted channel'}


def _validate_invitation(database, mobile: str, token: str):
    invite = database['auth_collector_invitations'].find_one({
        'mobile': mobile, 'token_hash': token_digest(token),
        'expires_at': {'$gt': now_utc()},
    })
    if not invite:
        raise HTTPException(status_code=400, detail='Invalid or expired invitation')
    return invite


@router.post('/collector/activate/request-otp', status_code=202)
def collector_activation_otp(payload: InvitationOtpRequest, request: Request,
                             database=Depends(get_auth_db)):
    sms.require_sms_provider()
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    _validate_invitation(database, payload.mobile, payload.invitation_token)
    if database['users'].find_one({'mobile': payload.mobile}):
        raise HTTPException(status_code=409, detail='Mobile number already registered')
    _issue_otp(database, payload.mobile, 'collector_activate',
               subject=token_digest(payload.invitation_token))
    return {'message': 'Verification code request accepted'}


@router.post('/collector/activate', status_code=201)
def activate_collector(payload: CollectorActivation, request: Request,
                        database=Depends(get_auth_db)):
    _enforce_otp_rate_limits(
        database, action='verify', mobile=payload.mobile, client_ip=_client_ip(request),
    )
    invitation = _validate_invitation(database, payload.mobile, payload.invitation_token)
    _consume_otp(database, payload.mobile, 'collector_activate', payload.code,
                 subject=token_digest(payload.invitation_token))
    deleted_invitation = database['auth_collector_invitations'].find_one_and_delete({
        'invitation_id': invitation['invitation_id'], 'token_hash': invitation['token_hash'],
    })
    if not deleted_invitation:
        raise HTTPException(status_code=409, detail='Invitation already used')
    try:
        user = _create_pending_user(database, mobile=payload.mobile,
                 name=invitation['full_name'], password=payload.password,
                 role='collector', extra={'invited_by_user_id': invitation['invited_by_user_id']})
    except HTTPException:
        raise
    database['users'].update_one({'user_id': user['user_id']}, {
        '$set': {'phone_verified': True, 'status': 'active', 'updated_at': now_utc()},
    })
    return {'message': 'Collector account activated'}


@router.post('/mobile/change/request', status_code=202)
def request_mobile_change(payload: ChangeMobileRequest, request: Request,
                          database=Depends(get_auth_db),
                          user=Depends(current_user)):
    sms.require_sms_provider()
    _enforce_otp_rate_limits(
        database, action='send', mobile=payload.new_mobile, client_ip=_client_ip(request),
    )
    if payload.current_password is not None:
        if not user.get('password_hash') or not verify_password(
            payload.current_password, user.get('password_hash'),
        ):
            raise HTTPException(status_code=401, detail='Reauthentication failed')
    else:
        if not payload.google_id_token:
            raise HTTPException(status_code=401, detail='Reauthentication failed')
        claims = _verify_google_id_token(payload.google_id_token)
        issued_at = claims.get('iat')
        now_seconds = int(now_utc().timestamp())
        if (claims.get('sub') != user.get('google_sub')
                or not isinstance(issued_at, (int, float))
                or issued_at > now_seconds + 60
                or now_seconds - issued_at > 300):
            raise HTTPException(status_code=401, detail='Reauthentication failed')

    if payload.new_mobile == user['mobile'] or database['users'].find_one({
        'mobile': payload.new_mobile,
    }):
        raise HTTPException(status_code=409, detail='Mobile number already registered')

    now = now_utc()
    pending = database['auth_mobile_changes'].find_one({
        'user_id': user['user_id'], 'expires_at': {'$gt': now},
    })
    if pending and pending['new_mobile'] != payload.new_mobile:
        raise HTTPException(status_code=409, detail='A mobile change is already pending')
    if pending is None:
        change_id = str(uuid4())
        change = {
            'change_id': change_id,
            'user_id': user['user_id'],
            'old_mobile': user['mobile'],
            'new_mobile': payload.new_mobile,
            'created_at': now,
            'expires_at': now + OTP_EXPIRY,
        }
        try:
            pending = database['auth_mobile_changes'].find_one_and_update(
                {
                    'user_id': user['user_id'],
                    'expires_at': {'$lte': now},
                },
                {'$set': change},
                upsert=True,
                return_document=ReturnDocument.AFTER,
            )
        except DuplicateKeyError:
            pending = database['auth_mobile_changes'].find_one({
                'user_id': user['user_id'], 'expires_at': {'$gt': now},
            })
            if not pending or pending['new_mobile'] != payload.new_mobile:
                raise HTTPException(
                    status_code=409,
                    detail='A mobile change is already pending',
                ) from None
    if pending is None:
        raise HTTPException(status_code=503, detail='Mobile change could not be reserved')
    _issue_otp(
        database, payload.new_mobile, 'mobile_change',
        subject=pending['change_id'],
    )
    return {'message': 'Verification code request accepted for the new mobile number'}


@router.post('/mobile/change/resend', status_code=202)
def resend_mobile_change(request: Request, database=Depends(get_auth_db),
                         user=Depends(current_user)):
    pending = database['auth_mobile_changes'].find_one({
        'user_id': user['user_id'], 'expires_at': {'$gt': now_utc()},
    })
    if not pending:
        raise HTTPException(status_code=400, detail='No active mobile change')
    _enforce_otp_rate_limits(
        database, action='send', mobile=pending['new_mobile'],
        client_ip=_client_ip(request),
    )
    _issue_otp(
        database, pending['new_mobile'], 'mobile_change',
        subject=pending['change_id'],
    )
    return {'message': 'Verification code request accepted'}


@router.post('/mobile/change/confirm')
def confirm_mobile_change(payload: ChangeMobileConfirm, request: Request,
                          database=Depends(get_auth_db),
                          user=Depends(current_user)):
    _enforce_otp_rate_limits(
        database, action='verify', mobile=payload.new_mobile, client_ip=_client_ip(request),
    )
    pending = database['auth_mobile_changes'].find_one({
        'user_id': user['user_id'],
        'new_mobile': payload.new_mobile,
        'expires_at': {'$gt': now_utc()},
    })
    if not pending:
        raise HTTPException(status_code=400, detail='Invalid or expired verification code')
    _consume_otp(
        database, payload.new_mobile, 'mobile_change', payload.code,
        subject=pending['change_id'],
    )
    try:
        result = database['users'].update_one({
            'user_id': user['user_id'],
            'mobile': pending['old_mobile'],
            'status': 'active',
            'phone_verified': True,
        }, {'$set': {
            'mobile': payload.new_mobile,
            'updated_at': now_utc(),
        }, '$inc': {'auth_version': 1}})
    except DuplicateKeyError as exc:
        database['auth_mobile_changes'].delete_one({
            'change_id': pending['change_id'],
        })
        raise HTTPException(status_code=409, detail='Mobile number already registered') from exc
    if not result.matched_count:
        database['auth_mobile_changes'].delete_one({
            'change_id': pending['change_id'],
        })
        raise HTTPException(status_code=409, detail='Account status changed')
    database['auth_mobile_changes'].delete_one({
        'change_id': pending['change_id'],
    })
    database['auth_sessions'].update_many({'user_id': user['user_id']}, {'$set': {'revoked': True}})
    return {'message': 'Mobile number updated. Sign in again'}


@router.post('/admin/traders/{user_id}/approve')
def approve_trader(user_id: str, database=Depends(get_auth_db),
                   admin=Depends(require_roles('admin'))):
    result = database['users'].update_one({
        'user_id': user_id, 'role': 'trader', 'status': 'pending_approval',
        'phone_verified': True,
    }, {'$set': {'status': 'active', 'approved_by_user_id': admin['user_id'],
                'approved_at': now_utc(), 'updated_at': now_utc()}})
    if not result.matched_count:
        raise HTTPException(status_code=409, detail='Trader not eligible for approval')
    return {'message': 'Trader approved'}


@router.post('/admin/traders/{user_id}/reject')
def reject_trader(user_id: str, database=Depends(get_auth_db),
                  admin=Depends(require_roles('admin'))):
    result = database['users'].update_one({
        'user_id': user_id, 'role': 'trader', 'status': 'pending_approval',
    }, {'$set': {'status': 'rejected', 'reviewed_by_user_id': admin['user_id'],
                'updated_at': now_utc()}})
    if not result.matched_count:
        raise HTTPException(status_code=409, detail='Trader not eligible for rejection')
    return {'message': 'Trader application rejected'}
