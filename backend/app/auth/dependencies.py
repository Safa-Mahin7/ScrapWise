"""Backend authorization, reusable by all ScrapWise routers."""
from collections.abc import Callable
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from backend.app.database import db
from .security import now_utc, token_digest

bearer = HTTPBearer(auto_error=False)


def get_auth_db():
    return db


def current_user(credentials: HTTPAuthorizationCredentials | None = Depends(bearer), database=Depends(get_auth_db)) -> dict:
    if credentials is None or credentials.scheme.lower() != 'bearer':
        raise HTTPException(status_code=401, detail='Authentication required', headers={'WWW-Authenticate': 'Bearer'})
    now = now_utc()
    session = database['auth_sessions'].find_one({
        'token_hash': token_digest(credentials.credentials),
        'expires_at': {'$gt': now},
        '$or': [
            {'access_expires_at': {'$gt': now}},
            {'access_expires_at': {'$exists': False}},
        ],
        'revoked': False,
    })
    user = database['users'].find_one({'user_id': session['user_id']}) if session else None
    if session is None or not session_account_is_active(session, user):
        raise HTTPException(
            status_code=401, detail='Invalid or expired session',
            headers={'WWW-Authenticate': 'Bearer'},
        )
    return user


def session_account_is_active(session: dict, user: dict | None) -> bool:
    return bool(
        user and user.get('status') == 'active' and user.get('phone_verified')
        and session.get('auth_version', 0) == user.get('auth_version', 0)
    )


def require_roles(*roles: str) -> Callable:
    """Use with Depends(require_roles('trader', 'admin'))."""
    def check_role(user: dict = Depends(current_user)) -> dict:
        if user.get('role') not in roles:
            raise HTTPException(status_code=403, detail='Insufficient permissions')
        return user
    return check_role


def has_permissions(user: dict, *permissions: str) -> bool:
    assigned = user.get('permissions')
    if not isinstance(assigned, (list, tuple, set)):
        return False
    return all(permission in assigned for permission in permissions)
