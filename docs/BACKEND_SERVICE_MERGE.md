# Backend Service Merge

The 28 supplied `Documents/Movetraq/backend/src/services/*.ts` files belong to
the archive's separate `pg`/journal-based architecture. They are reference
inputs, not drop-in replacements for this backend's Supabase SDK, wallet
ledger and service-only transactional RPCs. No external source files, secrets,
runtime configuration or hosted database were modified.

## Adapted In This Batch

- Real Google Places text search and reverse geocoding behind an injectable
  `AddressProvider`. Authenticated routes validate inputs and rate-limit lookup.
  Timeouts, redirects and malformed responses fail safely. No public Photon or
  OSRM demo is enabled automatically. Unconfigured providers return 503.
- P2P ad create, own-list/detail, edit, pause, resume, soft-delete and discovery.
  Creation keys are account-scoped and transactional; conflicting retries fail.
  Transport comes from the verified deliverer profile, not the request.
- Discovery checks both route coverages, declared delivery area, parcel weight,
  active-job capacity, service preferences, online state, approved verification,
  active accounts, current tariff minimum and both directions of blocking.
  Availability is evaluated on the database clock. Candidates are suggestions,
  not reserved jobs, quotes or assignments; order eligibility is rechecked by
  the existing order workflow.
- Owner-only direct ad reads and API-only discovery. Client writes and client
  execution of mutation/discovery RPCs are revoked. Replay keys/payloads are
  excluded from API projections. Existing activity triggers monitor ad changes.

`0014_delivery_ads.sql` is an append-only migration following the unchanged
`0001`-`0013` chain. Dated archive migrations remain reference-only. Apply 0014
to a disposable Supabase project and then through the usual reviewed deployment
process. It has only been executed in embedded PostgreSQL tests here.

Historical malformed coverage/availability rows are preserved, excluded from
discovery and require correction before publication. Soft deletion remains
possible. There are no seeded launch prices or financial ledger changes.

## API

All paths are relative to `/api/v1` and require Supabase bearer authentication.

| Method | Path | Contract |
| --- | --- | --- |
| GET | /addresses/search | `query` (3-200 characters); returns `addresses` |
| POST | /addresses/reverse | numeric `latitude`/`longitude`; returns `address` |
| GET | /deliverers/me/ads | `limit`/`offset`; returns own non-deleted `ads` |
| GET | /ads/:id | owned non-deleted detail; returns `ad` |
| POST | /ads | structured ad input and `Idempotency-Key`; returns `ad` |
| PATCH | /ads/:id | full structured ad input, or `{status: published|paused}` |
| DELETE | /ads/:id | owner soft-delete; repeated deletion is safe |
| GET | /ads | pickup/destination coordinates, `weightKg`, optional `limit`/`offset` |

Ad inputs: `title`, `pickupCoverage`, `destinationCoverage`, `priceMinor`,
`availableFrom`, `availableUntil`, optional `notes`. Coverage contains numeric
`latitude`, `longitude`, integer `radiusMeters` (100-100000), and `label`.
Prices are integer NGN minor units, bounded by the configured P2P tariff minimum
and 100000000. Availability timestamps require ISO offsets and a future end.
New ads are published; edits retain their existing status.

Discovery query fields: `pickupLatitude`, `pickupLongitude`,
`destinationLatitude`, `destinationLongitude`, `weightKg`. Complete coordinates
are required, not free-text coverage or a client eligibility flag.

Configure `GOOGLE_PLACES_API_KEY` and `GOOGLE_GEOCODING_API_KEY` on the backend;
each can fall back to the existing `GOOGLE_MAPS_API_KEY`. Nothing is written to
the missing `.env`. See [Google Places text search](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places/searchText)
and [reverse geocoding](https://developers.google.com/maps/documentation/geocoding/guides-v3/requests-reverse-geocoding).

## Service Mapping

These mappings describe coverage, not a claim that every supplied behavior is live.

| Supplied Service | Current Implementation / Boundary |
| --- | --- |
| account | account-service/account-repository; deletion/anonymization remains pending |
| address-search | New address-search service and protected routes |
| admin | Current verification, pricing, support and activity controls; not archive analytics |
| admin-management | admin-users-service and audited platform-user RPC; no journal/payout controls copied |
| admin-orders | Existing read-only order inspection; controlled reassignment/cancellation remains pending |
| ads | New ads service/repository/validators/routes and migration 0014 |
| business | Existing versioned pricing_rules; general business_config not imported |
| communication | Current order message/read-receipt and notification RPCs; attachments/inbox extensions pending |
| deliverer | Current availability/jobs/verification RPCs; counteroffer negotiation not imported |
| deliverer-insights | Existing summary/past-customers RPCs; expanded time series pending |
| dispatch | Current eligibility remains authoritative; automated system dispatch pending |
| idempotency | Existing operation-specific transactional keys; no incompatible generic replay table |
| ledger | wallet-ledger plus financial RPCs retained; no accounts/journals substitution |
| maps | Existing GoogleMapService route abstraction retained |
| matching | Existing deliverer_is_eligible; new ad discovery uses current coverage/capacity fields |
| moderation | Existing two-way blocking retained; dedicated moderation reports pending |
| order-machine | Existing semantic commands and database state guards retained |
| orders | delivery-service/delivery-repository and quoted-order RPCs retained |
| payments | Existing verified wallet top-ups retained; direct provider order checkout pending |
| payouts | Provider transfer/reservation/reconciliation architecture still pending |
| paystack | Existing integrations/paystack and webhook/verification checks retained |
| pricing | Existing pricing-service and configured tariff snapshots retained |
| push | FCM backend device registration/outbox worker still pending |
| returns | Existing return_requests/approval/settlement RPCs retained |
| routing | Existing live Google routes retained; no commercial public-demo fallback |
| settings | Existing separate preferences tables retained; PIN/session administration pending |
| storage | Existing private verification/evidence services retained; generic uploads/decoding pending |
| support | Existing support cases/staff review retained; support threads/attachments pending |

## Verification And Remaining Integration

On 2026-10-14: backend typecheck and production build passed; all 102 tests
passed, including 11 embedded SQL test files. Tests use local fixtures, not
live Google, Supabase, Paystack or Firebase services.

The Flutter feature gateway remains disabled. Its current ad form uses free-text
coverage/availability and must be migrated to these structured contracts before
connecting it; its `active` status must become `published`. Mobile authentication
must also use the production backend token format. This batch does not switch
the existing legacy mobile/server integration or enable unsupported calling,
withdrawals, provider refunds, automatic dispatch or push delivery.
