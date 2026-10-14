# Official Redesign Screen Audit

Reference: `C:/Users/dell/Downloads/Official MoveTraq Redesign.png`.
Reviewed the original 2000 x 26752 image in nine readable strips. The sheet has
99 populated screen tiles across 26 rows; blank cells are marked below.
Rows and columns refer to the supplied image, from top to bottom and left to right.
Text inside the reference is design content, not implementation instructions.

The mapping records native Flutter page coverage. A state within an existing
flow is not duplicated as a second form. It does not certify pixel-perfect
matching or live provider integration.

| Row | Column 1 | Column 2 | Column 3 | Column 4 |
| --- | --- | --- | --- | --- |
| 1 | Welcome: `/onboarding` | Blank | Sign in: `/signin` | Signup: `/create-account` |
| 2 | Home: `/home` | Live map: `/live-tracking` | Active deliveries: `/tracking` | Tracking timeline: `/order-detail` |
| 3 | Book delivery: `/send` | Request success: `/send-done` | Activity: Home tab | Orders: Home tab |
| 4 | Notifications: `/notifications` | Blank | Profile: Home tab | Deliverer profile: `/deliverer-public-profile` |
| 5 | Release payment: `/release-payment` | Authorize release: `/release-otp` | Release success: `/release-success` | Available deliveries: `/deliverer-home` |
| 6 | Job detail: `/deliverer-job` | Active pickup map: `/deliverer-active` | My trips: `/deliverer-orders` | Choose deliverer: `/pick-deliverer` |
| 7 | Review delivery: `/confirm-order` | Negotiate: `/negotiate` | Wallet: `/wallet` | Add money: `/topup` |
| 8 | Handover: `/handover` | Summary: `/delivery-completed` | Delivery problem: `/delivery-problem` | Delivery support: `/support-case` |
| 9 | Payout review: `/payout-review` (added) | Help: `/support` | Withdraw: `/withdraw` | Transactions: `/transactions` |
| 10 | Share: `/share-order` | Order confirmed: `/send-done`, `/order-receipt` | Order details: `/order-detail` | Work preferences: `/deliverer-work-settings` |
| 11 | Become a deliverer: `/delivery-opportunities`, `/deliverer-apply` | Performance: `/performance` | Past customers: `/past-customers` | Analytics: `/analytics` |
| 12 | Conversations: `/messages` | Earnings: `/deliverer-earnings` | Safety: `/safety` | Payment methods: `/payment-methods` |
| 13 | Opportunities: `/delivery-opportunities` | P2P requests: `/p2p-requests` (added) | Receive: `/receive` | Schedule: `/schedule` |
| 14 | Errand: `/errand` | Big move: `/big-move` | Settings: `/settings` | My delivery offers: `/delivery-work`, `/my-p2p-ads` |
| 15 | Rating: `/rate-delivery` | Confirm receipt: `/release-payment` | Create request: `/p2p-request` | Review request: final `/p2p-request` step |
| 16 | Payment: `/payment` | Track: `/order-detail`, `/live-tracking` | Safety/report/block: `/safety-reporting` (added) | Create offer: `/create-p2p-ad` |
| 17 | Preview offer: review state of `/create-p2p-ad` | Manage orders: `/deliverer-orders` | Map pin: `/map-picker` | Add address: `/address-edit` |
| 18 | Confirm email: `/verify-email` | Forgot password: `/password-recovery` | Completion: `/delivery-completed` | Review application: final `/deliverer-apply` step |
| 19 | Express review: `/confirm-order` in Express mode | Add payment method: `/add-payment-method` | Confirm payment: `/confirm-payment` (added) | Destination: `/location-search` |
| 20 | Service choice: `/service-choice` | Application: `/deliverer-apply` | Security: `/security` | Sessions: `/sessions` |
| 21 | Blocked people: `/blocked-users` | Notification preferences: `/notification-preferences` | Delivery preferences: `/delivery-preferences` | Display: `/display-preferences` |
| 22 | Privacy: `/privacy` | Account controls: `/account-controls` | Delete: `/delete-account` | About: `/about` |
| 23 | P2P offers: `/p2p-ads` | Customer deliveries: `/customer-deliveries` | Report issue: `/report-issue` | Application status: `/application-status` |
| 24 | Delivery details: `/delivery-summary` | Pickup: `/delivery-pickup` | Drop-off: `/delivery-dropoff` | Chat: `/chat` |
| 25 | Call: `/call` | Personal details: `/personal-details` | Addresses: `/saved-addresses` | Contact courier: `/delivery-contact` |
| 26 | Parcel photo: `/parcel-photo` | Blank | Blank | Blank |

## Added Navigation

- Home P2P action opens the request list. Its add button opens the existing
  booking flow, its marketplace entry opens P2P offers, and real order rows
  open order details.
- Wallet links to payment confirmation. Confirmation checks an owned provider
  reference with the backend; it never treats typed OTP digits as payment proof.
- Delivery tools link to payout review and safety reporting. Contact and chat
  menus open the same combined report/block page.
- Request and Express review titles now identify the flow. Ad review is titled
  Preview your offer and has Publish/Update actions plus an editable offer title.

## Integration Boundaries

Payout reviews and safety concerns submit actual support requests through the
existing mobile service, with order/contact references included. They do not
change payouts or resolve disputes. Dedicated moderation records and migration
to the new support API remain production work.

Blocking and provider verification use the existing gated production gateway.
They show errors while the mobile API migration is unavailable. Payment-method
setup retains its explicit unavailable-provider state instead of collecting
card credentials locally. Existing profile/payment/session/ads pages may be
present visually while their provider or backend integration remains unfinished.

Flutter tests cover all 77 additional routes at 320/390 px with larger text,
new page interactions and representative screenshot output in `build/ui-review/`.
See `PRODUCTION_IMPLEMENTATION.md` for the broader production gaps.
