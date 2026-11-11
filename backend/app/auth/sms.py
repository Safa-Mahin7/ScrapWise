"""Pluggable HTTPS SMS delivery adapter; disabled by default.

Configure an operator-controlled SMS gateway that accepts POST JSON:
{'mobile': E164, 'code': 6 digit string, 'purpose': string}
with Authorization: Bearer <AUTH_SMS_HTTP_TOKEN>.

Do NOT log verification codes, include them in API responses, or use HTTP URLs.
The gateway must be configured separately to deliver actual SMS messages.
"""
import os
import httpx
from fastapi import HTTPException


def require_sms_provider() -> None:
    if (os.getenv('AUTH_SMS_PROVIDER') != 'http'
        or not os.getenv('AUTH_SMS_HTTP_URL', '').startswith('https://')
        or not os.getenv('AUTH_SMS_HTTP_TOKEN')):
        raise HTTPException(status_code=503, detail='SMS delivery provider is not configured')


def send_verification_code(mobile: str, code: str, purpose: str) -> None:
    require_sms_provider()
    try:
        response = httpx.post(
            os.environ['AUTH_SMS_HTTP_URL'],
            headers={'Authorization': 'Bearer ' + os.environ['AUTH_SMS_HTTP_TOKEN']},
            json={'mobile': mobile, 'code': code, 'purpose': purpose},
            timeout=8.0,
        )
        response.raise_for_status()
    except (httpx.HTTPError, OSError) as exc:
        raise HTTPException(status_code=503, detail='SMS delivery unavailable') from None
