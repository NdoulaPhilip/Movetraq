begin;
insert into business_config(key,value) values
('enabled_services','["p2p","express","errand","big_move"]'),
('feature_flags','{"voice_calls":false,"memberships":false,"saved_payment_methods":false}'),
('cancellation','{"allow_before_pickup":true}'),
('support_categories','[{"code":"recipient_unreachable","label":"Recipient unreachable"},{"code":"incorrect_address","label":"Incorrect address"},{"code":"damaged_parcel","label":"Damaged parcel"},{"code":"failed_delivery","label":"Failed delivery"},{"code":"return","label":"Return"},{"code":"payment_issue","label":"Payment issue"},{"code":"deliverer_issue","label":"Deliverer issue"},{"code":"sender_issue","label":"Sender issue"},{"code":"other","label":"Other"}]'),
('notification_templates','{}'),('delivery_areas','[]'),
('supported_transport_types','["motorcycle","bicycle","walking","car","van","other_motor","other_non_motor"]') on conflict(key) do nothing;
commit;
