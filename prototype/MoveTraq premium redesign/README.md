# Movetraq delivery UI prototype

Run `./Start-Preview.ps1` from PowerShell in this folder, then open **http://localhost:4173/MoveTraq.dc.html**. Alternatively run `python -m http.server 4173 --bind 127.0.0.1`. Keep the server terminal open. No build or package installation is required. Existing runtime and font dependencies may require internet access.

## Account and welcome

The responsive welcome page has a compact, text-free charcoal logo, centered account actions, and a sliding introduction to the delivery services. Dots, swipe, keyboard navigation and automatic advancement are supported without visible play/pause controls. Reduced-motion preferences are respected. A brief logo splash appears at launch.

Sign in and signup have optional labeled fields, password visibility, and Google and Apple icons. Blank signup fields use sample account details. Social authentication is a UI placeholder. Signup opens an email confirmation screen before entering Home. Leave the code blank or enter the preview code **123456** to complete confirmation; no email is sent. Resend and change-email controls are included.

## Locations and delivery

Home displays **Current location**. Selecting it opens saved addresses, with add, edit, delete and select actions. Selecting an address updates the current location and returns Home.

Home search opens a location screen initialized with the current saved address. Selecting a destination leads to the P2P/Express choice. Location fields offer relevant local sample suggestions while typing and a pin button for map selection. `maps.js` renders an interactive illustrative map with zoom and selectable pins. It does not use live maps, geocoding, device GPS or location permissions. These interfaces are ready for future backend integration.

New Order uses a concise route, recipient and parcel form without repeated route or terms sections. Both Express and P2P have an order summary before payment. The summary carries the route, recipient, parcel, selected service/deliverer and full total. Insufficient wallet balance displays a small dismissible alert with an Add money action, returning to checkout after demo top-up. Successful demo payment creates an order, receipt, notification and wallet transaction when applicable. Duplicate payment taps are guarded.

Scheduling, errands, big moves, receive/tracking, courier contact, chat, parcel photo and rating screens remain connected to the existing flows.

## Profile, settings and notifications

Profile has account details, verification status, delivery/address counts, current address, personal details, wallet, saved addresses, support and sender/deliverer controls. The logo is removed from Profile.

Settings groups security/PIN, devices and sessions, notification preferences, delivery preferences, accessibility/display, privacy, account controls and app information. Larger text and animation preferences affect the preview.

Delivery opportunities opens the application and screening flow. Every field, document and safety requirement is optional: an empty application can be reviewed and submitted to enter the deliverer dashboard immediately. Profile ? Delivery verification opens an optional identity, transport and safety preview, with a skip-to-dashboard button. Transport options include motorcycle, bicycle, trekking / walking, car, van, other motor vehicles and other non-motor transport. Motor vehicles show licence, registration and insurance previews; bicycle and walking options show relevant safety declarations instead. No real identity, document or background checks run.

Notifications support individual dismissal, mark all read, clear all, an empty state and undo clearing. Clearing inbox messages does not remove orders.

## Scope and assets

Orders, local transactions, balances, conversations, addresses, preferences, evidence and support records are saved on this browser. Authentication inputs and payment credentials are not persisted. Some transient forms and notifications remain in memory. Authentication, OTP, payments, delivery activity and messages are demonstrations; no backend operations occur.

`assets/movetraq-mark.svg` is the compact vector interpretation of the supplied smiling-box logo without its wordmark. The original image is preserved in `assets/movetraq-brand.png`. Google and Apple button icons are local SVG assets.

## Verification

Run:

- `node verify.cjs` for screen construction, navigation, account/OTP, addresses, booking, payment, profile, notifications and validation checks.
- `node verify-maps.cjs` for local map pin placement, zoom and absence of live location/geocoding requests.

Browser checks also exercised signup to OTP to Home, saved-address selection, location suggestions and the map picker through the localhost preview.

Application checklist reference: [Uber courier screening overview](https://www.uber.com/us/en/ride/safety/driver-screening/). This prototype is not a jurisdiction-specific compliance checklist.

Settings includes Delete account with a typed DELETE confirmation and cancel action. Confirmation resets the local session and returns to Welcome; it does not delete server data.

Profile shows the demo Gold membership and links to payment management. Saved card and bank previews support add/edit/remove/default selection, with confirmation before removal. Checkout supports wallet balance checks, card verification (preview code 123456), bank-transfer simulation, failure/retry and a receipt with method/reference. Only labels, sample last-four digits and card expiry are collected; no actual payment credentials or transactions are involved.

## Deliverer profile and settings

Profile includes a Deliverer mode switch that opens the sender or deliverer dashboard. Deliverer Profile shows availability, transport, delivery area, optional verification, earnings and payouts, trip history, and safety support. Work settings save transport and area selections for the session and include job, pickup, payout and safety alert preferences. Online/offline controls share the dashboard availability state. Sender Profile retains wallet, saved addresses and membership details.

## Deliverer analytics and contact tools

Jobs and Profile link to analytics and delivery contacts. Analytics has Today, 7-day and 30-day sample earnings, trip totals, averages and a daily chart. Quality metrics are explicitly sample data. Job details link to sender/recipient contact options; active-trip chat and call actions select the sender at pickup and recipient at drop-off. Each contact has a separate session-only chat with quick updates and a message composer. Call previews include start, mute, speaker and end controls. No messages are transmitted and no real calls are placed.

Deliverer navigation now includes Jobs, Orders, Analytics, Messages and Profile. Orders supports search, status filters, acceptance, pickup confirmation and confirmed handover. Job cards open the matching order. Contact names and conversations are scoped to each order; Messages offers an order selector. Analytics separately summarizes active/completed orders and completed earnings from this session.

Jobs displays active deliveries with their next pickup/drop-off step and explicit Open delivery and Message customer buttons. Accepted jobs leave the available list. Messages is an order inbox with Pending/All filters, conversation previews, read status and order links. Accepting a job creates a clearly simulated pickup message for demonstrating the inbox; completed conversations remain under All.

Each deliverer order now exposes one customer contact: the person who placed the order. Order details, the inbox, chat and calls use the same customer throughout pickup and drop-off.

## Guided deliveries and P2P ads

Accepting an order opens a dedicated pickup screen, followed by drop-off, handover confirmation and a completion receipt. Open delivery resumes the current stage. Jobs includes P2P ad management with sample defaults, editing, preview, publish and pause. Sender Home has P2P offers: choosing a live ad carries its route and quoted price into the booking flow. Ads and deliveries remain session-only preview data.

Choose a deliverer now supports name/vehicle search and a filter panel for rate, distance, vehicle and verification. Matching uses a 1.2-second loading preview and excludes offline peers. Empty results suggest Express while preserving route fields. The filter panel includes a preview scenario for no available peers. Availability remains sample data, not live dispatch.

Matching filters now use a modal bottom sheet with draft choices, preset chips, reset and apply controls. Sample peer coverage is checked against the pickup area (Ikeja, Lekki/Admiralty, Victoria Island, Yaba, Surulere or Maryland depending on the peer). Unsupported addresses show an Express route summary and preserve both addresses. This is a local area-name check, not live geocoding or dispatch coverage.

## Navigation and safety

Deliveries combines available jobs and active work, with all-order history linked from the same screen. P2P now has its own navigation tab. Block or report actions are available on delivery stages, conversations, calls, sender deliverer views and P2P offer cards. Blocks require confirmation, hide future matches/jobs and stop contact actions; existing orders remain accessible. Settings lists blocked people with unblock actions. Reports require a reason and are stored locally only; no moderation service receives them.

Orders and payment receipts include tracking and sharing actions. Tracking shows booking-specific status and delivery stages. Share links contain only the order reference and status snapshot in the URL fragment, and open directly into tracking. Native share and clipboard controls have a manual-copy fallback. Links require a publicly accessible deployment for other devices; live tracking requires a backend.

## Sender P2P requests and transactions

Sender Home ? P2P delivery supports posting a parcel request with route, offer, schedule and notes. Review and demo payment publish it to the deliverer P2P tab. Acceptance, pickup and completion update the sender booking; pre-acceptance cancellation refunds the demo payment. Transaction history is available from Profile, Wallet, Earnings, Orders, receipts and tracking. It records session payments, top-ups, refunds, withdrawals and delivery earnings, with per-order filtering. These records and the request lifecycle are local UI simulations and reset on refresh.

Sender P2P posting is now free. Ads can be created repeatedly, edited, paused, resumed or deleted before acceptance. Acceptance moves the request to Awaiting payment; payment updates the same request and unlocks pickup, without duplicate bookings. Explore P2P ads opens the shared choose-deliverer matching screen, including published deliverer ads that cover the pickup. This supersedes the earlier pay-to-post flow.


## Errands and big moves

Errand and Big move now have separate four-step booking flows: Details, Route, Schedule and Review. Drafts persist separately during the session. Errands support shopping, pickup/drop-off and other tasks, instructions, a shopping spending limit and soonest or scheduled collection. Big moves collect load type, item descriptions, vehicle size, loading helpers, access at both ends and a scheduled time. Contact and future-schedule validation run before review.

Review shows the route, service details and an explicit demo estimate before using the existing payment flow. Shopping budgets are not charged as part of the errand fee. Moving estimates use vehicle/helper selections; distance and access pricing require a live quoting service. Service details are retained with the booking. No live dispatch or purchases occur.


Deliverer Profile now links to My performance and Past customers. Performance separates session completion/customer counts from explicitly labeled sample acceptance, punctuality and rating metrics. Past customers groups completed deliveries by sender ID where present (otherwise the demo sender name), supports search and links to each completed order and its conversation. Completed deliveries record a timestamp. This history remains session-only.


## Deliverer location map

Accepted pickup/drop-off screens now provide an opt-in Track my location control in `delivery-map.js`. Unlike the illustrative sender maps, this feature uses browser geolocation and an OpenStreetMap embed centered on the device position, refreshed at most every ten seconds. Coordinates are sent to OpenStreetMap to display the map; they are not stored in orders or sent to a MoveTraq backend. Leaving the map, changing delivery stage, completing the delivery or pressing Stop tracking clears the watcher. HTTPS (or localhost), network access and browser location permission are required. Navigate to pickup/drop-off opens Google Maps for the active destination. Background tracking and live sharing with senders are not implemented. Run `node verify-delivery-map.cjs` for mocked geolocation lifecycle checks.

After offer acceptance, the pickup screen offers Go to pickup and Reject order. Go to pickup reveals a Google Maps destination embed plus existing location tracking and navigation. Pickup progress is saved per order during the session. Rejection before collection returns the order to Available and its sender booking to Awaiting courier; existing funding is retained for reassignment. Rejection is unavailable after collection. Destination maps require network access.


## Delivery completion and sender Activity

Pickup now uses **Item collected**. Reject order is available on the accepted-offer screen, and is removed once Go to pickup has been selected.

The completion receipt includes the item, route, customer, completion time and payout. P2P deliveries remain pending until the sender confirms receipt, with message/call actions available while awaiting confirmation. The sender can confirm from Activity, order details or tracking. Confirmation releases the held payment once, without charging the sender again. Express completion credits the session balance immediately. New paid bookings are linked to the deliverer order list with their service type.

Sender Activity shows active deliveries, payment/confirmation actions, delivery events and transaction updates, with All / Deliveries / Payments filters and direct tracking/transaction links. Totals are derived from session data. All payments and calls remain local prototype behavior. `delivery-experience.css` contains the new Activity and completion layouts. Run `node verify.cjs` and `node verify-delivery-map.cjs` to check the flows.


## Delivery evidence, recovery and saved progress

- Handover requires a recipient name and either the recipient code or a JPG/PNG/WebP photo (up to 1.5 MB). Sender tracking shows the code and recorded evidence. For this local design, the code is the last four digits of the order reference; production needs a server-generated, one-time code. Completion and Express credit are blocked until evidence is recorded.
- Every delivery has a report-problem flow for unreachable recipients, incorrect addresses, damage, failed deliveries and returns. A recorded issue blocks completion until resolved. Agreed returns have Returning to sender and Returned to sender states; returns do not receive completion earnings.
- Pending P2P payouts link to a payment-review request with notes and a saved status, also visible under Help & support. Sender confirmation resolves the review and releases payment once. Unresolved delivery problems prevent release. Support records are local; no support team receives these requests and no automatic payout deadline is promised.
- Earnings now shows the shared available balance, pending P2P earnings and total deliverer withdrawals, calculated from records rather than static amounts. The account balance is shared across sender/deliverer roles in this prototype.
- Versioned local browser storage preserves delivery progress, conversations, transactions, proof, issues, reviews and preferences across refreshes. Passwords, OTP inputs and bank/card form fields are excluded. Photos stay on this device. Storage failures show a recovery notice; clearing browser storage removes saved progress. This supersedes earlier descriptions of these records as session-only.
- Offline chat attempts remain visible as Not sent with an explicit Retry action. Retrying updates the same message without duplication. Maps include offline/error recovery, Retry map and a Map not loading? action because embedded third-party errors cannot always be detected automatically.

Verification: `node verify.cjs`, `node verify-delivery-map.cjs`, and `node verify-maps.cjs`. The flow checks cover invalid proof, duplicate completion, unresolved issues, returned items, payment review and release, offline message retries, storage restoration and storage failures. Accounts, payments, chat transmission, support handling and dispatch still require production backend services.


## Refresh behavior

The UI starts from the splash and welcome screens on every refresh. All interactions remain in memory and reset on reload. Browser progress saving and restoration have been removed; this supersedes the saved-progress descriptions above. Existing browser storage is ignored.
