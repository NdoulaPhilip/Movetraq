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
flutter run --dart-define=MOVETRAQ_API_URL=https://movetraq-api.onrender.com
```

Build APK:

```bash
flutter build apk --release --dart-define=MOVETRAQ_API_URL=https://movetraq-api.onrender.com
```

Maps now use OpenStreetMap through `flutter_map` and require no Google Maps key. GPS is requested after login on the dashboards. See [OSM maps setup and testing](docs/OSM_MAPS.md).

The legacy mobile API forwards address lookup, routing and tracking to the Supabase backend through the existing authenticated bridge. OSRM handles road routing; the Render deployment uses Photon for OSM geocoding. See [OSM setup](docs/OSM_MAPS.md) for service configuration and public endpoint limits.

Courier tracking uses fresh device GPS samples while the active delivery screen is open. Tracking is restricted to delivery participants; stale samples expire from the live view. Road lines and travel metrics come from the route provider. Missing provider configuration produces an unavailable state.

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
