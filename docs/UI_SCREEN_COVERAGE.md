# Updated MoveTraq Screen Coverage

Reference: the supplied Official MoveTraq Redesign image. The update preserves
the white, charcoal and lime visual language, compact form layouts, service
colors, parcel mark, and sender/deliverer navigation. It is native Flutter, not a
WebView. The existing admin remains a separate React application.

## Screen Inventory

The existing core routes are retained. `lib/screens/additional_screens.dart`
registers 77 additional routes, including shared-screen variants:

| Family | Screens and views |
| --- | --- |
| Account | Personal details, saved addresses, address selection/editing, settings, PIN, sessions, blocked people, notification/delivery/display/privacy preferences, account controls, deletion, app information |
| Booking | Destination search, native map picker, service selection, scheduling, P2P request, four-step Errand and Big Move forms, parcel camera/gallery |
| Payments | Checkout, transaction history/detail, payment methods/setup availability, withdrawals, payout history, membership |
| Delivery | Summary, receipt, completion detail, contact, calling availability, deliverer profile, sharing, rating, pickup, drop-off, code/photo handover, evidence history/upload |
| Support | Help, safety, tickets, delivery problems, returns, disputes |
| Deliverer | Opportunities, four-step application, verification/status/documents, work, analytics, performance, customers, conversations, earnings, orders, work preferences, P2P advertising forms/lists |
| Authentication | Email confirmation, recovery request, authenticated password-change form |

The full image was rechecked in readable strips. The four missing pages
(P2P request list, payout review, safety/report/block and payment confirmation)
are now registered and linked from the existing flows. See
[Redesign Screen Audit](REDESIGN_SCREEN_AUDIT.md) for all 99 reference tiles,
including review states that share an existing form.

Core welcome/auth/home, activity, orders, profile, send/review/offer selection,
wallet, notifications, chat, tracking, deliverer work and payment-release pages
use the same updated visual foundation. Unknown routes display an unavailable
page rather than silently restarting onboarding.

## Behavior And Integration Boundaries

- Existing profile/address/support/order/message/history interactions continue
  using the legacy mobile API where available. Errors and empty histories are
  shown explicitly, without inserting sample shipments or earnings.
- Booking drafts retain address/service choices. Errand shopping spend is
  separate from the service fee. New financial form inputs use integer kobo.
- New API-backed forms use `FeatureGateway`, disabled by default. The mobile
  authentication and data contracts still require migration to Supabase/the new
  backend. `MOVETRAQ_EXTENDED_API_ENABLED` is an integration-development gate,
  not a production-readiness switch. Enabling it alone is insufficient.
- New quote/checkout, onboarding/documents, evidence/handover, preferences,
  ratings, return and dispute forms do not show successful submission unless
  their actual request succeeds. Private photo uploads reserve a signed URL and
  require backend confirmation. Evidence is capped at 1.5 MB; verification
  photos at 10 MB. PDF selection is not implemented on mobile.
- Payouts, payment-method management, P2P advertisement APIs, session management,
  account deletion, notification deletion and membership billing still need
  their operational integrations. Their UI does not fabricate records or
  confirmations. Ad lifecycle actions and payment-method tokenization remain
  release work, not completed backend features.
- Calling opens the real device dialer. In-app voice calling is explicitly
  unavailable. Native maps require provider configuration. No fixed ETA is
  presented as a live estimate.
- Location sharing is explicitly opted into on the active delivery page.
  Background lifecycle, push delivery, mobile realtime subscriptions and
  offline queues remain production work.
- Payment-release authorization is unavailable until real verification is
  integrated; entering arbitrary digits can no longer release funds.
- Analytics use existing released orders, not seeded statistics. Display and
  accessibility preference forms are not yet applied to the runtime theme.
- Admin verification, support and pricing screens share the updated mark,
  bundled fonts and palette. Missing operational admin modules listed in
  `PRODUCTION_IMPLEMENTATION.md` are not implemented by this mobile UI pass.

## Verification

Run `flutter analyze lib test` and `flutter test` from the workspace root.
The suite checks all 77 additional routes at 320/390 px with 1.3 text scaling,
core welcome/auth/home at 320/390/430 px, additional core screens on short
phones, the five-tab deliverer workspace, Errand stage validation, exact money
parsing, and truthful failure behavior for unavailable payouts/quotes.

Tests generate representative mobile screenshots in `build/ui-review/`.
Their account/order data is test-only. Native maps use the unconfigured state
in widget tests; these tests are not verification of live maps, payments,
GPS permissions, hosted backend services or iOS builds.

Admin: `npm run build` and `npm test` in `admin/`. Browser tests run on desktop
and mobile with mocked API fixtures, bundled-font checks and screenshots in
`admin/test-results/`.

See `PRODUCTION_IMPLEMENTATION.md` for the remaining release requirements.
