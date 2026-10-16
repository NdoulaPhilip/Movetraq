# Hosted Status

Maps release verified on 2026-10-16; initial hosting checks below are from
2026-10-15. These are hosting checks, not a completed production
acceptance audit or proof of live payment/delivery journeys.

| Service | Public URL | Render ID |
| --- | --- | --- |
| React admin | https://movetraq-production-admin.onrender.com | srv-db8as0ss728c738qb0qg |
| Supabase API | https://movetraq-production-api.onrender.com | srv-db8as06q1p3s73a7g03g |
| Existing mobile API | https://movetraq-api.onrender.com | srv-dapuig6gekts73f94a6g |

The new API uses a free web-service plan. Admin is a static site. Existing
mobile API settings and the hosted database were not replaced. No Supabase
migrations were applied during this deployment. Read-only checks confirmed
expected account/security/wallet/ad/pricing/admin-directory columns existed.

## Mobile map display restoration — 2026-10-16

The user requested undoing the OSM map display. Flutter views now use Google
Maps again; automatic GPS, saved addresses and delivery-sharing fixes remain.
Flutter analysis and all 105 tests pass. The Android display needs a Maps SDK key,
which was not present in the checked local Android properties/build environment.
The existing hosted Photon/OSRM APIs below are retained; no Render configuration
or database rollback is needed for the native map display restoration.

## Maps API release — 2026-10-16

- Supabase API deployment `dep-db9072rl550s73fdolh0` is live on `142a497`.
- Mobile API deployment `dep-db904oon74is73d1t5tg` is live on `dff1e81`.
- Both health checks and the mobile PostgreSQL health check pass.
- Existing migrations `0015` and `0016` were confirmed through read-only RPC
  calls. No migrations, accounts, orders or payments were created by these checks.
- Authenticated saved-address reads, Photon search/reverse lookup and OSRM road
  geometry pass against the hosted API. The public-landmark route check returned
  4,597 metres, 351 seconds and 136 road points; these are estimated provider metrics.
- Missing service authentication and missing mobile authentication return 401.
  The shared bridge tokens match and the mobile authority URL remains correct.
- `MAPS_PROVIDER=osm`, `GEOCODER_PROVIDER=photon` and the provider endpoints are
  configured on Render. Nominatim search/reverse lookup failed from the Render
  service, so the release uses Photon. Public provider capacity limits still apply.
- Database, JWT and payment credentials were preserved. Admin was not redeployed.

Use `node tools/render-maps.mjs status` or `node tools/render-maps.mjs verify`
for deployment status and read-only live checks. `inspect` checks the existing
services/schema and reports configuration key differences without printing secrets.
`configure` changes only maps/bridge variables; `deploy backend` and `deploy mobile`
deploy the exact current commit after confirming it was published to `origin/main`.
The helper only targets the two existing API services; it does not provision resources.

Install the updated Flutter APK for the OpenStreetMap views. Real-device GPS,
permission prompts and a complete sender/driver journey remain device acceptance
checks; successful provider checks do not replace those tests.

## Initial hosting verification

- Both new Render deployments reached live on Git commit `6a73d0e`.
- API `/health` identifies `movetraq-backend`.
- Unauthenticated `/api/v1/users/me` returns 401.
- API CORS matches the actual admin origin; sign-in preflight succeeds.
- Admin HTML and compiled JavaScript assets load over HTTPS.
- The admin bundle uses the new API URL including `/api/v1`.
- Direct `/accept-invitation` requests return the admin SPA.
- Configured Render, Supabase service-role and payment secrets were not found
  in the compiled admin JavaScript. Admin environment contains only
  `NODE_VERSION` and the public `VITE_API_URL`.
- API environment matches the configured Supabase project/keys and admin origin.
- Existing mobile API health and PostgreSQL connectivity were also verified
  after its separate update to `6a73d0e`.

## Maintenance

Use `node tools/render-current.mjs` for read-only deployment status and
`node tools/render-current.mjs --verify` for public hosting checks. The helper
loads ignored local credentials; it never prints their values.

`--deploy` provisions/reuses only the two named current services in the
workspace containing the configured legacy service. Existing repository/type/
root mismatches fail instead of being overwritten. Secret transfer and resource
creation require the owner's explicit approval. It does not migrate the
database, configure Supabase auth settings or change the legacy mobile API.

Do not run the incompatible archive's `tools/render-deploy.mjs` or use its
`render.preview.yaml` for these services. The current declarative setup is
`render.production.yaml`. Secret values belong only in backend environment
settings and ignored local `.env`, never in GitHub or admin build variables.
Rotate any secret shared in chat and update its intended consumer separately.

## Remaining Release Checks

Actual administrator sign-in, staff-role provisioning, invitation/recovery
email delivery and Supabase redirect allowlists were not verified. Hosting
does not create or grant an administrator account. Paystack webhook dashboard
setup and real payment reconciliation remain unverified; payments use test
configuration. No real charge was initiated during deployment.

The Flutter UI still uses the legacy API for many workflows. Do not switch it
wholesale to the new API before migrating its authentication and data contracts.
App-store publication, real-device testing, push, background tracking, provider
refunds/transfers and other documented integration gaps remain separate work.
