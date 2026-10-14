# Delivery And Driver Screen Audit

Reviewed against the official redesign: available jobs, job details, driver
workspace, pickup, active map, drop-off, handover, completion, order history,
contact/chat, earnings, analytics, performance, customers, verification and support.

## Corrected Workflows

- Driver summaries no longer show sender receipt-confirmation or release actions.
  Assigned drivers can resume the correct pickup/drop-off stage and see their payout.
- Sender summaries retain receipt confirmation and do not offer driver payout review.
- Driver history opens pickup for accepted orders and drop-off for in-transit
  orders. Historical/awaiting-confirmation records still open the summary.
- Pickup and drop-off controls require assignment to the signed-in account and
  the corresponding order state. Completed/cancelled orders cannot open handover
  through an enabled delivery-stage action.
- Direct handover routes also require an assigned in-transit delivery. The
  backend remains responsible for evidence, code and transition authorization.
- Active maps offer only the relevant delivery stage. Location-sharing controls
  require an assigned active delivery.
- Job details distinguish loading from missing/error states and disable
  acceptance for sender accounts, own orders and non-open jobs.
- Job cards show the driver's payout, not the sender's total charge.
- Pickup, drop-off, driver summaries and active maps share the compact progress
  indicator from the design. The explicit driver-home route opens the five-tab shell.
- Analytics limit earnings to the selected local-date window, excluding future
  records, and no longer contain a duplicate loading branch.
- Unavailable maps show a customer-facing message. SDK configuration diagnostics
  remain available only in debug builds.

## Verification

`flutter analyze --no-pub lib test` and `flutter test --no-pub test/redesign_test.dart`.
Widget checks include role separation, accepted/in-transit/delivered/released/
cancelled stage actions, navigation from driver order history, handover failure
behavior, five-tab navigation and larger text on 320/390 px phones.
Screenshots: `build/ui-review/driver-*.png`.

## Remaining Integration Work

Mobile still uses legacy order models/API contracts. Handover, private evidence
and other new contracts remain gated until authentication/API migration. Tests
use test-only fixtures and unconfigured map states. They do not verify live
maps, GPS permissions/background lifecycle, provider payments, push delivery,
hosted Supabase or iOS builds. The screen audit does not establish production readiness.
