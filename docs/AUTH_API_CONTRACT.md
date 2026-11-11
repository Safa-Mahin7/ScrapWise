# ScrapWise Phase 2B — Authentication API Contract

Implementation based on `Safa-Mahin7/ScrapWise` `feature/frontend` commit `7ac6502` and existing `backend/app/database.py`. **All endpoints below are proposed additions**, not existing teammate endpoints.

## Rules

- One mobile number, one account, one primary role (`household`, `collector`, `trader`, `admin`).
- One universal mobile/password login. Role is **always assigned by the server**, not supplied at login.
- Household may register publicly. Trader may submit an application but needs manual business approval. Collector needs an invitation from an active trader. Admin is provisioned internally, never through a public API.
- Passwords are Argon2-hashed; one-time codes are HMAC-hashed using `AUTH_OTP_SECRET`. Database stores SHA-256 hashes of high-entropy bearer session tokens, never the plaintext session token. Bearer tokens expire after one hour and are revocable by logout and account changes.
- SMS verification is intentionally **disabled by default**: the `backend/app/auth/sms.py` adapter must be replaced with a real SMS delivery provider, tested, and enabled before public registration, reset, phone change or collector activation is functional. No SMS code is returned or printed.
- Current team pickup and transaction routes are **NOT protected yet**. They still accept client-supplied `household_id` / `recorded_by_user_id`, so do not deploy publicly until the team lead coordinates server-side identity checks. This package does not modify those routes.

## Endpoints

| Method | Path | Access | Behavior |
| --- | --- | --- | --- |
| POST | `/api/auth/register/household` | Public | Create pending household, deliver registration OTP |
| POST | `/api/auth/trader/apply` | Public | Create pending trader application, deliver registration OTP |
| POST | `/api/auth/otp/resend` | Public | Resend pending registration OTP (60s per-number cooldown) |
| POST | `/api/auth/otp/verify` | Public | Validate code; activate household or mark trader `pending_approval`; for password reset issue one-use reset grant |
| POST | `/api/auth/login` | Public | Mobile + password, only active/verified users; returns opaque bearer session token and user role |
| GET | `/api/auth/me` | Bearer | Current account profile/role |
| POST | `/api/auth/logout` | Bearer | Revoke current bearer session |
| POST | `/api/auth/password/forgot` | Public | Generic response, initiate recovery OTP |
| POST | `/api/auth/password/reset` | Public + one-time reset grant | Replace password, revoke all sessions |
| POST | `/api/auth/collector/invitations` | Active trader | Create one-time invitation link token, returned once to inviter for trusted delivery |
| POST | `/api/auth/collector/activate/request-otp` | Valid invitation token | Send invitation-bound OTP |
| POST | `/api/auth/collector/activate` | Valid invitation + OTP | Set password, create verified collector account |
| POST | `/api/auth/mobile/change/request` | Bearer | OTP to new unregistered phone |
| POST | `/api/auth/mobile/change/confirm` | Bearer + OTP | Update verified phone, revoke sessions |
| POST | `/api/auth/admin/traders/{user_id}/approve` | Active admin | Approve phone-verified trader **after out-of-band business verification** |
| POST | `/api/auth/admin/traders/{user_id}/reject` | Active admin | Reject pending trader |

### Sample requests

`POST /api/auth/register/household`
```json
{"full_name":"Demo Household","mobile":"9876543210","locality_id":"cowl_bazar","password":"replace-with-strong-password"}
```
Local Indian 10-digit numbers are normalized to `+91...`; other countries must use E.164.

`POST /api/auth/otp/verify`
```json
{"mobile":"+919876543210","purpose":"registration","code":"123456"}
```
This is a **format example**, not a real OTP; no provider is configured by this patch.

`POST /api/auth/login`
```json
{"mobile":"+919876543210","password":"replace-with-strong-password"}
```

The response includes `access_token`, `token_type: bearer`, `expires_in: 3600`, `user: {user_id, mobile, role, status, phone_verified, full_name}`. Subsequent calls: `Authorization: Bearer <access_token>`.


## Setup and testing (current `feature/frontend` branch)

The authentication router is already integrated into `backend/app/main.py`.
Authentication indexes are initialized through the FastAPI lifespan function.

Do not run `scripts/apply_auth_router.py`. It is an outdated setup helper.

1. Install the project's Python dependencies from `requirements.txt`.
2. Configure the project-root `.env` with the required MongoDB connection settings and a unique, high-entropy `AUTH_OTP_SECRET` of at least 32 characters. Never commit `.env`.
3. Run authentication tests:

   `python -m pytest backend/tests/test_auth_offline.py -q`

4. Run the existing standalone pickup and transaction regression scripts:

   `python -m backend.tests.test_pickup_offline`

   `python -m backend.tests.test_transaction_offline`

5. Run Flutter checks:

   `flutter analyze`

   `flutter test`

6. For normal backend operation, start FastAPI:

   `python -m uvicorn backend.app.main:app --host 127.0.0.1 --port 8000`

7. Check `/health` and `/docs` to verify database connectivity and API registration.
8. A real HTTPS SMS provider must be configured before normal SMS-dependent authentication can work. The development-only mock SMS server is not part of this committed implementation.
9. Coordinate authorization changes to the existing pickup and transaction endpoints with the backend team before public deployment.

This is a development-stage authentication integration, not a production deployment approval.


## Important follow-up security work

- Add IP/device/account-based rate limiting to login, OTP and invitation endpoints (60-second OTP cooldown and five verification attempts alone are not sufficient).
- Add audit logs, out-of-band business-document verification, anti-abuse monitoring, session renewal/refresh, CSRF controls if switching to web cookies, secure Android token storage and browser session strategy.
- Ensure SMS provider reliability, retry semantics and duplicate-request handling. For a highly concurrent deployment, use atomic challenge issue operations and a DB transaction/outbox where appropriate.
- Confirm the existing `users` collection has no conflicting indexes or incompatible old account records before adding unique mobile/user_id indexes.
- Do not run unsecured existing pickup/transaction endpoints on a public server merely because `/api/auth` now exists.
- Admin provisioning: create an active, verified admin through trusted offline operations only, with audited manual identity verification; do not use a publicly exposed endpoint or insert plaintext passwords.

### Optional HTTPS SMS gateway

Set all these variables in the existing repo-root `.env` once you have an operator-controlled delivery adapter:

```dotenv
AUTH_SMS_PROVIDER=http
AUTH_SMS_HTTP_URL=https://your-private-sms-gateway.example/api/send-otp
AUTH_SMS_HTTP_TOKEN=<gateway-secret-not-in-source-control>
```

The gateway must accept `POST` with a bearer token and JSON `{"mobile":"+919876543210","code":"<six-digit-code>","purpose":"registration"}`, return 2xx only after accepting delivery, and actually dispatch the SMS. This URL is **illustrative, not an existing provider**. Default configuration sends nothing and returns HTTP 503 for SMS-dependent operations. Protect the gateway against abuse and ensure Indian telecom compliance where applicable.
