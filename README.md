# MoveTraq

MoveTraq is a Flutter delivery app with sender and deliverer flows backed by a Node.js API and PostgreSQL.

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
