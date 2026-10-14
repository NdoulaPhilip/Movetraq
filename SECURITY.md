# Security

Clients are untrusted. Ownership and roles come from verified auth/database records; quotes, payments, evidence, state transitions, financial balances, and release decisions are validated server-side.

Keep database credentials, service-role keys, payment secrets, encryption keys, and Firebase service accounts outside source control. Logs redact authorization headers. Use verified TLS, narrow CORS origins, secure mobile token storage, private buckets, short-lived signed URLs, and separate environments.

Admin finance privileges are distinct from support/verification privileges. Financial interventions require confirmation, idempotency, and audit records. Blocked relationships constrain future matching without deleting existing order history.

Required pre-release verification: cross-user REST/RLS/realtime access, role escalation, signed upload replay/type/size, payment signature/reference/amount mismatch, duplicate release/refund/payout, concurrent wallet operations, revoked sessions, account erasure, and financial recovery after worker crashes.

Current limitations include per-process HTTP rate limits, incomplete retention/erasure, incomplete provider refund execution, and unverified live realtime secret filtering. Resolve these before exposing the service publicly. See [Supabase RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security).
