# Platform Activity Monitoring

## Activation

1. Apply `supabase/migrations/0013_activity_monitoring.sql` after migration 0012 in the same Supabase project used by the backend. It is transactional and must be run once in full.
2. Rebuild the backend with `npm.cmd run build` from `backend`, then restart it. Keep existing Supabase credentials server-side. No new browser keys are required.
3. Build/deploy the admin app with `npm.cmd run build` from `admin`, or open the existing Vite server at http://localhost:5173.
4. Sign in as Super Admin and open Platform Activity. A connected stream shows Live. Disconnected is an actual connection failure, not a simulated success.
5. Perform an authorized action in another window. Confirm the event, summaries and associated record refresh. Test denied access from an ordinary account and verify a rejected event appears.

Do not run the updated API against the old schema. Hosted activation and actual Supabase Realtime delivery must be checked after applying 0013. Local database and browser tests do not establish hosted provider connectivity.

## Sources and Coverage

| Source | Recorded changes |
| --- | --- |
| Orders and order events | Creation, lifecycle commands, assignments, status transitions, actor and order IDs |
| Evidence, returns, offers, locations | Evidence metadata, returns, offers, sampled tracking changes |
| Payments, wallets, escrow, platform ledger, payouts | Persisted provider/state references, amounts in integer minor units, funding/release/refund/withdrawal transitions |
| Profiles, security settings, roles, blocks | Registration, login, profile updates, suspension/deactivation, roles and blocks |
| Deliverer profiles and verification | Availability, area/profile changes, application decisions and document metadata |
| Messages and notifications | Sent/read/delivered chat state, notification creation/read/removal |
| Support, disputes and settlements | Ticket state, disputes, settlements |
| Audit logs | Administrative actions; original audit retains prior/new state |
| HTTP observation | Successful mutations, failures and rejected access, verified request actor, status/error code and server-generated request ID |

Database events commit or roll back with the business operation. HTTP outcomes describe the API request, not settlement: an initialized payment is not a verified payment. Provider success continues to require the existing verified webhook/payment flow. Several representations may describe one operation (HTTP, state change, ledger and audit); these are separate observations, not additional financial transactions.

Notification provider delivery/failure callbacks and provider payout callbacks are not manufactured. They appear only when an implemented integration persists that outcome. This change monitors existing modules; it does not implement missing provider workers. Authentication outside the Node API is not observed by the HTTP middleware. Direct auth-provider login/logout history requires a provider event integration; backend login has an explicit account event.

## Privacy and Authorization

All monitoring REST endpoints and the SSE stream require a currently enabled `super_admin` account. Ordinary administrative roles cannot read the platform feed. Tables remain RLS-enabled and are not granted to the browser. The Node service-role client bridges Supabase Realtime to authenticated SSE **invalidation hints only**; event details are fetched through current backend authorization.

Stream identity, suspension and role are checked every 20 seconds; a revoked session is disconnected. Each process allows three concurrent streams per account. Production proxy buffering must be disabled for `/api/v1/admin/platform/stream`; idle timeout must exceed the 20-second heartbeat. Browser disconnect, hidden tab and component disposal remove subscriptions. Reconnects use bounded backoff and refresh records to recover missed hints.

Events never copy request bodies, tokens, passwords, webhook payloads, full bank credentials, message contents, private storage paths or GPS coordinates. Associated-record previews use an explicit server-side column allowlist. Message read actors are not inferred from the message author. Unknown/system actors stay unknown; old events are marked legacy and do not acquire fabricated actor identities. Location events are sampled to one per order per minute, not a route-history substitute.

Activity UPDATE, DELETE and TRUNCATE are rejected by immutable-record triggers. Financial and original audit immutability remains unchanged. Account deactivation retains history. If the database is unavailable, HTTP observation writes a sanitized structured operational log instead; retain/export production logs for incident recovery. HTTP logging is best effort after the response and is not a durable delivery queue. Transactional critical-operation records are the reliable source of truth.

## API and Analytics

- `GET /api/v1/admin/platform/activity`: page (25 rows), type, category, outcome, userId (actor or account), orderId, reference (exact), status, from/to (ISO UTC), q.
- `GET /api/v1/admin/platform/activity/:id/record`: privacy-limited related record or metadata-only result.
- `GET /api/v1/admin/platform/metrics`: order/payment/dispute/payout totals and fourteen UTC daily data points.
- `GET /api/v1/admin/platform/stream`: authenticated SSE ready/invalidate/heartbeat/unavailable/unauthorized signals.
- Existing `/analytics` and `/audit` endpoints retain user counts and administrative audit details.

Revenue uses the platform ledger, not gross payments. Failed-payment counts are not all rejected HTTP operations. User activity means distinct recorded actors/accounts, not concurrent online sessions. Money is returned as integer minor units; chart revenue strings are parsed with BigInt. Pagination is bounded offset pagination; historical cursors and retained-log archival are future scaling considerations.

## Verification

Backend tests exercise migrations on embedded PostgreSQL, financial/delivery lifecycle regressions, event privacy, transactional rollback, append-only protections, filters, RBAC, rejected-operation logging and stream cleanup. Playwright uses explicit test-only REST/SSE fixtures to cover console workflows, filters, charts and responsive layout on desktop and mobile. These fixtures are never used by the production application.
