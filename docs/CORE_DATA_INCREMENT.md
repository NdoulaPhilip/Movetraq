# Core Data And Delivery Requirements

## This Increment

- Fixed production mobile session restoration to consume the actual
  `data.user` backend profile envelope; tests now reproduce that shape.
- Exposed a serialized authenticated request boundary for feature repositories
  using the production session, never legacy tokens or browser local storage.
- Added typed production saved-address models and repository operations for
  list, add, full edit, delete, select and mark default. Models retain owner,
  label/address, coordinates, place ID, city/state/country, default and timestamps.
  Writes carry no client-selected owner. Selection requires server confirmation.
  Failures remain failures; no optimistic success or local persistence replaces SQL.
- Added `POST /api/v1/users/me/addresses/:id/default`, an account-scoped operation
  that changes only the default flag. Client-supplied address/account fields are
  rejected. The RPC locks the same profile row as normal address writes, validates
  ownership before clearing defaults, and preserves existing address details.
  The existing unique partial index still limits each account to one default.
- Added separate general and deliverer verification states to account responses,
  and retained simultaneous sender/deliverer roles in the production mobile model.
  Capability flags do not authorize jobs; verification, availability, suspension
  and order eligibility remain backend checks.

## Deployment

Apply only the new `supabase/migrations/0011_address_default.sql` to the new
development project, after migrations 0001-0010. Do not replay earlier files.
No hosted schema changes were made by this increment. Build/restart or redeploy
the backend after applying the migration. An old running process is not updated
by editing source or rebuilding its files.

## Existing Backend Coverage

The production backend already contains guarded orders for P2P, Express, errands
and big moves, quote pricing through Google Routes, separate shopping budgets,
wallet-funded holds and sender-confirmed release, deliverer verification with
private document reads, backend eligibility checks and delivery commands.
These existing implementations were not replaced or duplicated here.

This does not mean every listed flow is complete: automatic dispatch, repricing
negotiations, shopping-budget funding/reimbursement, provider withdrawals,
expanded deliverer analytics, and the full production mobile UI/API migration
remain in the release backlog. See PRODUCTION_IMPLEMENTATION.md.

## Validation And Boundaries

Backend unit/API and embedded PostgreSQL tests cover the new endpoint, absent
authentication, injected owner fields, dual roles and verification state, default
uniqueness/retries, preserved address content, cross-account rejection and
service-only RPC grants. Flutter tests cover the real profile envelope, typed
address CRUD, secure request headers, server denial and selection validation.

Existing address/auth screens still use LocalDataService and the legacy API.
The new repository is not wired into those screens yet. No live mobile address
journey, device build or hosted new default-address operation was verified here.
