# MoveTraq Archive Merge

Source: `C:\Users\dell\Documents\Movetraq.rar`.
Decision: selectively merge features, preserving this project's database and configuration.

## Source Review

The archive contains a separate Flutter package under `mobile/`, a Riverpod/
GoRouter frontend, an Express 5/PostgreSQL backend, and a React administration
application. Its migrations use a different schema and history than this
checkout. It is not a drop-in update. Its README and status documents describe
work in progress; their hosted verification claims have not been independently
verified in this merge.

404 source files were staged under `.archive-review/2026-10-14/Movetraq/`.
Git internals, dependency/build caches, environment files, saved sessions,
mobile runtime configurations and signing secrets were excluded. This staging
directory is ignored. No archive setup, seeding, role-granting, payment or
migration scripts were executed.

## First Adapted Features

- Admin order browsing: reference search, status/service filters, 25-row
  pagination, delivery route/recipient information, actual payment/escrow state
  and the latest 100 timeline events. This adapts the archive's order-inspection
  concept to `public_ref`, `total_amount_minor` and the existing schema.
- Backend `GET /api/v1/admin/orders` and `GET /api/v1/admin/orders/:id`:
  operations/admin/super-admin authorization, validated UUID/filter/pagination
  inputs and explicit projections. No handover codes, private storage paths,
  chat bodies or arbitrary metadata are returned.
- Local restart script: builds the current backend, validates configuration,
  uses its configured port, verifies service identity and starts hidden local
  servers. It does not start the archive's incompatible worker.

Order inspection is read-only. Refunds, reassignment, new financial mutations,
archive migrations and cloud changes are not part of this increment. Existing
user work and credentials remain intact.

## Pasted Mobile Screen Adaptations

The supplied personal-details and home screens have been adapted to the
current Provider/legacy API architecture rather than introducing incompatible
Riverpod imports. Personal details prefill the signed-in profile, validate and
trim edits, display read-only email, guard duplicate saves and retain edits
after failure. Optional empty phone numbers follow the existing API contract.

Home now separates typed data loading from `HomeContent` presentation. It shows
the selected booking pickup or an explicitly marked saved default, the newest
nonterminal sender order (including pending offers), compact quick actions,
four service tiles and the supplied charcoal/lime visual hierarchy. It uses
existing registered routes. Pull-to-refresh and error retry call the real data
refresh method; address/order snapshots are reset when the signed-in user changes.
Saved-address default flags are parsed without inventing a default address.
This does not migrate authentication to Supabase or enable unimplemented APIs.

Verified: 5 personal-details tests, all 34 redesign tests, home screenshot review
and targeted Flutter analysis without issues.

## Remaining Merge Work

The supplied backend service batch now has a
[service mapping and verified adaptations](BACKEND_SERVICE_MERGE.md).
Address lookup and transactional P2P ads were adapted to the current backend;
financial, auth and order implementations were retained. This is not a wholesale
import of the archive's 28 services.

All supplied core and feature file paths are now adapted in the current
workspace. See [mobile module update](MOBILE_MODULE_UPDATE.md) for the 12-core/
32-feature inventory, compatibility adapters, verified contracts and remaining
integration boundaries.

The entire archive has not been merged. Review/adapt its mobile authentication,
preferences, encrypted offline cache, chat retries/receipts, P2P ad lifecycle,
support threads/attachments, verification realtime, dispatch, notifications,
payout management and administrative configuration individually. Preserve the
current API and database contracts, adding reviewed forward migrations only
where necessary. Do not copy the archive's dated migration chain into the live
project or import its development accounts and session files.

## Verification

Backend: `npm.cmd run typecheck`, `npm.cmd test -- tests/accounts-api.test.ts`.
Admin: `npm.cmd run build`, `npm.cmd test -- --grep archive-adapted --workers=1`.
Local services: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/start-local.ps1`.

API/browser tests use test-only fixtures. They do not prove that an admin
account can sign in or that live order histories exist in hosted Supabase.

Verified: backend typecheck, admin build, 45 API tests and both desktop/mobile
order-inspection browser tests. The browser runner was interrupted after both
tests passed because its Windows web-server shutdown did not finish.

The conflicting dated migration chain was moved with user approval to
`supabase/reference-migrations/archive-2026-10/`. All 16 archive SQL files are
preserved there; at that stage only `0001`-`0013` remained in the active directory.
The backend service increment now appends reviewed local migration `0014_delivery_ads.sql`.
No hosted migrations were applied or changed. The local `backend/.env` is
also absent; the restart script correctly
refuses to start an unconfigured API. No credentials were restored from the
archive. The admin frontend can be previewed separately, but live signin is
not verified.

After separating the migration chains, the complete backend suite passes:
9 test files, 92 tests, including all embedded PostgreSQL migration tests.
