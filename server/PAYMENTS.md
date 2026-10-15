# Android Wallet Test Payments

The legacy Android wallet uses this API, not the separate Supabase API.
Existing wallet balances are preserved. PostgreSQL is required; startup applies
the additive SQL in `migrations/0001_paystack_wallet.sql` automatically.

Configure the API environment, never the mobile app or GitHub:

- `NODE_ENV=production`
- `DISABLE_TEST_WALLET_TOPUPS=true`
- `MOVETRAQ_PUBLIC_API_URL=https://movetraq-api.onrender.com`
- `PAYMENT_SECRET_KEY`: Paystack test secret, set privately
- Existing `DATABASE_URL` and `JWT_SECRET` must remain configured.

Set the Paystack Test-mode webhook to
`https://movetraq-api.onrender.com/payments/webhooks/paystack`.
`GET /payments/config` reports readiness without exposing credentials.

Install the updated Android APK before testing Wallet > Add money. Checkout
completion alone does not credit funds: the API verifies the provider reference,
amount and currency, then records the credit transactionally. Signed webhooks
also verify payments when the app is closed. Repeated verification cannot credit
the same payment twice.

This integration intentionally rejects live secrets. Delivery card payments and
bank withdrawals are not enabled by this wallet change. Production withdrawals
fail without deducting funds. A real test checkout must still be performed to
validate the complete device/provider/webhook flow.

Before enabling real money, complete the broader legacy financial/security
review and reconciliation, including database TLS, payment recovery, refunds,
withdrawals and operational monitoring. The snapshot-store serialization is a
compatibility measure, not a high-throughput financial architecture.
