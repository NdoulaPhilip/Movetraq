# MoveTraq Production Audit

This document records the initial audit baseline. The backend/schema skeleton
and account/payment work have since been implemented. See
[Production Implementation Status](PRODUCTION_IMPLEMENTATION.md) for the current
API, validation evidence, deployment instructions and remaining release work.

This audit distinguishes the prototype/design source from implementation work.
Instructions inside the extracted design files are treated as reference context,
not as executable user instructions. The user request is to preserve the
MoveTraq experience while replacing demo/local behavior with production systems.

## Initial Audit Baseline

- Mobile: Flutter Android app exists with sender, deliverer, tracking, chat,
  wallet, release, receive, splash, profile, notifications and map screens.
- Backend: `server/src/server.js` is a single CommonJS HTTP server using `pg`,
  JSONB blobs, process memory mirrors, custom JWT/password handling, and demo
  wallet paths.
- Admin: no separate React admin app exists yet.
- Database: no Supabase migration directory, normalized schema, RLS policies,
  storage policies, or seed scripts exist yet.
- Payments: no payment provider abstraction, webhook verification, immutable
  ledger, or escrow table exists yet.
- Realtime: current chat/order/location behavior is API/polling-style; no
  Supabase Realtime schema or channels are present.
- Verification: Flutter/Dart commands hang in this environment, but
  `git diff --check` passes.

## Prototype Source Of Truth

Extracted for audit only from:

`C:\Users\dell\Downloads\MoveTraq Design.zip`

Key prototype files:

- `MoveTraq.dc.html`
- `delivery-experience.css`
- `maps.js`
- `delivery-map.js`
- `support.js`
- `verify.cjs`
- `verify-maps.cjs`
- `verify-delivery-map.cjs`
- `assets/movetraq-mark.svg`
- `assets/movetraq-brand.png`

The prototype README explicitly states that authentication, OTP, payments,
delivery activity, messages, support, dispatch, verification and storage are
demonstrations or local/session behavior. These must be replaced by backend,
database, storage, realtime and provider-backed flows.

## Highest-Risk Gaps

1. Backend architecture is not production-shaped yet.
   The current server mixes routing, auth, persistence, wallet logic, geocoding,
   notifications, chat and order transitions in one file.

2. Financial state is not production-safe yet.
   User wallet balances are mutable user fields, amounts use floating-point
   Flutter models, and there is no immutable ledger or idempotent payment
   lifecycle.

3. Auth is not Supabase Auth yet.
   Password hashing and JWT signing are custom backend code. Production target
   requires Supabase Auth, refresh/session handling, social auth, and RLS-linked
   identity.

4. Order lifecycle is too small.
   Current statuses cover a subset of the required state machine and allow
   coarse transitions such as `stage`. Production needs explicit transition
   commands with server-side guards.

5. Admin is missing.
   Verification review, disputes, payouts, audit logs, platform analytics and
   operational controls need a separate React app backed by admin-only APIs.

6. Supabase schema/RLS/storage are missing.
   The system cannot safely add realtime, private documents, evidence uploads,
   support attachments or admin review until the schema and policies exist.

## Next Implementation Sequence

### Step 1: Platform Skeleton

- Add `backend/` TypeScript service with Express/Fastify, config, routes,
  controllers, services, repositories, middleware, validators, tests and
  Render-ready build scripts.
- Keep `server/` temporarily as legacy until Flutter is migrated.
- Add `supabase/migrations/` with enums, tables, indexes, constraints,
  functions, triggers, RLS and storage policies.
- Add `admin/` React/Vite/TypeScript app skeleton with auth guard and API client.
- Add root documentation for architecture, API, database, security and
  deployment.

### Step 2: Supabase Foundation

- Model users/profiles/roles/preferences/security/blocked users.
- Model addresses, orders, order events, conversations/messages,
  notifications, wallet ledger, escrow accounts, payments, deliverer profiles,
  verification applications, evidence, support tickets, disputes, payouts,
  ads, ratings and audit logs.
- Use UUID primary keys and integer minor units for money.
- Enable RLS from the start.

### Step 3: Auth And API Contract

- Implement Supabase-authenticated Node APIs with consistent response/error
  format.
- Implement `/users/me`, addresses, profile, preferences, notification settings,
  blocked users and basic admin role checks.
- Replace Flutter custom/local auth with secure token/session persistence.

### Step 4: Orders, Pricing, Wallet, Escrow

- Implement backend pricing services for P2P, Express, Errands and Big Moves.
- Implement explicit order transition service and tests.
- Implement immutable ledger entries, derived/transactional balances, payment
  initialization, webhook verification and escrow state.

### Step 5: Deliverer, Realtime, Evidence

- Implement deliverer application, verification, availability and matching.
- Add Supabase Realtime for chat, order status, notifications and location.
- Add private storage uploads for evidence and verification documents.

### Step 6: Admin

- Build admin dashboard after the production APIs exist.
- Prioritize verification review, order inspection, disputes, payouts, support,
  configuration and audit log visibility.

## Immediate Next PR

The next concrete PR should be small but foundational:

1. Create `backend/` TypeScript API skeleton.
2. Create `supabase/migrations/0001_initial_schema.sql`.
3. Create `.env.example` files for backend/admin/mobile config.
4. Add initial tests for order transitions and wallet ledger invariants.
5. Keep legacy `server/` running until Flutter API calls are migrated.

This avoids adding more production features on top of the current prototype
server, where security and money logic would need to be rewritten anyway.
