# MoveTraq Admin

Separate staff console for private deliverer verification, pricing and support.
The Node API enforces scoped staff permissions; hiding navigation is not an
authorization boundary. Access and refresh credentials are memory-only and
reload requires signing in again.

## Local Development

Set `VITE_API_URL` using `.env.example`, configure the backend CORS origin,
and run `npm ci` then `npm run dev`. The default origin is localhost:5173.
The new backend and Supabase migrations must be configured for real sign-in.
Grant staff capabilities using a trusted administrative database connection,
never signup metadata. The console does not provide a role elevation endpoint.

`verification_agent` reviews applications/documents. `finance` manages tariffs.
`support`/`operations` review cases and approve returns. `finance` can settle held
disputes but cannot approve returns. `admin`/`super_admin` can use all views.
Financial settlement checks evidence, return status and independent review on the
server; retry keys and immutable settlement records prevent repeated transfers.
Tariffs are versioned and audited;
launch prices are intentionally not seeded.

## Verification

- `npm run typecheck`
- `npm run build`
- `npm test`: headless installed Microsoft Edge, desktop and mobile viewports.
- `npm audit`: dependency advisories.

Browser tests intercept API requests with fixtures and write screenshots under
ignored `test-results/`. They verify responsive layouts, assets, review mutations,
unconfigured tariffs, scoped navigation and logout. They do not replace hosted
Supabase or payment-provider integration tests.
