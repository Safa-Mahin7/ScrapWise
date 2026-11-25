"""Server-side SMS delivery adapters; delivery is disabled by default.

Configure an operator-controlled SMS gateway that accepts POST JSON:
{'mobile': E164, 'code': 6 digit string, 'purpose': string}
with Authorization: Bearer <AUTH_SMS_HTTP_TOKEN>.

MSG91 uses its SMS Flow API with an operator-approved template. The locally
generated OTP is sent as the template's VAR1 value and verified by ScrapWise.
Do NOT log verification codes, include them in API responses, or use HTTP URLs.
"""
import os
import re

import httpx
from fastapi import HTTPException

MSG91_FLOW_URL = 'https://control.msg91.com/api/v5/flow'


def require_sms_provider() -> None:
    provider = os.getenv('AUTH_SMS_PROVIDER', '')
    if provider == 'http':
        if (not os.getenv('AUTH_SMS_HTTP_URL', '').startswith('https://')
                or not os.getenv('AUTH_SMS_HTTP_TOKEN')):
            raise HTTPException(
                status_code=503,
                detail='SMS delivery provider is not configured',
            )
        return
    if provider == 'msg91':
        if (not os.getenv('AUTH_SMS_MSG91_AUTH_KEY')
                or not os.getenv('AUTH_SMS_MSG91_TEMPLATE_ID')):
            raise HTTPException(
                status_code=503,
                detail='SMS delivery provider is not configured',
            )
        return
    raise HTTPException(
        status_code=503,
        detail='SMS delivery provider is not configured',
    )


def send_verification_code(mobile: str, code: str, purpose: str) -> None:
    require_sms_provider()
    if os.getenv('AUTH_SMS_PROVIDER') == 'msg91':
        _send_msg91_code(mobile, code)
        return

    try:
        response = httpx.post(
            os.environ['AUTH_SMS_HTTP_URL'],
            headers={'Authorization': 'Bearer ' + os.environ['AUTH_SMS_HTTP_TOKEN']},
            json={'mobile': mobile, 'code': code, 'purpose': purpose},
            timeout=8.0,
        )
        response.raise_for_status()
    except (httpx.HTTPError, OSError):
        raise HTTPException(status_code=503, detail='SMS delivery unavailable') from None


def _send_msg91_code(mobile: str, code: str) -> None:
    if re.fullmatch(r'\+91[6-9]\d{9}', mobile) is None:
        raise HTTPException(
            status_code=422,
            detail='MSG91 delivery supports valid Indian mobile numbers only',
        )

    try:
        response = httpx.post(
            MSG91_FLOW_URL,
            headers={
                'authkey': os.environ['AUTH_SMS_MSG91_AUTH_KEY'],
                'accept': 'application/json',
                'content-type': 'application/json',
            },
            json={
                'template_id': os.environ['AUTH_SMS_MSG91_TEMPLATE_ID'],
                'realTimeResponse': '1',
                'recipients': [
                    {'mobiles': mobile[1:], 'VAR1': code},
                ],
            },
            timeout=8.0,
        )
        response.raise_for_status()
        result = response.json()
    except (httpx.HTTPError, OSError, ValueError):
        raise HTTPException(
            status_code=503,
            detail='SMS delivery unavailable',
        ) from None

    if not isinstance(result, dict) or result.get('type') != 'success':
        raise HTTPException(
            status_code=503,
            detail='SMS delivery unavailable',
        )
