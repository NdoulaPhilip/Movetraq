# Hosted Status

Verified on 2026-10-15. These are hosting checks, not a completed production
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

## Verified

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
