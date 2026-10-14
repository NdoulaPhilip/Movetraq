import {readFile,writeFile} from 'node:fs/promises';
const path=new URL('../docs/FEATURE_PARITY.md',import.meta.url);
const groups=[
 ['onboard emailOtp forgot',['Native auth/welcome; visual parity pending','Supabase Auth','auth.users/profiles','Auth events','Verified sessions','Not run','User listing']],
 ['addressEdit addresses locations mapPicker',['Native CRUD/search/map; parity pending','Addresses/maps','addresses','Not required','Owner scoped','Not run','Not implemented']],
 ['applicationForm applicationReview delivererApply',['Native application; review partial','Deliverer application/uploads','deliverers/verification_applications/documents','Notification events','Owner/reviewer roles','Not run','Verification review']],
 ['chat',['Native chat/photos/history/retry/receipts; parity pending','Conversations/messages/private uploads','messages/conversation_members/uploads','Messages + receipt subscription','Membership RLS/upload ownership','Not run','Order chat metadata']],
 ['senderP2p senderP2pForm senderP2pReview errand move create send schedule confirmOrder deliveryChoice',['Native creation/review; parity pending','Quotes/orders','quotes/orders','Order subscription','Owner + server pricing','Not run','Order inspection']],
 ['payment expressPayment topup paymentAuthorize paymentReview',['Native checkout/verify; parity pending','Payments/wallet funding','payments/journals/escrows','Backend events','Signature + server verification','Not run','Order payment metadata']],
 ['wallet transactions',['Native balances/history; parity pending','Wallet/transactions','ledger_entries/accounts/journals','Manual refresh','Owner scoped','Not run','Partial']],
 ['order orders senderOrderDetail orderTracking live trackList receive deliveryProof completion confirmReceipt release',['Native tracking/evidence/transitions; parity pending','Orders/evidence/location','orders/order_events/evidence/locations','Subscribed','Participant/actor/state guards','Not run','Order inspection']],
 ['deliveryIssue deliveryIssueStatus support ticket',['Native support cases/photo attachments; parity pending','Support/returns','support_cases/order_returns','Backend notification events','Participant/staff roles','Not run','Case controls/return decisions']],
 ['notifs',['Native inbox; parity pending','Notifications','notifications/push_devices/outbox','Subscribed + provider push','Owner scoped','Not run','Partial']],
 ['personal settings security sessions preferences',['Native personal editing/settings/PIN/sessions; parity pending','Users/preferences/security/sessions','profiles/user_preferences/security_settings/auth.sessions','Not required','Owner scoped','Not run','User status controls']],
 ['deleteAccount',['Native request; erasure incomplete','Account deletion','account_deletions/profiles','Worker','Owner + financial guards','Not run','Audit records']],
 ['deliverer dHome dOrders dTrips dEarnings roles',['Native jobs/availability/history; parity pending','Deliverer/matching/payouts','deliverers/orders/accounts','Outbox job alerts','Verified eligibility','Not run','Deliverer listing']],
 ['p2pAds p2pBrowse p2pEdit p2pPreview',['Native CRUD/preview/browse/request; parity pending','Ads/quotes/preferred matching','p2p_ads/quotes/orders','Order offers subscribed; ad refresh','Approved owner/block/coverage checks','Not run','Order inspection']],
 ['blockedPeople safetyActions',['Native block/unblock/order reports; parity pending','Blocks/reports/moderation','blocked_users/user_reports','Not required','Owner/participant/block matching checks','Not run','Safety report decisions']],
 ['rating',['Native completed-order ratings; parity pending','Ratings','ratings','Not required','Completed participant/unique retry','Not run','Performance aggregation']],
 ['negotiate pickDeliverer',['Native counter/agreement/selection; parity pending','Offers/counter/agreement/select','delivery_offers/offer_history/ledger','Offer subscription','Participant/eligible deliverer/funding checks','Not run','Order inspection']],
 ['dPerformance dAnalytics',['Native performance/analytics; parity pending','Deliverer insights','orders/ratings/ledger','On-demand refresh','Owner scoped','Not run','Partial']],
 ['dCustomers dCustomerHistory',['Native past customers/history; parity pending','Deliverer customers/order history','orders/profiles','On-demand refresh','Prior delivery relationship','Not run','Partial']],
 ['withdraw',['Native bank verification/withdrawals/history; parity pending','Payout destinations/request/approval','payouts/payout_destinations/ledger','Outbox/provider worker','Owner/PIN/finance roles','Not run','Approval controls']],
];
const mappings=new Map();for(const [routes,values] of groups)for(const route of routes.split(' '))mappings.set(route,values);
for(const route of ['support','ticket','deliveryIssueStatus'])mappings.set(route,['Native cases/public replies/photo attachments; parity pending','Support tickets/details/replies/attachments','support_cases/support_notes/support_attachments/event_outbox','Backend notification event','Reporter ownership/private staff notes','Not run','Case assignment/priority/public replies/internal notes/attachments']);
for(const route of ['accessibility','preferences'])mappings.set(route,['Native saved motion/larger-text preferences; parity pending','User preferences','user_preferences','Not required','Owner scoped','Not run','Not required']);
const original=await readFile(path,'utf8');
const updated=original.replace(/^\| ([A-Za-z][A-Za-z0-9]*) \|.*$/gm,(line,route)=>mappings.has(route)?`| ${route} | ${mappings.get(route).join(' | ')} |`:line);
await writeFile(path,updated);
