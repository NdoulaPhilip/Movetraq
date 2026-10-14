# Deployment

Deployment is pending external project configuration and completion of the release audit. Do not use the current build as an approved production release.

## Supabase

Apply migrations, configure email delivery and confirmation, register Google/Apple OAuth credentials and `movetraq://auth/callback`, and verify private storage/RLS/realtime behavior with separate sender, deliverer, and staff identities. Seed staff privileges through a controlled database administration process; ordinary signup cannot assign staff roles.

## Render

Source is available in the private repository `https://github.com/AlepsGitHub/MoveTraq` on `main`. The API and admin preview were deployed on 4 October 2026:

- API: https://movetraq-api-ymc2.onrender.com
- Admin: https://movetraq-admin.onrender.com
- Database readiness: https://movetraq-api-ymc2.onrender.com/ready

Both Render deployments reached `live`. Verified public database readiness, authenticated sender profile/wallet/orders reads, admin SPA route handling, the admin's compiled API URL, allowed admin CORS origin, and rejection of unauthenticated API calls. This does not establish full delivery/payment journeys or admin role provisioning. The worker and deferred providers are not provisioned. The free API can sleep when idle.

The external keep-awake/readiness check is configured in https://github.com/AlepsGitHub/movetraq-uptime and runs every ten minutes through GitHub Actions. It checks `/ready`, retries cold-start/network failures, and runs without the local computer. This is best-effort: schedule delays, Render restarts, and shared free-hour limits still apply. GitHub disables scheduled workflows on public repositories after 60 days without repository activity; re-enable in Actions when needed. Disable that workflow to stop the checks. No application secrets are stored in the monitoring repository.

For the initial API/admin preview, use `render.preview.yaml` as the Blueprint path. It explicitly selects a free API plan and uses `/ready` to check database connectivity. It omits the paid background worker; dispatch, notification processing, scheduled maintenance, and payout reconciliation need the worker before delivery journeys can be considered ready. The full deployment remains in `render.yaml`.

If the database certificate is not trusted by the default Node CA store, download its CA certificate from Supabase Database Settings → SSL Configuration. Set `DATABASE_CA_CERT_BASE64` to the base64 encoding of that PEM file in local and Render environments. The database pool uses this CA with certificate and hostname verification enabled. Do not disable TLS verification to work around a certificate-chain error.

For direct API deployment, save `RENDER_API_KEY` in ignored `backend/.env`, then run `node tools/render-deploy.mjs` for read-only status or `node tools/render-deploy.mjs --deploy` to create/update the free API and static admin services. If multiple Render workspaces are available, the script lists their IDs and requires `RENDER_OWNER_ID`. Render must have access to the private GitHub repository. The script submits builds; confirm they reach `live` and verify API `/ready` before switching the mobile build to its public API URL. It does not provision the worker or enable deferred providers.

Before deployment, supply a working `DATABASE_URL` and apply/check migrations. Server secrets belong in Render environment settings, never in the repository. For the temporary preview, the user has chosen to turn off **Confirm email** in Supabase until SMTP is ready. The app handles immediate signup sessions and retains verification for later. Re-enable confirmation and save `supabase/templates/confirmation.html` when email delivery is configured; uploading the template alone does not change hosted emails. Password recovery still requires email delivery.

Create a Node web service from repository root: build `cd backend && npm ci --include=dev && npm run build`, start `cd backend && npm start`, health path `/health`. Provide server environment values from `backend/.env.example` using Render secret settings. Run migrations as a controlled release step from the repository root context. Create a separate worker with start `cd backend && node dist/jobs/worker.js`; confirm worker entry-point execution and scaling before provisioning.

Admin static build: `cd admin && npm ci --include=dev && npm run build`, publish `admin/dist`, with SPA rewrites to `/index.html`. Build-time VITE variables must contain public values only. Limit API CORS to the real admin origin.

## Providers and mobile

Configure Paystack test mode first, callback URL, signed webhook URL, bank transfers, and payouts. [Paystack webhook documentation](https://paystack.com/docs/payments/webhooks/) describes signature validation. Reconcile money before enabling live keys.

Payout bank selection obtains names/codes from the provider's [bank API](https://paystack.com/docs/api/miscellaneous/); validate coverage and pagination against the configured account before launch.

Enable Google Places, Routes, and Maps SDKs. Restrict mobile keys by package/signature or bundle ID and server keys by server access. Android reads `GOOGLE_MAPS_ANDROID_KEY`; iOS requires its map build setting. Never ship a server API key in Dart defines.

Register Android/iOS apps in Firebase, provide native configuration files locally, and provision APNs. Supply the worker's Firebase service account through a secret file and its configured path. Validate push delivery on physical devices.

Android release requires local `mobile/android/key.properties` and protected signing material. iOS requires macOS, signing, provisioning, and physical-device permission tests. Enable MAPS_ENABLED/PUSH_ENABLED only after configuration. Run both mandatory end-to-end journeys with real providers before publishing apps.
