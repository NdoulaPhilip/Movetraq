# Map Screen Audit

Scope: destination pin selection, service preview maps, order-summary maps,
pickup/drop-off maps, driver active map, and sender live tracking. Preserve the
existing MoveTraq design and native Google Maps implementation, not a WebView.

## Corrections

- Live maps clear courier markers when a location disappears, is invalid, or
  is marked simulated, including during marker animation. Simulated trails are
  not displayed as GPS history.
- Shared coordinate validation rejects nonfinite and out-of-range coordinates.
  Shared bounds support single/coincident pins and date-line crossings.
- Preview maps fit their locations when created or updated instead of keeping
  a fixed midpoint zoom. Controllers are disposed with their widgets.
- Embedded driver maps no longer reserve space for a nonexistent bottom sheet.
- Sender tracking reserves camera space for the actual sheet extent and header.
  Map-error content also occupies the visible area, keeping retry accessible.
  Compact error states and hidden toolbars avoid collisions at maximum extent.
- Live maps have fit, follow-toggle and zoom controls with tooltips. Controls
  are disabled without a map controller or an applicable courier location.
- Pickup/drop-off markers are visually distinct. Straight location connectors
  are dashed; supplied GPS history remains solid. Connectors are not road routes.
- Missing/null configuration and native bridge errors fail closed to an explicit
  unavailable state. Noncompact views can retry configuration. Diagnostics remain
  debug-only.
- The destination picker retains an existing destination, supports tap selection
  and draggable pins, and disables confirmation while GPS is locating.
- Tracking distinguishes loading, unavailable orders and stream errors, reloads
  its subscription when the order changes, hides simulated/invalid coordinates,
  and restricts the receipt-confirmation link to the sender.

## Verification

Commands: `flutter analyze --no-pub lib test` and `flutter test --no-pub`.

Map regression tests cover bounds, invalid coordinates, stale marker removal
during animation, simulated locations, padding, unavailable controls, line styles,
bridge failure and retries. Screen tests cover pin taps/dragging/retention and
sheet resizing through maximum extent at 320/390 px with 1.3 text scaling.
The suite also checks the existing delivery/driver screens and all additional
routes. Screenshots: `build/ui-review/map-picker.png` and `live-tracking.png`.

Tests intentionally use test-only data and an unconfigured native map bridge.
They verify widget behavior and unavailable layouts, not map tiles, actual native
camera movement, provider responses, GPS permissions or background execution.

## Integration Gaps

- Backend `MapService` currently returns route distance and duration only.
  Provider road geometry and mobile ETA/route consumption are not connected.
- Mobile still uses legacy order/tracking API contracts. This audit does not
  establish authenticated production realtime tracking or backend authorization.
- The Android configuration bridge exists. There is no iOS project/configuration
  in this checkout; iOS native map initialization and the configuration bridge
  still require implementation and device verification.
- Verify configured Maps SDK keys/restrictions, physical-device map tiles,
  camera framing, permission denial/recovery, battery-conscious tracking and
  subscription lifecycle before treating maps as production-ready.
- Pin selection currently passes coordinates as the destination label. A real
  address/recipient-access workflow and provider-backed reverse geocoding remain
  necessary where a human-readable destination is required.

No external provider result is simulated as successful.
