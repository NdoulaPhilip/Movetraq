# Architecture

Flutter uses Riverpod, GoRouter, Dio, Supabase Auth/Realtime, secure token storage, and native maps. React staff clients use public authentication and the Node API. Neither client receives service-role or payment secrets.

The API separates routes, controllers, services, repositories, validators, and middleware. Supabase verifies bearer tokens; trusted database roles authorize operations. PostgreSQL owns transactional financial and order state. Provider integrations fail explicitly when credentials are absent.

Money uses integer minor units. Balanced immutable journals connect wallet, escrow, platform earnings, deliverer earnings, and payout reserves. Order mutations lock database rows, validate actors/transitions, and use persistent idempotency records. Provider webhooks require signature validation and server verification of reference, amount, and currency.

A durable outbox drives inbox/push delivery. A worker leases events with retries, handles reminders, dispatch, payout reconciliation, and retention maintenance. Database state survives process restarts. Maps and payments have provider boundaries; unconfigured calling currently returns unavailable.

Remaining release work includes complete native/admin parity, external refund-provider execution, comprehensive account erasure/retention, device background tracking, and live concurrency/security/end-to-end verification. Read-only or partial screens must not be represented as completed workflows.
