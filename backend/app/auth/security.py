"""Authentication cryptography and time helpers (no JWT dependency)."""
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import os
import secrets

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from fastapi import HTTPException

_passwords = PasswordHasher()
_DUMMY_HASH = _passwords.hash('ScrapWise-no-such-user-2026!')


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def aware_utc(value: datetime) -> datetime:
    """PyMongo returns UTC dates without tzinfo unless tz_aware is enabled."""
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)


def hash_password(password: str) -> str:
    return _passwords.hash(password)


def verify_password(password: str, digest: str | None) -> bool:
    try:
        return _passwords.verify(digest or _DUMMY_HASH, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError, TypeError):
        return False


def random_secret() -> str:
    return secrets.token_urlsafe(32)


def token_digest(token: str) -> str:
    return hashlib.sha256(token.encode('utf-8')).hexdigest()


def otp_digest(purpose: str, mobile: str, code: str, subject: str = '') -> str:
    key = os.getenv('AUTH_OTP_SECRET', '')
    if len(key) < 32:
        raise HTTPException(status_code=503, detail='Authentication OTP secret is not configured')
    message = f'{purpose}|{mobile}|{subject}|{code}'.encode('utf-8')
    return hmac.new(key.encode('utf-8'), message, hashlib.sha256).hexdigest()


def compare_digest(a: str, b: str) -> bool:
    return hmac.compare_digest(a, b)


def ensure_password(password: str) -> str:
    if len(password) < 10 or len(password) > 128:
        raise HTTPException(status_code=422, detail='Password must be 10–128 characters')
    return password
