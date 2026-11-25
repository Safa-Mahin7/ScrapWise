# ScrapWise Phase 2C — Authentication API Contract

This contract describes authentication endpoints in ScrapWise's existing shared FastAPI and MongoDB application; it is not a separate backend.

## Rules

- One mobile number, one account, one primary role (`household`, `collector`, `trader`, `admin`).
- One universal mobile/password login. Role is **always assigned by the server**, not supplied at login.
- Household may register publicly. Trader may submit an application but needs manual business approval. Collector needs an invitation from an active trader. Admin is provisioned internally, never through a public API.
- Passwords are Argon2-hashed; one-time codes are HMAC-hashed using `AUTH_OTP_SECRET`. The database stores SHA-256 hashes of high-entropy access and refresh tokens, never their plaintext values. Access tokens expire after one hour; rotating refresh tokens have a 30-day absolute lifetime. Password reset and mobile changes invalidate all account sessions without changing the assigned role.
- SMS verification is **disabled by default**. Configure either the HTTPS gateway adapter or the MSG91 SMS Flow adapter before SMS-dependent operations. MSG91 sends the server-generated code using an approved template; ScrapWise verifies it locally. Provider acceptance is not proof of handset delivery, and no OTP is returned or logged.
- Current team pickup and transaction routes are **NOT protected yet**. They still accept client-supplied `household_id` / `recorded_by_user_id`, so do not deploy publicly until the team lead coordinates server-side identity checks. This package does not modify those routes.

## Pending Phase 1 RBAC integration

This worktree is based on commit `957ac39` and does not include the separate, uncommitted Phase 1 authorization changes in `feature/auth-hardening`. Before public deployment, the shared-backend owner must selectively port and validate server-derived identity, role, assignment, and cross-account ownership checks for protected business routes. The Phase 1 edits are mixed with pickup, transaction, assignment, and clustering changes; do not copy those files wholesale. No pickup, transaction, clustering, or forecasting implementation was changed for SMS.

## Endpoints

| Method | Path | Access | Behavior |
| --- | --- | --- | --- |
| POST | `/api/auth/register/household` | Public | Create pending household, request registration OTP delivery |
| POST | `/api/auth/trader/apply` | Public | Create pending trader application, deliver registration OTP |
| POST | `/api/auth/otp/resend` | Public | Resend pending registration OTP (60s per-number cooldown) |
| POST | `/api/auth/otp/verify` | Public | Validate code; activate household or mark trader `pending_approval`; for password reset issue one-use reset grant |
| POST | `/api/auth/login` | Public | Mobile + password, only active/verified users; returns opaque bearer session token and user role |
| POST | `/api/auth/google/register` | Public | Create a pending Household account from a verified Google subject; request mobile OTP |
| POST | `/api/auth/google/login` | Public | Verify Google ID token; sign in only an active account linked by Google `sub` |
| POST | `/api/auth/google/link` | Bearer + current password | Reauthenticate the active mobile account, then link one unique Google subject |
| GET | `/api/auth/me` | Bearer | Current account profile/role |
| POST | `/api/auth/refresh` | Refresh token | Atomically rotate access and refresh credentials; reuse of a rotated refresh credential revokes that session |
| POST | `/api/auth/logout` | Bearer and/or refresh token | Revoke current bearer session, including when its access token has expired |
| POST | `/api/auth/password/forgot` | Public | Generic response, initiate recovery OTP |
| POST | `/api/auth/password/reset` | Public + one-time reset grant | Replace an existing password, consume the grant, and revoke all sessions |
| POST | `/api/auth/collector/invitations` | Active trader | Create one-time invitation link token, returned once to inviter for trusted delivery |
| POST | `/api/auth/collector/activate/request-otp` | Valid invitation token | Request delivery of an invitation-bound OTP |
| POST | `/api/auth/collector/activate` | Valid invitation + OTP | Set password, create verified collector account |
| POST | `/api/auth/mobile/change/request` | Active bearer + password or fresh linked-Google ID token | Reauthenticate, reserve one pending change per account, and request OTP to a new unregistered phone |
| POST | `/api/auth/mobile/change/resend` | Active bearer | Resend the OTP for the account's active pending mobile change |
| POST | `/api/auth/mobile/change/confirm` | Active bearer + OTP | Atomically consume OTP, update the verified phone, and invalidate all account sessions |
| POST | `/api/auth/admin/traders/{user_id}/approve` | Active admin | Approve phone-verified trader **after out-of-band business verification** |
| POST | `/api/auth/admin/traders/{user_id}/reject` | Active admin | Reject pending trader |

### Sample requests

`POST /api/auth/register/household`
```json
{"full_name":"Demo Household","mobile":"9876543210","locality_id":"cowl_bazar","password":"replace-with-strong-password"}
```
Local Indian 10-digit numbers are normalized to `+91...`; other countries must use E.164. The MSG91 adapter is currently restricted to Indian `+91` numbers; the generic HTTPS adapter can be configured for other supported regions.

`POST /api/auth/otp/verify`
```json
{"mobile":"+919876543210","purpose":"registration","code":"123456"}
```
This is a **format example**, not a real OTP. OTP values are never returned by the API.

`POST /api/auth/login`
```json
{"mobile":"+919876543210","password":"replace-with-strong-password"}
```

The response includes `access_token`, `refresh_token`, `token_type: bearer`, `expires_in: 3600`, `refresh_expires_in: 2592000`, and `user: {user_id, mobile, role, status, phone_verified, full_name}`. Subsequent API calls use `Authorization: Bearer <access_token>`. Store both opaque tokens only in platform-appropriate secure storage; never log them.

`POST /api/auth/refresh` accepts `{"refresh_token":"<current-refresh-token>"}`. A successful response rotates both credentials and returns the same server-derived user identity and role. A refresh-token replay is rejected and revokes that login session. Each deliberate login creates its own device/session; logout revokes that session, while password reset and mobile change invalidate every session for the account. Refresh expiry is absolute (30 days from login), not extended by rotation.

Password recovery uses `/api/auth/password/forgot`, `/api/auth/otp/verify` with `purpose: "password_reset"`, and `/api/auth/password/reset`. The reset grant is opaque, stored hashed, expires in 10 minutes, is bound to the normalized mobile number, and is consumed once. Google-only accounts receive the same generic forgot-password response but are not sent an OTP and are not given a password.

Mobile changes require either `current_password` or a fresh Google ID token belonging to the account's linked `google_sub`. The OTP challenge and pending change are bound to that account and a unique attempt ID. One active pending change is allowed per account; successful confirmation invalidates all sessions. The primary role and linked Google subject remain unchanged.

The app's Flutter refresh-token flow uses Android `flutter_secure_storage`; older stored access-token-only sessions are cleared and must sign in once after the upgrade. On Web, the current API continues to use explicit bearer headers and the Flutter secure-storage Web implementation rather than HttpOnly cookies. Browsers do not attach bearer headers automatically, so classic CSRF is not the main exposure; JavaScript-accessible session material remains exposed to successful XSS. Production Web deployments need HTTPS, a restrictive CSP and security headers, tightly allowlisted origins, and an XSS review. If Web sessions move to cookies, use `Secure; HttpOnly; SameSite` cookies, credentialed CORS with exact origins, and a CSRF token/header check on state-changing requests.


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

- OTP sends are limited to 5 per mobile and 30 per client IP per fixed UTC hour; OTP verification attempts are limited to 10 per mobile and 100 per client IP per fixed UTC hour, in addition to the 60-second resend cooldown and five attempts per challenge. Login and invitation endpoints still need separate rate limits.
- Add audit logs, out-of-band business-document verification, anti-abuse monitoring, and login/invitation rate limits.
- Review production browser XSS protections and headers. Cookie-based Web sessions are not implemented; add CSRF defenses if switching from bearer headers to cookies.
- Validate the session-refresh TTL/index behavior against the deployment MongoDB before rollout. Existing access-only sessions require one interactive login after upgrade.
- OTP challenge issuance enforces the cooldown atomically. Use a DB transaction/outbox if deployment requirements call for durable provider delivery or retries.
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

### MSG91 SMS Flow provider

Set these server-side environment variables in the repo-root `.env`:

```dotenv
AUTH_SMS_PROVIDER=msg91
AUTH_SMS_MSG91_AUTH_KEY=<MSG91-auth-key>
AUTH_SMS_MSG91_TEMPLATE_ID=<approved-MSG91-template-id>
```

The adapter follows the [MSG91 Send SMS API](https://docs.msg91.com/sms/send-sms.openapi.yml) and calls `POST https://control.msg91.com/api/v5/flow` with the auth key in the `authkey` header, the E.164 Indian mobile number without `+`, `realTimeResponse: "1"`, and the locally generated OTP as `VAR1`. A response is accepted only when HTTP succeeds and MSG91 returns `type: "success"`; rejection, timeout, malformed response, or missing configuration returns HTTP 503. It sends only Indian `+91` mobile numbers.

In the MSG91 panel, [create an SMS template](https://msg91.com/help/template/how-to-create-flow-id-to-send-sms-via-api), register/map the Principal Entity (PE ID) and sender header, and create an India DLT-approved template whose first variable is the six-digit OTP (`VAR1`). Wait for MSG91/DLT approval, then mark the approved template version active/default. Copy that template's ID into `AUTH_SMS_MSG91_TEMPLATE_ID`. The approved text should say the OTP expires in five minutes and must not be shared. Provider account approval, DLT registration, message delivery, and pricing are operator responsibilities.

The existing backend enforces the five-minute expiry and one-time verification; MSG91 is used only to deliver the code. Mongo-backed rate counters are stored as hashed records in the existing TTL-indexed OTP-challenge collection, so no migration or new database index is required. `request.client.host` is used as the client IP; behind a reverse proxy, configure Uvicorn's trusted `--forwarded-allow-ips` values to the actual proxy addresses. Do not trust arbitrary client-supplied forwarding headers.

Offline tests mock the SMS provider and do not prove delivery. A real SMS check requires the variables above, an approved DLT template and a user-controlled Indian test number; confirm receipt on the handset and in MSG91 delivery logs before claiming delivery works.

### Google Sign-In (Android and Web)

The Flutter app uses the official `google_sign_in` plugin and its supported Google Identity Services web button. Configure OAuth clients in the same Google Cloud project:

- Create an Android OAuth client for the Android application ID (`com.example.scrapwise`) and add the SHA-1 fingerprints for each debug/release signing certificate.
- Create a Web application OAuth client. Add the deployed HTTPS origin to **Authorized JavaScript origins**. For local web testing, use a fixed port such as `7357` and authorize both `http://localhost` and `http://localhost:7357`; run with `flutter run -d chrome --web-hostname localhost --web-port 7357`.
- Complete the Google Auth Platform consent-screen branding and authorized-domain setup. The requested identity scopes are the standard sign-in scopes; no OAuth client secret is needed by Flutter or the backend.
- Supply the public Web client ID to Flutter at build/run time with `--dart-define=GOOGLE_WEB_CLIENT_ID=<web-client-id>`. On Android, the plugin uses that Web client as its `serverClientId` to request an ID token for the backend.
- Configure the backend environment variable `AUTH_GOOGLE_CLIENT_IDS` with the comma-separated allowed client IDs (the Web client and any Android client IDs accepted by the deployment). These values are public identifiers, not secrets. Never place client secrets or service-account credentials in Flutter.

The backend uses Google's `google-auth` library to verify the ID-token signature, audience, issuer and expiry before using `sub` as the identity key. No accounts are merged by email or mobile number. `/api/auth/google/register` creates only a `household` in `pending_phone`; successful existing OTP verification activates it. A mobile already owned by another account must first be authenticated with its existing method and linked through `/api/auth/google/link`. Linking requires a live ScrapWise bearer session plus the current password and is protected by a sparse unique `users.google_sub` index (`users_unique_google_sub`). Existing accounts without this field are unaffected; confirm the index builds successfully before deployment.

Google identity endpoints and Flutter tests in this phase are mocked/offline. A live Google test still requires the configured Cloud OAuth clients, authorized origins and signing fingerprints, then an actual Android and Web sign-in with a controlled account. These checks do not replace the pending Phase 1 business-route RBAC integration described above.
