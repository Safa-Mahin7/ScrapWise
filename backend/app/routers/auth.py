"""Authentication APIs for the EXISTING ScrapWise FastAPI application.

No public role selection or admin registration. SMS delivery is disabled until
an actual provider is configured. API clients never choose their own roles.
"""
from datetime import timedelta
import secrets
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from pymongo import ASCENDING, ReturnDocument
from pymongo.errors import DuplicateKeyError

from backend.app.auth import sms
from backend.app.auth.dependencies import bearer, current_user, get_auth_db, require_roles
from backend.app.auth.schemas import (
    ChangeMobileConfirm, ChangeMobileRequest, CollectorActivation,
    HouseholdRegistration, InvitationOtpRequest, InviteCollector,
    LoginRequest, LoginResponse, MobileRequest, PasswordReset, ResendOtp,
    TraderApplication, UserResponse, VerifyOtp,
)
from backend.app.auth.security import (
    aware_utc, compare_digest, hash_password, now_utc, otp_digest, random_secret,
    token_digest, verify_password,
)

router = APIRouter(prefix='/api/auth', tags=['Authentication'])
OTP_EXPIRY = timedelta(minutes=5)
OTP_COOLDOWN = timedelta(seconds=60)
OTP_ATTEMPTS = 5
SESSION_EXPIRY = timedelta(hours=1)
RESET_EXPIRY = timedelta(minutes=10)
INVITATION_EXPIRY = timedelta(days=7)


def initialize_auth_indexes(database=None) -> None:
    """Call once at startup. Existing user records must be checked before unique indexes."""
    if database is None:
        from backend.app.database import db
        database = db
    database['users'].create_index('mobile', unique=True, name='users_unique_mobile')
    database['users'].create_index('user_id', unique=True, name='users_unique_id')
    database['auth_sessions'].create_index('token_hash', unique=True)
    database['auth_sessions'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_otp_challenges'].create_index(
        [('purpose', ASCENDING), ('mobile', ASCENDING), ('subject', ASCENDING)],
        unique=True, name='otp_unique_purpose_mobile_subject',
    )
    database['auth_otp_challenges'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_reset_grants'].create_index('token_hash', unique=True)
    database['auth_reset_grants'].create_index('expires_at', expireAfterSeconds=0)
    database['auth_collector_invitations'].create_index('token_hash', unique=True)
    database['auth_collector_invitations'].create_index('expires_at', expireAfterSeconds=0)


def _public_user(user: dict) -> UserResponse:
    return UserResponse(
        user_id=user['user_id'], mobile=user['mobile'], role=user['role'],
        status=user['status'], phone_verified=bool(user.get('phone_verified')),
        full_name=user.get('full_name'),
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


def _issue_otp(database, mobile: str, purpose: str, *, subject: str = ''):
    """Persist a digest, deliver, and roll back the challenge on provider failure."""
    sms.require_sms_provider()
    now = now_utc()
    old = database['auth_otp_challenges'].find_one({
        'mobile': mobile, 'purpose': purpose, 'subject': subject,
    })
    if old and aware_utc(old['created_at']) > now - OTP_COOLDOWN:
        raise HTTPException(status_code=429, detail='Please wait before requesting another code')
    code = f'{secrets.randbelow(1_000_000):06d}'
    digest = otp_digest(purpose, mobile, code, subject)
    challenge_id = str(uuid4())
    challenge = {
        'challenge_id': challenge_id, 'mobile': mobile,
        'purpose': purpose, 'subject': subject,
        'code_hash': digest, 'attempts': 0,
        'created_at': now, 'expires_at': now + OTP_EXPIRY,
    }
    database['auth_otp_challenges'].replace_one(
        {'mobile': mobile, 'purpose': purpose, 'subject': subject},
        challenge, upsert=True,
    )
    try:
        sms.send_verification_code(mobile, code, purpose)
    except Exception:
        database['auth_otp_challenges'].delete_one({'challenge_id': challenge_id})
        raise HTTPException(status_code=503, detail='Could not deliver verification SMS') from None


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
    token = random_secret()
    now = now_utc()
    database['auth_sessions'].insert_one({
        'session_id': str(uuid4()), 'user_id': user['user_id'],
        'token_hash': token_digest(token), 'created_at': now,
        'expires_at': now + SESSION_EXPIRY, 'revoked': False,
    })
    return LoginResponse(access_token=token, user=_public_user(user))


@router.post('/register/household', status_code=202)
def register_household(payload: HouseholdRegistration, database=Depends(get_auth_db)):
    sms.require_sms_provider()  # Fail before creating an unusable account.
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
    return {'message': 'Verification code sent', 'status': 'pending_phone'}


@router.post('/trader/apply', status_code=202)
def apply_trader(payload: TraderApplication, database=Depends(get_auth_db)):
    sms.require_sms_provider()
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
    return {'message': 'Verification code sent', 'status': 'pending_phone'}


@router.post('/otp/resend', status_code=202)
def resend_otp(payload: ResendOtp, database=Depends(get_auth_db)):
    user = database['users'].find_one({'mobile': payload.mobile, 'status': 'pending_phone'})
    if user:
        _issue_otp(database, payload.mobile, 'registration')
    return {'message': 'If eligible, a verification code will be sent'}


@router.post('/otp/verify')
def verify_otp(payload: VerifyOtp, database=Depends(get_auth_db)):
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
    user = database['users'].find_one({'mobile': payload.mobile, 'phone_verified': True})
    if not user:
        raise HTTPException(status_code=400, detail='Invalid verification request')
    _consume_otp(database, payload.mobile, 'password_reset', payload.code)
    token = random_secret()
    now = now_utc()
    database['auth_reset_grants'].insert_one({
        'user_id': user['user_id'], 'token_hash': token_digest(token),
        'created_at': now, 'expires_at': now + RESET_EXPIRY,
    })
    return {'reset_token': token, 'expires_in': 600}


@router.post('/login', response_model=LoginResponse)
def login(payload: LoginRequest, database=Depends(get_auth_db)):
    user = database['users'].find_one({'mobile': payload.mobile})
    # Hash check even for missing numbers to reduce account-existence timing leaks.
    if not verify_password(payload.password, user.get('password_hash') if user else None):
        raise HTTPException(status_code=401, detail='Invalid mobile number or password')
    if not user or user['status'] != 'active' or not user.get('phone_verified'):
        raise HTTPException(status_code=403, detail='Account not active or awaiting verification/approval')
    return _make_session(database, user)


@router.get('/me', response_model=UserResponse)
def me(user=Depends(current_user)):
    return _public_user(user)


@router.post('/logout')
def logout(user=Depends(current_user), credentials=Depends(bearer), database=Depends(get_auth_db)):
    database['auth_sessions'].update_one({
        'token_hash': token_digest(credentials.credentials), 'user_id': user['user_id'],
    }, {'$set': {'revoked': True}})
    return {'message': 'Signed out'}


@router.post('/password/forgot', status_code=202)
def forgot_password(payload: MobileRequest, database=Depends(get_auth_db)):
    sms.require_sms_provider()
    user = database['users'].find_one({'mobile': payload.mobile, 'phone_verified': True})
    if user:
        _issue_otp(database, payload.mobile, 'password_reset')
    return {'message': 'If the account exists, recovery instructions will be sent'}


@router.post('/password/reset')
def reset_password(payload: PasswordReset, database=Depends(get_auth_db)):
    grant = database['auth_reset_grants'].find_one_and_delete({
        'token_hash': token_digest(payload.reset_token),
        'expires_at': {'$gt': now_utc()},
    })
    if not grant:
        raise HTTPException(status_code=400, detail='Invalid or expired reset token')
    database['users'].update_one({'user_id': grant['user_id']}, {
        '$set': {'password_hash': hash_password(payload.new_password), 'updated_at': now_utc()},
    })
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
def collector_activation_otp(payload: InvitationOtpRequest, database=Depends(get_auth_db)):
    _validate_invitation(database, payload.mobile, payload.invitation_token)
    if database['users'].find_one({'mobile': payload.mobile}):
        raise HTTPException(status_code=409, detail='Mobile number already registered')
    _issue_otp(database, payload.mobile, 'collector_activate',
               subject=token_digest(payload.invitation_token))
    return {'message': 'Verification code sent'}


@router.post('/collector/activate', status_code=201)
def activate_collector(payload: CollectorActivation, database=Depends(get_auth_db)):
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
def request_mobile_change(payload: ChangeMobileRequest, database=Depends(get_auth_db),
                          user=Depends(current_user)):
    if database['users'].find_one({'mobile': payload.new_mobile}):
        raise HTTPException(status_code=409, detail='Mobile number already registered')
    _issue_otp(database, payload.new_mobile, 'mobile_change', subject=user['user_id'])
    return {'message': 'Verification code sent to new mobile number'}


@router.post('/mobile/change/confirm')
def confirm_mobile_change(payload: ChangeMobileConfirm, database=Depends(get_auth_db),
                          user=Depends(current_user)):
    _consume_otp(database, payload.new_mobile, 'mobile_change', payload.code, subject=user['user_id'])
    try:
        result = database['users'].update_one({'user_id': user['user_id'], 'status': 'active'}, {
            '$set': {'mobile': payload.new_mobile, 'updated_at': now_utc()},
        })
    except DuplicateKeyError as exc:
        raise HTTPException(status_code=409, detail='Mobile number already registered') from exc
    if not result.matched_count:
        raise HTTPException(status_code=409, detail='Account status changed')
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
