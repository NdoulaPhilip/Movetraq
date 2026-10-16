# Go Online

The current API and admin are now hosted. See [verified hosted status](HOSTED_STATUS.md)
for URLs, checks and remaining release boundaries. The checklist below remains
the setup/reference procedure.

GitHub source: `https://github.com/NdoulaPhilip/Movetraq`, branch `main`.
Use `render.production.yaml` for the current Supabase backend and React admin.
The existing root `render.yaml` still deploys the legacy `server/` application.
The archive's `render.preview.yaml` and `tools/render-deploy.mjs` target a
different repository/schema and must not be used for this checkout.

## Hosting Setup

1. Connect the intended Render workspace and Supabase project. Inspect existing
   services before creating replacements. Do not create a new database in place
   of the existing one or provision paid resources without approval.
2. Check migration history, back up the existing database and apply only missing
   numeric migrations `0001` through `0016`. Never apply reference migrations.
   SQL tests have run locally, not against the hosted project.
3. In Render, create/sync a Blueprint from the approved GitHub repository using
   `render.production.yaml`. The API is explicitly a free web service; the admin
   is a static site. Keep the legacy API available for existing mobile clients.
4. Configure API `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
   `SUPABASE_SERVICE_ROLE_KEY` using that project. Set `CORS_ORIGINS` to the actual
   HTTPS admin origin and configure approved Supabase auth/invitation redirects.
   Enter the rotated Paystack test secret as `PAYMENT_SECRET_KEY` in Render.
   Configure the callback URL and provider webhook
   `<api-origin>/api/v1/payments/webhooks/paystack`.
5. Set admin `VITE_API_URL` to `<api-origin>/api/v1`, then rebuild the admin.
   Never use the legacy API origin, an internal Render hostname or localhost.
   Only this public API URL belongs in admin build variables, not server secrets.
6. Verify both deploys reach `live`, API `/health` responds, missing authentication
   returns 401, and actual sender/admin profile and database reads succeed. The
   health endpoint alone does not prove database readiness. Verify admin deep
   links, CORS, session refresh and private-file authorization separately.

Blueprint secret prompts occur on initial creation. Existing services need
their settings updated separately. See [Render Blueprint configuration](https://render.com/docs/blueprint-spec).
No local `.env` is uploaded or copied into GitHub by this setup.

## Remaining Product Work

The mobile maps bridge requires migrations `0015` (mobile approval identities)
and `0016` (saved addresses, routes and latest GPS samples). Configure the same
`MONITORING_SERVICE_TOKEN` on both APIs and set the legacy API's
`DELIVERER_AUTHORITY_URL` to the HTTPS Supabase backend origin. Set `MAPS_PROVIDER=osm` on the Supabase backend and configure `OSRM_URL` and `NOMINATIM_URL` for the intended routing/geocoding services. The mobile map needs no Google key. See [OSM maps setup](OSM_MAPS.md) for defaults and usage limits. Verify address search, pin reverse lookup, order
creation and participant tracking on a device after deployment; local checks
use isolated fixtures and embedded PostgreSQL.

Online hosting is not a declaration of production readiness. The current
Flutter UI still depends on the legacy server for many workflows. Do not
repoint it wholesale to the Supabase API until authentication and data contracts
are migrated. Native Android/iOS apps need signing and distribution separately.

Live payments, mobile production checkout, realtime subscriptions, push workers,
background tracking, withdrawals and provider refund workflows still require
integration/configuration and real-device/provider verification. See
`PRODUCTION_IMPLEMENTATION.md`, `MOBILE_MODULE_UPDATE.md` and
`BACKEND_SERVICE_MERGE.md` for boundaries. No migrations, Render services or
provider settings were changed in the cloud by preparing these files.
