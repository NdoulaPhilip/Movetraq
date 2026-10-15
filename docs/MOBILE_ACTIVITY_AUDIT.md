# Mobile Activity Investigation

## Confirmed Cause (2026-10-15)

Android uses `NodeApiClient` and `https://movetraq-api.onrender.com`, backed by
the existing Render PostgreSQL store. The React admin uses the separate
`backend/` Supabase API. Supabase activity triggers cannot see writes in the
mobile database. The two systems use incompatible identities and financial
schemas; treating legacy IDs as Supabase UUIDs or copying balances is unsafe.

A read-only investigation found two mobile users, six orders and one Paystack
top-up. The top-up for 550000 kobo (NGN 5,500), reference ending `eee6e29e38`,
was already verified in PostgreSQL. Paystack independently returned `success`,
the same amount and NGN currency. Its absence from admin was a data-source
integration defect, not evidence of a missing wallet credit. No charge or
wallet adjustment was performed in this investigation.

## Implementation

- Additive legacy migration `server/migrations/0002_mobile_monitoring.sql`
  projects actual records, appends domain events inside the same write
  transaction and backfills existing records. Reapplying the migration does
  not duplicate unchanged observations.
- Existing records are labelled `recorded`, with observation time separate
  from original creation/verification timestamps. Historic logins or failed
  requests that were never stored cannot be reconstructed.
- Request attempts are persisted before running operations and completed with
  status afterwards. Interrupted/crashed requests remain `pending`, not
  falsely successful. Database outages fail closed before executing monitored
  requests. A completion-write failure leaves a traceable pending attempt.
- Payment provider failure/abandonment and verification errors are retained on
  top-up records. Only independently verified success credits the ledger.
- A bounded background sweep checks initialized, unverified payments older
  than five minutes from the preceding seven days. Each check is audited.
  Provider outages remain errors rather than guessed payment outcomes.
- A server-to-server adapter connects the admin API to the authoritative
  mobile database through a fixed HTTPS endpoint and a random private service
  credential. The browser never receives that credential or database keys.
- The backend requires a valid, enabled Supabase session and `super_admin`
  role for every monitoring read. Mobile access is audited with the staff ID.
- Admin activity, users, orders and support include explicit mobile/Supabase
  source selection. Payments & Wallet provides payment references, statuses,
  wallet ledger and request failures. Mobile views refresh every ten seconds
  while visible; existing Supabase activity uses its realtime stream.
- Unavailable or unconfigured sources display errors, not empty successful
  responses. Pending operations expose incomplete processing.

## Coverage And Limits

Legacy PostgreSQL monitoring covers current user/deliverer metadata, orders,
escrow flags, tracking updates, wallet ledger, top-ups, payment checks,
notification states, message metadata, support, saved-address operations and
account settings. Request attempts also capture unavailable routes and rejected
operations. Sensitive request bodies, passwords, PINs, card credentials,
message bodies and exact GPS coordinates are not copied to activity feeds.

The separate Supabase activity system continues monitoring its applications,
verification decisions, payouts, returns, disputes and administrative actions.
Those workflows are not all implemented by the legacy mobile API. A client-only
action that never contacts either backend cannot be reconstructed as a server
event; unsupported operations must not be presented as completed workflows.
This integration does not invent missing historic events or enable refunds,
withdrawals or other unfinished financial capabilities.

## Deployment

Set the same strong random `MONITORING_SERVICE_TOKEN` on **both APIs only**.
On the Supabase API set `MOBILE_MONITORING_URL` to the approved mobile API URL.
Deploy the mobile API first, the Supabase API second, then the React admin.
No Supabase migration, identity reassignment or balance copy is required.
Verify both health endpoints, protected endpoints, actual payment/ledger rows,
and the deployed admin bundle. Keep all secrets outside Git and static assets.
