# MoveTraq

## Online Deployment

Live admin: https://movetraq-production-admin.onrender.com

Live Supabase API: https://movetraq-production-api.onrender.com/health

See [verified hosted status](docs/HOSTED_STATUS.md) for checks and limitations.

Use `render.production.yaml` for the current Supabase API and React admin.
See [go online checklist](docs/GO_ONLINE.md) for cloud access, secrets,
database migration checks and verification. The root `render.yaml` remains the
legacy mobile API deployment; do not substitute archive deployment scripts.

## Archive Merge

The supplied `Movetraq.rar` is being selectively merged while preserving the
existing database and configuration. See [merge status](docs/ARCHIVE_MERGE.md)
for adapted features and remaining work. Restart the local API/admin with
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools/start-local.ps1`.

## Updated UI

The supplied updated design is implemented across the mobile screen families,
with 73 additional routes and an aligned admin visual foundation. See
[screen coverage and integration boundaries](docs/UI_SCREEN_COVERAGE.md).
Run `flutter test` for responsive layouts and generated screenshots.

MoveTraq is a Flutter delivery app with sender and deliverer flows backed by a Node.js API and PostgreSQL.

The Supabase/TypeScript production migration lives in `backend/` and
`supabase/`. Its current implementation, API contract, deployment instructions
and remaining release work are documented in
[Production Implementation Status](docs/PRODUCTION_IMPLEMENTATION.md).
The Flutter app still targets the legacy `server/` API; the new backend is not
yet a complete replacement. Legacy identifier-only password reset is disabled.

This repository keeps the Android app source and Render backend source. Desktop, iOS, web, generated build output, and local tool caches are not required for the current Android release workflow.

## Backend

The backend lives in `server/` and is deployed on Render.

Required production environment variables:

```bash
DATABASE_URL=postgres://USER:PASSWORD@HOST:5432/DATABASE
JWT_SECRET=use-a-long-random-secret
NODE_ENV=production
```

Optional environment variables:

```bash
PORT=3000
ACCESS_TOKEN_TTL_SECONDS=604800
CORS_ORIGINS=*
DISABLE_TEST_WALLET_TOPUPS=false
```

`DISABLE_TEST_WALLET_TOPUPS=false` keeps the prototype wallet top-up route usable. Set it to `true` after connecting a real payment provider.

Run the API locally:

```bash
cd server
npm install
npm start
```

Health checks:

```bash
GET /health
GET /health/db
```

## Render

The repo includes `render.yaml`.

Render settings:

```bash
Root Directory: server
Build Command: npm ci
Start Command: npm start
Health Check Path: /health
```

Set `DATABASE_URL` to your Render PostgreSQL, Supabase, Neon, or other hosted PostgreSQL connection string.

## Flutter

The Flutter app uses the hosted Render API by default:

```bash
https://movetraq-api.onrender.com
```

Run explicitly against Render:

```bash
flutter run --dart-define=MOVETRAQ_API_URL=https://movetraq-api.onrender.com --dart-define=GOOGLE_MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
```

Build APK:

```bash
flutter build apk --release --dart-define=MOVETRAQ_API_URL=https://movetraq-api.onrender.com --dart-define=GOOGLE_MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
```

The live tracking screens use native Google Maps on Android. Set `GOOGLE_MAPS_API_KEY` with `--dart-define`, an environment variable, a Gradle property, or `android/local.properties`; the Android manifest receives that value at build time. If the in-app diagnostics show the key is configured but the map is blank, enable **Maps SDK for Android** for that key in Google Cloud and make sure the Android app restriction includes package `com.example.movetraq` plus the SHA-1 shown by the diagnostics panel.

The backend also geocodes typed pickup/drop-off addresses. For hosted deployments, set `GOOGLE_PLACES_API_KEY` or `GOOGLE_GEOCODING_API_KEY` on the Node server and enable **Places API** plus **Geocoding API** for that key. Use a server/API-restricted key for the backend; an Android package/SHA-1 restricted key usually will not work from the server.

Courier tracking uses the deliverer's device GPS while the active delivery screen is open. Prototype/simulated movement is labelled as simulated and is replaced automatically once real GPS updates reach the app/API.

Local in-memory fallback is disabled for normal builds. Only enable it for isolated development:

```bash
flutter run --dart-define=MOVETRAQ_ALLOW_LOCAL_FALLBACK=true
```

## Current Backend Flows

- Authentication: signup, signin, password reset, current user
- Profiles and user location
- Deliverer availability
- Sender orders
- P2P targeted delivery requests
- Express open delivery requests
- Order acceptance, negotiation, stage updates, live courier location
- Escrow hold, refund, release, wallet transactions
- Notifications
- Order chat
- Address autocomplete

## Security Notes

- Do not commit `.env`.
- Do not expose database credentials in Flutter.
- Keep `JWT_SECRET` private and unique per environment.
- Wallet balance changes should remain server-side only.
- Direct wallet mutation is disabled in production through the API.
- P2P orders are only visible to the sender and targeted deliverer.
