# API

Base path: `/v1`. Authenticated requests use `Authorization: Bearer <Supabase access token>`. Successful responses use `{success:true,data:...}`; errors use `{success:false,error:{code,message}}`. No production stack traces are returned.

Admin list endpoints return `data:{items,next_cursor}` and accept `search`, `status` (where applicable), `limit` (1–100), and an opaque `cursor`. Cursors include their resource identity and use timestamp-plus-ID ordering, so records with equal timestamps do not disappear between pages.

`GET /health` checks process health; `/ready` checks database readiness. Core resources: `/users/me`, `/addresses`, `/orders`, `/wallet`, `/payments`, `/deliverer`, `/conversations`, `/notifications`, `/support/tickets`, `/uploads`, and `/admin`. Exact methods, request schemas, and role requirements are defined in `backend/src/routes` and `backend/src/validators`.

Order pricing originates from server quotes; create requests reference a quote rather than submitting trusted totals. Financial and lifecycle mutation endpoints require idempotency keys where specified. Clients cannot declare payments paid, change ledger entries, or select arbitrary order states.

`GET /v1/orders/lookup?reference=MT-...` resolves a tracking reference for the authenticated sender or assigned deliverer. References are normalized to uppercase. Missing and inaccessible orders return the same `ORDER_NOT_FOUND` response; knowing a reference does not grant access. Receive uses this endpoint without a recent-order limit.

Paystack's webhook endpoint consumes raw bytes and verifies HMAC before processing. Clients returning from checkout request server verification; browser redirects alone do not fund orders.

Payment initialization also returns server-selected `callback_url` and `cancel_url` for the mobile checkout. `/v1/payments/return` and `/v1/payments/cancel` are public informational landing pages; neither changes financial state. The app intercepts their exact origins/paths and verifies the original reference through its authenticated API session. Hosted checkout receives no Supabase token or payment secret. Card/bank HTTPS authentication redirects remain inside the checkout screen.

`POST /v1/wallet/reconcile` accepts an empty object and recovers up to five recent unresolved top-ups belonging to the authenticated user. References and amounts are selected from database records, never client assertions. Each payment is independently checked with Paystack and credited through the existing immutable, idempotent journal flow. The response contains `payments:[{reference,status,error_code?}]`; `unverified` means provider verification failed and no credit was granted. This endpoint is limited to ten requests per user per minute. The mobile wallet calls it on entry, foreground resume, and explicit refresh so app termination does not lose the payment reference. Provider webhooks remain the preferred background confirmation path.

Uploads initialize an authorized private object, upload using the signed token, then finalize server validation. Download URLs expire quickly. Calls return an explicit unavailable error until a genuine calling integration is configured.

This document is an overview; a generated exhaustive OpenAPI contract remains a release task.

Admin management additions are documented in [Admin management](docs/admin-management.md). New list resources are `/admin/payments`, `/admin/ledger`, `/admin/ads`, `/admin/events`, `/admin/deletions`, and `/admin/staff`. Detail endpoints include `/admin/users/:id`, `/admin/deliverers/:id`, `/admin/ledger/:id`, `/admin/payouts/:id` and `/admin/operations/health`.

`POST /admin/orders/:id/operations` accepts `{action:cancel_unpaid|requeue,reason,confirmation:CONFIRM}` with an `idempotency-key`. `POST /admin/payouts/:id/reject` accepts `{reason,confirmation:CONFIRM}` with the same key requirement. `PATCH /admin/users/:id/staff-roles` requires super admin and `{roles,reason,confirmation:CONFIRM}`. `POST /admin/deliverers/:id/offline`, `/admin/events/:id/retry`, `/admin/operations/dispatch`, and finance-only `/admin/payments/:id/verify` accept `{reason}`. `PATCH /admin/ads/:id` accepts `{status:paused|deleted,reason}`. Reasons require 10–3000 trimmed characters. List permissions and mutation guards are independent; financial read access does not permit writes.
# Support conversations

`GET /v1/support/tickets/:id` returns `{ticket, notes, attachments}`. Only the reporter or trusted support/admin staff can access this endpoint. Reporters receive public replies; staff also receive internal notes. History is limited to the latest 100 notes. Attachment metadata contains upload IDs, MIME types, sizes and timestamps, without private storage paths.

`POST /v1/support/tickets/:id/replies` accepts `{client_note_id, body, internal?}`. The UUID must remain stable across retries; a changed payload with the same UUID returns `NOTE_CONFLICT`. Internal notes require support/admin privileges. Resolved and closed cases reject new replies; previously acknowledged retries still return the original note. Staff actions are audited and public staff replies enqueue a support notification.

`POST /v1/support/tickets/:id/attachments` accepts `{upload_id}`. Only the reporter may link a finalized, owned `support-attachments` upload with the same order association as the case. Up to five files can be linked per case; an upload cannot be shared between cases. Retries return the existing link, including after closure. New links to resolved/closed cases are rejected. Downloads use `/v1/uploads/:id/download`; linked files are available to support/admin staff and the uploader, never automatically to other order participants. The mobile UI currently selects photos; the upload API also accepts PDF documents.

`GET /v1/admin/support-staff` lists active authorized support staff with search and cursor pagination. `PATCH /v1/admin/disputes/:id` accepts an optional `assigned_admin_id`: omit it to preserve assignment, send a UUID to assign active support/admin staff, or `null` to unassign. Status, priority and assignment changes are audited and notify the reporter. Changing priority to `urgent` escalates the case's priority; it does not imply an external alert was delivered.

