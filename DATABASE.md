# Database

Realtime status projections added on 8 October 2026: `deliverer_verification_updates` contains only user ID, verification status and update timestamp, with owner-only RLS. `order_realtime_updates` contains order ID, participants, order/payment status and update timestamp, with participant-only RLS. Database triggers maintain both projections transactionally. Publish these tables instead of source deliverers/orders: the hosted realtime gateway can return full source rows despite publication column filters. Authenticated direct reads of order handover hash/ciphertext are denied by column privileges. Migrations 14–16 define this behavior.

Ordered SQL migrations live in `supabase/migrations`. Apply through the backend migration runner or Supabase CLI, choosing one authoritative migration workflow per environment. The backend runner holds an advisory lock and atomically records each applied migration. Back up before applying production changes.

Schema groups include profiles/roles/preferences/security, addresses, orders/events/quotes/offers, deliverer applications/documents, accounts/journals/ledger, payments/escrow/payouts, messages/membership, notifications/devices, location history, evidence, returns, support/disputes, ratings, advertisements, audit records, and event outbox.

UUID identifiers, foreign keys, indexes, status constraints, RLS, scoped read policies, and denied direct client mutations protect records. Database service access is confined to the API/worker. Financial journals are immutable and must balance. Security-definer helpers pin their search path.

Sensitive buckets are private. Signed API uploads are bound to owned records and validated for size/type; image decoding rejects corrupt or oversized images. Never turn private buckets public to resolve access errors.

Realtime publication and column exposure require a live Supabase security test before release, including confirmation that order secret fields cannot leak through subscriptions. PGlite tests do not exercise Supabase's realtime gateway.
