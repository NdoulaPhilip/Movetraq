# Production Implementation Status

The existing Flutter visual design is retained. This document describes actual
implementation status, not a claim that MoveTraq is ready for public release.
The original design README was reviewed in full. The latest supplied production
specification supersedes its free P2P posting/payment timing: funding is now held
before discoverable jobs and sender-confirmed assignment. Evidence before
completion, sender confirmation before P2P release, returns without earnings,
and persistent conversation history are retained.

## Implemented In This Increment

- Request-scoped Supabase Auth clients: signup, email OTP verification, signin,
  refresh rotation, recovery initiation, authenticated password changes, logout.
- Provisioning trigger and backfill for profiles, sender roles, preferences,
  security settings and wallets. User metadata cannot grant deliverer/admin roles.
- Backend account/profile, saved-address, preference, notification and blocking
  APIs with strict validation and account-scoped queries.
- Account-scoped notification unread counts, mark-all-read, delete and clear-all
  operations with a partial unread index and API/database isolation checks.
- Transactional default-address updates, serializing changes per account.
- Read-only wallet balances and paginated ledger history in integer minor units.
- Paystack hosted top-up checkout, deterministic references per account/request,
  raw-body webhook signatures, server-side transaction verification, and atomic
  idempotent credit plus notification creation.
- RLS-safe wallet balance view, protected account columns, service-only RPCs,
  immutable ledger rows and wallet/user/currency foreign-key consistency.
- Async Express error propagation, auth rate limits, malformed-JSON errors,
  redacted credentials and consistent JSON 404 responses.
- Corrected compiled backend start path and added a separate Render blueprint.
- Separate source-only test discovery and production build configuration.
- Disabled unsafe identifier-only password replacement in the legacy server.
- Google Routes integration behind a maps interface, server-calculated quotes
  for all four services, expiring immutable quote snapshots and configured tariffs.
  Shopping budgets are tracked separately and are not charged as delivery fees.
- Idempotent order creation and transactional semantic order commands. Database
  transitions guard assignment, pickup, handover, completion, cancellation and returns.
- Wallet-funded escrow holds, single-release deliverer earnings/platform fees,
  pre-pickup cancellation refunds and issue/dispute holds. No completion earnings
  are credited for a return. Scoped finance/admin dispute adjudication is now implemented.
- Matching eligibility checked on the backend: approved capability, availability,
  service preference, weight/job capacity, transport for moves, declared coverage
  and two-way blocks. Candidate distance is explicitly distance to the coverage
  center, not a claim of the deliverer's current GPS position.
- Sender-only random handover codes, expiry and persisted failed-attempt counters.
  Valid codes record handover evidence; P2P release still requires sender confirmation.
- Active-delivery GPS updates with recency/accuracy checks, throttling and ownership,
  latest-location-only storage, cleanup on handover/end and 15-minute retention.
- Persistent order conversations, idempotent text messages, unread/read receipts,
  backend in-app notifications and conditional Supabase Realtime publication setup.
- Private verified document uploads, short-lived signed reads, configurable required
  documents, reviewed deliverer approval and suspension with append-only audit logs.
- Saved-address selection, real deliverer summaries/past customers and order receipts.
- Separate authenticated React admin console with scoped verification and finance
  access, private document review and audited tariff version activation. Credentials
  stay in memory, not browser storage. No placeholder metrics or seeded prices.
- Protected historical tariff snapshots, platform-ledger/audit truncation guards,
  no-store API responses and graceful backend shutdown.
- Optional private JPG/PNG/WebP handover photos, capped at 1.5 MB with metadata
  and file-signature checks. Upload ownership, order association and verified
  upload IDs are checked transactionally before attaching photos to a code-verified
  handover. Photos alone do not bypass recipient-code verification.
- Idempotent categorized support cases, staff case status/priority/internal notes,
  independent return approval and immutable financial dispute settlements.
  Support/operations staff cannot settle money. Finance/admin can release only
  verified non-returned deliveries or refund eligible held/disputed funds once.
- Return workflow stored separately as return_requested, return_approved,
  returning and returned. Delivery commands require approval before return travel.
  Returned orders remain returned after refunds and receive no normal earnings.
- Completed-order participant ratings, exact-retry idempotency and rejection of
  duplicate conflicting ratings. Public rating aggregation is still pending.
- Admin support queue, private evidence reads, return approvals and scoped
  settlement controls with explicit financial confirmation. Customer API/RLS
  reads exclude staff notes/private paths.

## Backend API

The selective backend service merge adds authenticated address lookup and
transactional P2P ad management/discovery in forward migration 0014. See
[backend service merge](BACKEND_SERVICE_MERGE.md) for exact contracts,
configuration, tests and unimplemented archive behaviors. The mobile ad forms
are not yet connected to these structured production contracts.

Base path: `/api/v1`. Responses use `{ success: true, data }` or
`{ success: false, error: { code, message, details? } }`.
Authenticated routes require `Authorization: Bearer <Supabase access token>`.
The legacy server's custom tokens are not accepted.

| Method | Path | Behavior |
| --- | --- | --- |
| POST | /auth/signup | name, email, optional E.164 phone, password (12+ characters) |
| POST | /auth/signin | emailOrPhone, password |
| POST | /auth/verify | email, token, type (signup or recovery) |
| POST | /auth/refresh | refreshToken; returns rotated credentials |
| POST | /auth/recover | email; same response for known/unknown accounts |
| POST | /auth/password | authenticated password change |
| POST | /auth/logout | revoke this session's refresh token |
| GET/PATCH | /users/me | profile read or name/phone/granted activeRole update |
| GET/POST | /users/me/addresses | list or create |
| PUT/DELETE | /users/me/addresses/:id | replace or delete owned address |
| POST | /users/me/addresses/:id/default | atomically mark owned address default; migration 0011 required |
| GET/PATCH | /users/me/preferences | delivery/accessibility/display/privacy |
| GET/PATCH | /users/me/notification-preferences | notification settings |
| GET/POST | /users/me/blocked-users | list or block |
| DELETE | /users/me/blocked-users/:id | unblock |
| GET | /notifications | limit (1-100), offset |
| POST | /notifications/:id/read | owned notification only |
| GET | /notifications/unread-count | account-scoped unread count |
| POST | /notifications/read-all | mark owned unread items; preserve existing read timestamps |
| DELETE | /notifications/:id | delete owned notification; missing/unowned IDs return 404 |
| DELETE | /notifications | clear own inbox and return affected count |
| GET | /wallet | balanceMinor, currency, status |
| GET | /wallet/transactions | paginated immutable entries |
| POST | /payments/topups | amountMinor; Idempotency-Key header (16-128 characters) |
| POST | /payments/:reference/verify | reconcile an owned top-up |
| POST | /payments/webhooks/paystack | signed Paystack webhook |
| POST | /quotes | validated service input; backend route and price |
| GET | /quotes/:id/candidates | eligible candidates for an owned active quote |
| GET/POST | /orders | list owned/assigned orders or create from a quote; Idempotency-Key |
| GET | /orders/:id | participant-scoped detail |
| POST | /orders/:id/commands | validated semantic command, never arbitrary status |
| GET | /orders/:id/handover-code | sender-only handover secret |
| GET/POST | /orders/:id/location | participant tracking or assigned-worker GPS update |
| GET/POST | /orders/:id/messages | history or idempotent text message |
| POST | /orders/:id/messages/read | recipient read receipts |
| GET | /messages/unread-count | authenticated account unread count |
| GET | /orders/:id/receipt | participant-scoped payment receipt |
| POST | /users/me/addresses/:id/select | persist owned selected address |
| GET | /deliverers/me/jobs | backend-filtered eligible funded opportunities |
| PUT | /deliverers/me/availability | approved worker coverage/capacity/preferences |
| GET | /deliverers/me/summary | real wallet, earnings and delivery counts |
| GET | /deliverers/me/past-customers | completed-delivery customers |
| POST | /deliverers/me/applications | create/update draft onboarding |
| GET | /deliverers/me/applications/:id | owned application and document metadata |
| POST | /deliverers/me/applications/:id/documents | reserve signed private upload |
| POST | /verification-documents/:id/confirm | backend verifies storage metadata |
| POST | /deliverers/me/applications/:id/submit | require verified mandatory documents |
| GET | /verification-documents/:id/download | owner/reviewer short-lived signed URL |
| GET | /admin/verification-applications | scoped staff review queue |
| POST | /admin/verification-applications/:id/review | guarded decision plus audit |
| GET/POST | /admin/pricing-rules | scoped finance/admin tariff read or activation |
| GET/POST | /support/cases | own reported cases or open an order case; Idempotency-Key |
| GET | /admin/support/cases | scoped support/operations/finance review queue |
| POST | /admin/support/cases/:id/review | support case state/priority/internal notes |
| GET/POST | /orders/:id/returns | participant return approval state or request |
| POST | /admin/orders/:id/returns/approve | independent scoped staff approval |
| POST | /admin/orders/:id/dispute-settlement | finance/admin release or refund; Idempotency-Key |
| POST | /orders/:id/evidence/uploads | assigned deliverer signed private photo upload |
| POST | /evidence/uploads/:id/confirm | stored image metadata/content verification |
| GET | /orders/:id/evidence | participant/support evidence metadata |
| GET | /evidence/:id/download | authorized short-lived photo URL |
| POST | /orders/:id/ratings | rate the completed delivery counterpart |

Email signup stores a profile phone for contact purposes. Phone/password login
requires a separately verified Supabase phone identity; a profile phone alone
does not authenticate the account. Social login needs provider configuration
and mobile OAuth/deep-link handling. OTP emails need Supabase email templates
that include the verification code. Logout revokes refresh credentials; existing
access tokens remain valid until their JWT expiry. Disabled accounts are denied
by the Node API even while an access token remains valid.

Top-ups are NGN only, from 10,000 to 100,000,000 minor units. Checkout does not
credit money. Signed success events are verified again with Paystack and must
match the stored reference, amount and currency. Retries of the credit RPC
return the already verified payment without inserting another entry. No card
credentials are stored or handled by MoveTraq. Concurrent checkout initialization
uses one provider reference; a provider timeout or duplicate initialization may
require reconciliation or a new request key. Provider failures never credit a
wallet. Flutterwave, provider refunds and withdrawals are not implemented here.
Delivery funding currently uses a verified wallet balance. Direct provider order
checkout and bank-transfer-specific UX still need integration. Internal holds do
not establish a licensed escrow product or a separate safeguarded provider account.

## Setup And Verification

1. Apply Supabase migrations in numeric order to a test project first.
2. Configure email confirmation, SMTP, allowed auth redirects and OTP templates.
3. Populate `backend/.env` from `.env.example`; keep service-role and payment
   keys exclusively on the backend. Configure `TRUST_PROXY_HOPS` for the actual
   trusted proxy path (0 locally, 1 in the Render blueprint) so rate limits use
   client IPs. Require Node 22.12 or newer for the current test tooling.
4. Run `npm ci`, `npm run build`, `npm test`, `npm run smoke:build` in `backend/`.
5. `npm run test:db` executes migrations and the SQL checks in embedded
   PostgreSQL with Supabase auth/grant fixtures. It omits the currently unused
   PostGIS extension. Also run `supabase/tests/` against a disposable Supabase
   database to check the hosted environment. Scripts roll back test data.
6. Use `backend/render.yaml` to deploy the new API as a separate service, and
   configure Paystack's webhook URL and checkout callback URL.
7. Configure Google Routes and activate approved tariffs before quoting. There
   are no fabricated route results or default launch prices. Review the database
   verification requirements before enabling onboarding in the launch jurisdiction.
8. In `admin/`, run `npm ci`, `npm run build` and `npm test`. Browser tests use
   installed Edge and mocked API fixtures, not a hosted Supabase project. Configure
   `VITE_API_URL` and matching backend CORS origins, then run `npm run dev`.
   Staff roles must be granted through a trusted database administration process.

The root `render.yaml` and Flutter's default API URL still target the legacy
service. Do not switch the production mobile app to the new backend yet: the
Flutter order/chat/deliverer contracts have not been migrated. The new backend is a
separate deployable increment, not a drop-in replacement.

## Remaining Release Work

The saved-address production repository, separate verification states and
dedicated default-address endpoint are implemented. Migration 0011 is not yet
applied to the hosted project. See [core data increment](CORE_DATA_INCREMENT.md).

The separate mobile production auth repository, Dio transport and secure session
storage are implemented and regression-tested. Existing mobile auth screens are
not switched yet. See [mobile auth migration](MOBILE_AUTH_MIGRATION.md).

- Flutter migration to Riverpod/Bloc, GoRouter, Dio, secure session storage,
  confirmation/recovery flows and the new API contracts; Android/iOS verification.
- Flutter booking/checkout integration for all services, counterprice negotiation
  with re-funding, automatic dispatch/ranking and optional fresh GPS matching.
- Provider refunds/transfers, withdrawal reservations/reconciliation, partial
  dispute settlements, accounting reports and legal review of the held-funds model.
- Support/chat attachments and policy-approved recovery after exhausted handover
  attempts; shopping-budget funding/reimbursement is not implemented.
- Mobile Supabase Realtime subscriptions, offline message queues/attachments,
  GPS permission/foreground/background lifecycle, FCM device registration and a
  retryable push worker. Publication setup alone is not mobile realtime integration.
- Full deliverer analytics, payout details, mobile P2P advertisement integration, scheduled reminders,
  user moderation reports, public rating aggregation and membership.
- Admin operational metrics/charts, user suspension/reactivation, order search/
  controlled management, reporting, payout resolution and expanded configuration.
- Real calling-provider abstraction/configuration; no fake call-success behavior.
- Saved payment methods via provider tokens, membership, ratings, session
  management and account anonymization with financial retention rules.
- Integration/staging/device tests, backups, monitoring and operational runbooks.

The full supplied specification includes sections 1-72. Approved launch tariff
values, verification policy and the complete prototype-to-production acceptance
audit still need incorporation before a production release.
Hosted Supabase/Render deployment and real payment/storage/maps/device integration
have not been exercised with production credentials.

## References

- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [Supabase RLS and view security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase private signed uploads](https://supabase.com/docs/reference/javascript/file-buckets-createsigneduploadurl)
- [Supabase signed reads](https://supabase.com/docs/reference/javascript/file-buckets-createsignedurl)
- [Paystack webhook verification](https://paystack.com/docs/payments/webhooks/)
- [Paystack transaction initialization and verification](https://paystack.com/docs/api/transaction/)
