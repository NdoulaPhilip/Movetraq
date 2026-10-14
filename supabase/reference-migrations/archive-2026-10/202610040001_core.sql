begin;
create extension if not exists pgcrypto;
create type order_status as enum ('draft','pending_payment','awaiting_deliverer','offer_received','deliverer_assigned','accepted','heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff','awaiting_confirmation','completed','cancelled','rejected','failed','return_requested','return_approved','returning','returned','disputed');
create type service_type as enum ('p2p','express','errand','big_move');
create type verification_status as enum ('not_started','submitted','under_review','approved','rejected','suspended');
create type escrow_status as enum ('created','funded','held','release_pending','released','refunded','disputed');

create table profiles (
 id uuid primary key references auth.users(id), display_name text not null default '', phone text,
 avatar_path text, status text not null default 'active' check(status in ('active','suspended','deletion_pending','deleted')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table user_roles(user_id uuid references profiles(id),role text check(role in ('customer','deliverer','super_admin','admin','support','verification_agent','finance','operations')),primary key(user_id,role));
create table user_preferences(user_id uuid primary key references profiles(id),preferences jsonb not null default '{}',notification_preferences jsonb not null default '{}',updated_at timestamptz not null default now());
create table blocked_users(user_id uuid references profiles(id),blocked_user_id uuid references profiles(id),created_at timestamptz not null default now(),primary key(user_id,blocked_user_id),check(user_id<>blocked_user_id));
create table addresses(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),label text not null,address text not null,latitude numeric(9,6) not null check(latitude between -90 and 90),longitude numeric(9,6) not null check(longitude between -180 and 180),place_id text,city text,state text,country text not null default 'NG',is_default boolean not null default false,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create unique index one_default_address on addresses(user_id) where is_default;
create index addresses_owner on addresses(user_id,created_at,id);
create table business_config(key text primary key,value jsonb not null,version integer not null default 1,updated_by uuid references profiles(id),updated_at timestamptz not null default now());
insert into business_config(key,value) values ('pricing','{"minimum_p2p_minor":200000,"platform_basis_points":1000,"express_base_minor":250000,"errand_base_minor":300000,"per_km_minor":10000,"helper_minor":150000,"access_minor":100000,"vehicle_base_minor":{"car":800000,"van":1500000,"truck":2500000}}');
create table quotes(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),service_type service_type not null,request jsonb not null,route jsonb not null,total_minor bigint not null check(total_minor>0),platform_minor bigint not null check(platform_minor>=0),deliverer_minor bigint not null check(deliverer_minor>=0),shopping_budget_minor bigint not null default 0 check(shopping_budget_minor>=0),currency text not null default 'NGN' check(currency='NGN'),pricing_version integer not null,expires_at timestamptz not null,created_at timestamptz not null default now(),check(total_minor=platform_minor+deliverer_minor));
create table orders(id uuid primary key default gen_random_uuid(),public_reference text unique not null default ('MT-'||upper(encode(gen_random_bytes(6),'hex'))),sender_id uuid not null references profiles(id),deliverer_id uuid references profiles(id),quote_id uuid unique not null references quotes(id),service_type service_type not null,status order_status not null default 'pending_payment',pickup jsonb not null,destination jsonb not null,recipient_name text not null,recipient_phone text not null,parcel_description text not null,instructions text not null default '',service_details jsonb not null default '{}',total_minor bigint not null check(total_minor>0),platform_minor bigint not null check(platform_minor>=0),deliverer_minor bigint not null check(deliverer_minor>=0),shopping_budget_minor bigint not null default 0 check(shopping_budget_minor>=0),currency text not null default 'NGN' check(currency='NGN'),payment_status text not null default 'unpaid' check(payment_status in ('unpaid','paid','refunded')),handover_hash text not null,handover_ciphertext text not null,scheduled_at timestamptz,timezone text not null default 'Africa/Lagos',accepted_at timestamptz,picked_up_at timestamptz,delivered_at timestamptz,completed_at timestamptz,cancelled_at timestamptz,cancellation_reason text,created_at timestamptz not null default now(),updated_at timestamptz not null default now(),check(sender_id is distinct from deliverer_id),check(total_minor=platform_minor+deliverer_minor));
create index orders_sender on orders(sender_id,created_at desc,id);
create index orders_deliverer on orders(deliverer_id,created_at desc,id);
create index orders_dispatch on orders(status,scheduled_at) where status='awaiting_deliverer';
create table order_events(id uuid primary key default gen_random_uuid(),order_id uuid not null references orders(id),actor_id uuid references profiles(id),from_status order_status,to_status order_status not null,metadata jsonb not null default '{}',created_at timestamptz not null default now());
create index events_order on order_events(order_id,created_at);
create table deliverers(user_id uuid primary key references profiles(id),verification_status verification_status not null default 'not_started',transport text not null check(transport in ('motorcycle','bicycle','walking','car','van','other_motor','other_non_motor')),available boolean not null default false,service_preferences service_type[] not null default '{p2p,express,errand}',area_center_lat numeric(9,6),area_center_lng numeric(9,6),area_radius_metres integer not null default 10000 check(area_radius_metres between 100 and 100000),capacity_kg integer not null default 10 check(capacity_kg>0),max_active_jobs integer not null default 1 check(max_active_jobs between 1 and 10),last_lat numeric(9,6),last_lng numeric(9,6),last_location_at timestamptz,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table verification_applications(id uuid primary key default gen_random_uuid(),user_id uuid not null references deliverers(user_id),status verification_status not null default 'submitted',identity jsonb not null,safety_declarations jsonb not null,reviewed_by uuid references profiles(id),review_notes text,submitted_at timestamptz not null default now(),reviewed_at timestamptz);
create table uploads(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),order_id uuid references orders(id),bucket text not null,path text unique not null,mime_type text not null,size_bytes integer not null check(size_bytes>0),verified_at timestamptz,created_at timestamptz not null default now());
create table verification_documents(id uuid primary key default gen_random_uuid(),application_id uuid not null references verification_applications(id),upload_id uuid not null references uploads(id),document_type text not null);
create table delivery_offers(id uuid primary key default gen_random_uuid(),order_id uuid not null references orders(id),deliverer_id uuid not null references deliverers(user_id),amount_minor bigint not null check(amount_minor>0),status text not null default 'pending' check(status in ('pending','accepted','rejected','withdrawn')),created_at timestamptz not null default now(),unique(order_id,deliverer_id));
create table accounts(id uuid primary key default gen_random_uuid(),user_id uuid references profiles(id),order_id uuid references orders(id),kind text not null check(kind in ('wallet','escrow','provider_clearing','platform_revenue','payout_pending')),currency text not null default 'NGN' check(currency='NGN'),created_at timestamptz not null default now());
create unique index user_account_kind on accounts(user_id,kind,currency) where user_id is not null;
create unique index order_escrow_account on accounts(order_id,kind,currency) where order_id is not null;
create unique index system_account_kind on accounts(kind,currency) where user_id is null and order_id is null;
insert into accounts(kind) values ('provider_clearing'),('platform_revenue');
create table journals(id uuid primary key default gen_random_uuid(),idempotency_key text not null unique,kind text not null,order_id uuid references orders(id),actor_id uuid references profiles(id),created_at timestamptz not null default now());
create table ledger_entries(id uuid primary key default gen_random_uuid(),journal_id uuid not null references journals(id),account_id uuid not null references accounts(id),amount_minor bigint not null check(amount_minor<>0),created_at timestamptz not null default now(),unique(journal_id,account_id));
create index ledger_account on ledger_entries(account_id,created_at desc,id);
create table payments(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),order_id uuid references orders(id),reference text not null unique,amount_minor bigint not null check(amount_minor>0),currency text not null default 'NGN',purpose text not null check(purpose in ('order','topup')),status text not null default 'initialized' check(status in ('initialized','pending','succeeded','failed')),idempotency_key text not null,authorization_url text,verified_at timestamptz,created_at timestamptz not null default now(),unique(user_id,idempotency_key));
create unique index one_funded_payment_per_order on payments(order_id) where status='succeeded';
create table escrows(order_id uuid primary key references orders(id),account_id uuid unique not null references accounts(id),status escrow_status not null default 'created',funded_at timestamptz,released_at timestamptz,refunded_at timestamptz);
create table delivery_evidence(id uuid primary key default gen_random_uuid(),order_id uuid unique not null references orders(id),recipient_name text not null,code_verified boolean not null default false,upload_id uuid references uploads(id),submitted_by uuid not null references profiles(id),captured_at timestamptz not null default now(),check(code_verified or upload_id is not null));
create table support_cases(id uuid primary key default gen_random_uuid(),order_id uuid references orders(id),reporter_id uuid not null references profiles(id),category text not null,description text not null,status text not null default 'open' check(status in ('open','investigating','waiting_user','waiting_deliverer','resolved','closed')),priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),assigned_admin_id uuid references profiles(id),resolution text,created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create index unresolved_order_cases on support_cases(order_id) where status not in ('resolved','closed');
create table support_notes(id uuid primary key default gen_random_uuid(),case_id uuid not null references support_cases(id),author_id uuid not null references profiles(id),body text not null,internal boolean not null default true,created_at timestamptz not null default now());
create table conversations(id uuid primary key default gen_random_uuid(),order_id uuid unique not null references orders(id),created_at timestamptz not null default now());
create table conversation_members(conversation_id uuid references conversations(id),user_id uuid references profiles(id),last_read_at timestamptz,primary key(conversation_id,user_id));
create table messages(id uuid primary key default gen_random_uuid(),conversation_id uuid not null references conversations(id),sender_id uuid not null references profiles(id),client_message_id uuid not null,body text not null check(length(body) between 1 and 4000),upload_id uuid references uploads(id),created_at timestamptz not null default now(),unique(sender_id,client_message_id));
create index messages_history on messages(conversation_id,created_at desc,id);
create table notifications(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),event_id uuid,title text not null,body text not null,data jsonb not null default '{}',read_at timestamptz,created_at timestamptz not null default now(),unique(user_id,event_id));
create index notifications_inbox on notifications(user_id,created_at desc,id);
create table push_devices(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),token text unique not null,platform text not null check(platform in ('android','ios')),enabled boolean not null default true,updated_at timestamptz not null default now());
create table deliverer_locations(id uuid primary key default gen_random_uuid(),order_id uuid not null references orders(id),deliverer_id uuid not null references deliverers(user_id),latitude numeric(9,6) not null check(latitude between -90 and 90),longitude numeric(9,6) not null check(longitude between -180 and 180),accuracy_metres numeric not null check(accuracy_metres between 0 and 5000),captured_at timestamptz not null,created_at timestamptz not null default now());
create index locations_order on deliverer_locations(order_id,created_at desc);
create table ratings(id uuid primary key default gen_random_uuid(),order_id uuid not null references orders(id),reviewer_id uuid not null references profiles(id),reviewee_id uuid not null references profiles(id),score integer not null check(score between 1 and 5),review text,created_at timestamptz not null default now(),unique(order_id,reviewer_id),check(reviewer_id<>reviewee_id));
create table p2p_ads(id uuid primary key default gen_random_uuid(),deliverer_id uuid not null references deliverers(user_id),pickup_coverage jsonb not null,destination_coverage jsonb not null,price_minor bigint not null check(price_minor>0),availability jsonb not null,transport text not null,notes text,status text not null default 'active' check(status in ('active','paused','deleted')),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table user_reports(id uuid primary key default gen_random_uuid(),reporter_id uuid not null references profiles(id),reported_user_id uuid not null references profiles(id),order_id uuid references orders(id),reason text not null,status text not null default 'open',created_at timestamptz not null default now());
create table payout_destinations(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),provider_recipient text not null,bank_name text not null,account_last4 text not null check(length(account_last4)=4),created_at timestamptz not null default now());
create table payouts(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),destination_id uuid not null references payout_destinations(id),amount_minor bigint not null check(amount_minor>0),reference text unique not null,status text not null default 'pending' check(status in ('pending','approved','processing','completed','failed')),approved_by uuid references profiles(id),created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create table saved_payment_methods(id uuid primary key default gen_random_uuid(),user_id uuid not null references profiles(id),provider_authorization_ciphertext text not null,last4 text not null,brand text,expiry_month integer,expiry_year integer,is_default boolean not null default false,created_at timestamptz not null default now());
create table memberships(user_id uuid primary key references profiles(id),plan text not null,status text not null check(status in ('active','expired','cancelled')),expires_at timestamptz not null,provider_reference text);
create table account_deletions(id uuid primary key default gen_random_uuid(),user_id uuid unique not null references profiles(id),status text not null default 'requested',requested_at timestamptz not null default now(),completed_at timestamptz);
create table audit_logs(id uuid primary key default gen_random_uuid(),actor_id uuid references profiles(id),action text not null,entity text not null,entity_id uuid,previous_state jsonb,new_state jsonb,request_id text,created_at timestamptz not null default now());
create table event_outbox(id uuid primary key default gen_random_uuid(),event_type text not null,order_id uuid references orders(id),user_id uuid references profiles(id),payload jsonb not null default '{}',attempts integer not null default 0,available_at timestamptz not null default now(),processed_at timestamptz,last_error text,created_at timestamptz not null default now());
create index outbox_pending on event_outbox(available_at) where processed_at is null;
create table idempotency_records(user_id uuid references profiles(id),key text not null,operation text not null,request_hash text not null,response jsonb not null,created_at timestamptz not null default now(),primary key(user_id,key,operation));

create function reject_mutation() returns trigger language plpgsql set search_path=public as $$ begin raise exception 'Immutable record'; end $$;
create trigger immutable_entries before update or delete on ledger_entries for each row execute function reject_mutation();
create trigger immutable_journals before update or delete on journals for each row execute function reject_mutation();
create trigger immutable_audit before update or delete on audit_logs for each row execute function reject_mutation();
create function check_journal_balance() returns trigger language plpgsql set search_path=public as $$
begin
 if (select count(*)<2 or sum(amount_minor)<>0 from ledger_entries where journal_id=new.journal_id) then raise exception 'Unbalanced journal'; end if;
 return new;
end $$;
create constraint trigger balanced_journal after insert on ledger_entries deferrable initially deferred for each row execute function check_journal_balance();
create function create_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name',''));
 insert into user_roles values(new.id,'customer');
 insert into user_preferences(user_id) values(new.id);
 insert into accounts(user_id,kind) values(new.id,'wallet');
 return new;
end $$;
create trigger auth_profile after insert on auth.users for each row execute function create_profile();

-- Clients receive scoped read access only. Business mutations go through the API.
do $$ declare t record;begin for t in select tablename from pg_tables where schemaname='public' loop execute format('alter table public.%I enable row level security',t.tablename);execute format('revoke all on public.%I from anon, authenticated',t.tablename);end loop;end $$;
create function participates(p_order uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from orders where id=p_order and (sender_id=auth.uid() or deliverer_id=auth.uid())); $$;
create function conversation_member(p_conversation uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from conversation_members where conversation_id=p_conversation and user_id=auth.uid()); $$;
revoke all on function participates(uuid),conversation_member(uuid),create_profile(),reject_mutation(),check_journal_balance() from public;
grant execute on function participates(uuid),conversation_member(uuid) to authenticated;
grant select on profiles,user_roles,user_preferences,blocked_users,addresses,quotes,orders,order_events,deliverers,verification_applications,delivery_offers,accounts,journals,ledger_entries,payments,escrows,delivery_evidence,support_cases,conversations,conversation_members,messages,notifications,deliverer_locations,ratings,p2p_ads,payouts,memberships,account_deletions to authenticated;
-- Column grants prevent raw codes and recipient secrets leaking through direct API reads.
revoke select on orders from authenticated;
grant select(id,public_reference,sender_id,deliverer_id,service_type,status,pickup,destination,recipient_name,recipient_phone,parcel_description,instructions,service_details,total_minor,platform_minor,deliverer_minor,shopping_budget_minor,currency,payment_status,scheduled_at,timezone,accepted_at,picked_up_at,delivered_at,completed_at,created_at,updated_at) on orders to authenticated;
create policy own_profile on profiles for select to authenticated using(id=auth.uid());
create policy own_roles on user_roles for select to authenticated using(user_id=auth.uid());
create policy own_preferences on user_preferences for select to authenticated using(user_id=auth.uid());
create policy own_blocks on blocked_users for select to authenticated using(user_id=auth.uid());
create policy own_addresses on addresses for select to authenticated using(user_id=auth.uid());
create policy own_quotes on quotes for select to authenticated using(user_id=auth.uid());
create policy own_orders on orders for select to authenticated using(sender_id=auth.uid() or deliverer_id=auth.uid());
create policy own_order_events on order_events for select to authenticated using(participates(order_id));
create policy own_deliverer on deliverers for select to authenticated using(user_id=auth.uid());
create policy own_verification on verification_applications for select to authenticated using(user_id=auth.uid());
create policy own_offers on delivery_offers for select to authenticated using(deliverer_id=auth.uid() or participates(order_id));
create policy own_accounts on accounts for select to authenticated using(user_id=auth.uid());
create policy own_journals on journals for select to authenticated using(exists(select 1 from ledger_entries e join accounts a on a.id=e.account_id where e.journal_id=journals.id and a.user_id=auth.uid()));
create policy own_entries on ledger_entries for select to authenticated using(exists(select 1 from accounts a where a.id=account_id and a.user_id=auth.uid()));
create policy own_payments on payments for select to authenticated using(user_id=auth.uid());
create policy own_escrows on escrows for select to authenticated using(participates(order_id));
create policy own_evidence on delivery_evidence for select to authenticated using(participates(order_id));
create policy own_cases on support_cases for select to authenticated using(reporter_id=auth.uid() or participates(order_id));
create policy own_conversations on conversations for select to authenticated using(conversation_member(id));
create policy own_membership on conversation_members for select to authenticated using(user_id=auth.uid());
create policy own_messages on messages for select to authenticated using(conversation_member(conversation_id));
create policy own_notifications on notifications for select to authenticated using(user_id=auth.uid());
create policy own_locations on deliverer_locations for select to authenticated using(participates(order_id));
create policy own_ratings on ratings for select to authenticated using(reviewer_id=auth.uid() or reviewee_id=auth.uid());
create policy own_ads on p2p_ads for select to authenticated using(deliverer_id=auth.uid());
create policy own_payouts on payouts for select to authenticated using(user_id=auth.uid());
create policy own_membership_plan on memberships for select to authenticated using(user_id=auth.uid());
create policy own_deletion on account_deletions for select to authenticated using(user_id=auth.uid());

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
 ('avatars','avatars',false,1500000,array['image/jpeg','image/png','image/webp']),
 ('delivery-evidence','delivery-evidence',false,1500000,array['image/jpeg','image/png','image/webp']),
 ('verification-documents','verification-documents',false,10000000,array['image/jpeg','image/png','application/pdf']),
 ('parcel-images','parcel-images',false,1500000,array['image/jpeg','image/png','image/webp']),
 ('support-attachments','support-attachments',false,5000000,array['image/jpeg','image/png','image/webp','application/pdf']),
 ('chat-attachments','chat-attachments',false,1500000,array['image/jpeg','image/png','image/webp']);
-- Upload/read signing is API-authorized. No direct client writes to private buckets.
do $$ begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table orders,messages,notifications,deliverer_locations;end if;end $$;
commit;
