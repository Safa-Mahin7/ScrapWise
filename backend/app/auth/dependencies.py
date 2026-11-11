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
    session = database['auth_sessions'].find_one({
        'token_hash': token_digest(credentials.credentials),
        'expires_at': {'$gt': now_utc()},
        'revoked': False,
    })
    if session is None:
        raise HTTPException(status_code=401, detail='Invalid or expired session')
    user = database['users'].find_one({'user_id': session['user_id']})
    if not user or user.get('status') != 'active' or not user.get('phone_verified'):
        raise HTTPException(status_code=401, detail='Account or session inactive')
    return user


def require_roles(*roles: str) -> Callable:
    """Use with Depends(require_roles('trader', 'admin'))."""
    def check_role(user: dict = Depends(current_user)) -> dict:
        if user.get('role') not in roles:
            raise HTTPException(status_code=403, detail='Insufficient permissions')
        return user
    return check_role
