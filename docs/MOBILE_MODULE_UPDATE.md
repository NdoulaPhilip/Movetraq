# Mobile Module Update

The supplied files from `Documents/Movetraq/mobile/lib/` are inputs to the
current workspace, not a second active application. All 12 core module paths
and all 32 requested feature module paths are present under `lib/core/` and
`lib/features/`. Existing screens were migrated where their behavior already
matched; adapter views reuse shared screens instead of duplicating them. Old
`lib/screens/` import paths re-export migrated implementations.

## Core

| Module | Adaptation |
| --- | --- |
| environment | Validated HTTPS production origins and `/api/v1`; no secrets imported |
| api | Existing server-mediated auth, one refresh retry, idempotency headers, account-change checks |
| uploads | Current evidence/document endpoints, byte/size preflight, same-project signed URLs, isolated upload transport, server confirmation |
| push_service | Firebase permission/APNs/token lifecycle, serialized registration, cancellation and unregister; disabled/unconfigured states |
| router | Centralized current named-route registry and source-screen aliases; no disruptive GoRouter switch |
| workspace_switch | Actual role-change completion, failure display, reduced-motion support; no timed fake success |
| cache | Encrypted, owner-scoped, serialized cache with TTL; no financial/eligibility/order snapshots |
| secure_session | Existing versioned secure session and namespaced PKCE storage; no second credential store |
| app_theme | Shared current design tokens, fonts and palette; no negative letter spacing |
| preferences | Server-confirmed larger-text/reduced-motion settings, system accessibility retained, reset per user |
| components | Supplied shared components and 32 bundled SVG icons; fixed currency encoding and removed decorative orb |
| resource_view | Loading, retry, safe errors and stale resource isolation |

Firebase auto initialization is disabled in the Android manifest. Permission
approval explicitly enables it; device unregister disables it before deleting
the token. No startup push service is enabled without a configured backend
registration integration. See [Firebase Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started).

## Features

| Family | Supplied files addressed |
| --- | --- |
| Addresses | addresses_screen, home_location_picker, location_search_screen |
| Auth | auth_repository, auth_screen, welcome_screen |
| Chat | chat_screen |
| Deliverer | application_screen, deliverer_gate, deliverer_screen, insights_screen, offers_screen |
| Earnings | payout_screen |
| Notifications | notifications_screen |
| Orders | create_order_screen, delivery_choice_screen, order_repository, orders_screen |
| P2P | ad_form_screen, ads_screen |
| Payments | checkout_request, payment_checkout, paystack_checkout_screen |
| Profile | personal_screen, profile_screen |
| Settings | blocked_screen, settings_screen |
| Support | support_screen |
| Tracking | order_screen, tracking_service |
| Wallet | deposit_amount, wallet_screen |

New helpers use the current backend contracts: quotes unwrap `quote`; orders
unwrap `order` and are created from `quoteId` plus an idempotency key; state
changes use `/orders/:id/commands`, not client-supplied arbitrary statuses.
GPS reports use `accuracyMeters` and `capturedAt`, verify active deliverer
assignment before permissions, throttle posts and stop new posts after opt-out.

Hosted Paystack checkout accepts `checkoutUrl`/`reference` from the backend,
checks HTTPS/provider origin and callback reference, and verifies through
`POST /payments/:reference/verify`. Only a matching server `verified` response
can return a verified result; close/callback navigation never credits a wallet.
The app remains native Flutter: only the hosted payment page uses WebView.
This follows [Paystack verification requirements](https://paystack.com/docs/payments/verify-payments/).

Blocked-user views use `blockedUsers`/`blocked_id`. Ad pages now have separate
public/owned views and non-optimistic edit/pause/resume/delete controls. Their
missing APIs remain behind the existing disabled feature gateway. Forms and
controls do not fabricate persisted results. The deliverer presentation gate
does not replace backend authorization or grant roles.

## Integration Boundaries

This is a compatibility migration, not a wholesale import of the archive's
Supabase/Riverpod application or database. The existing UI still uses Provider
and named Navigator routes. Coordinated Riverpod/GoRouter, Supabase-auth UI,
realtime/offline chat queues, background GPS, support attachments/threads,
live ad APIs, payout/bank verification, full provider configuration and live
device journeys remain release work. New production repositories, checkout and
GPS helpers are separately tested but are not silently substituted for the
legacy UI data gateway. Auth adapters retain the existing login/signup screens;
verification/recovery forms retain their explicit integration boundary.

Some feature modules are shared-screen adapters, not new bespoke screens.
Folder/path coverage does not mean every archive behavior is live. The source
files under `Documents/` were not edited. Existing database/configuration was
not replaced, and no archive credentials, role grants, workers or migrations
were executed. The missing local backend configuration still prevents live
backend startup until it is restored separately.

## Verification

On 2026-10-14, static analysis completed with no issues and all 90 Flutter
tests passed, including refresh failure handling, route boot, small-phone
layouts, authorization guards, payment contracts and GPS throttling. The
Android debug APK build also succeeded; output is
`build/app/outputs/flutter-apk/app-debug.apk`.

`flutter analyze --no-pub lib test`

`flutter test --no-pub`

`flutter build apk --debug --no-pub`

Tests use isolated fixtures for authentication, API, storage, GPS and UI.
They do not verify real payment completion, FCM delivery, hosted RLS/realtime
or iOS builds. Mobile screenshots remain in `build/ui-review/`.
