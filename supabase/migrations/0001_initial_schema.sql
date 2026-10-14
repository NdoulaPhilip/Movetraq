-- MoveTraq production foundation.
-- Apply with Supabase CLI or dashboard migrations. RLS is enabled from day one.

create extension if not exists "pgcrypto";
create extension if not exists "postgis";

create type public.user_role as enum (
  'sender',
  'deliverer',
  'support',
  'verification_agent',
  'finance',
  'operations',
  'admin',
  'super_admin'
);

create type public.service_type as enum ('p2p', 'express', 'errand', 'big_move');
create type public.transport_type as enum (
  'motorcycle',
  'bicycle',
  'walking',
  'car',
  'van',
  'other_motor',
  'other_non_motor'
);

create type public.order_status as enum (
  'draft',
  'pending_payment',
  'awaiting_deliverer',
  'offer_received',
  'deliverer_assigned',
  'accepted',
  'heading_to_pickup',
  'arrived_pickup',
  'picked_up',
  'heading_to_dropoff',
  'arrived_dropoff',
  'awaiting_confirmation',
  'completed',
  'cancelled',
  'rejected',
  'failed',
  'returning',
  'returned',
  'disputed'
);

create type public.payment_status as enum (
  'created',
  'initialized',
  'pending',
  'verified',
  'failed',
  'refunded',
  'cancelled'
);

create type public.escrow_status as enum (
  'created',
  'funded',
  'held',
  'release_pending',
  'released',
  'refunded',
  'disputed'
);

create type public.ledger_entry_type as enum (
  'wallet_credit',
  'wallet_debit',
  'topup',
  'refund',
  'delivery_payment',
  'escrow_hold',
  'escrow_release',
  'withdrawal',
  'adjustment'
);

create type public.verification_status as enum (
  'not_started',
  'submitted',
  'under_review',
  'approved',
  'rejected',
  'suspended'
);

create type public.support_status as enum (
  'open',
  'investigating',
  'waiting_user',
  'waiting_deliverer',
  'resolved',
  'closed'
);

create type public.payout_status as enum ('pending', 'approved', 'processing', 'completed', 'failed', 'cancelled');
create type public.ad_status as enum ('draft', 'published', 'paused', 'deleted');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  phone text,
  avatar_path text,
  membership_tier text not null default 'standard',
  verification_status public.verification_status not null default 'not_started',
  active_role public.user_role not null default 'sender',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  role public.user_role not null,
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  delivery_preferences jsonb not null default '{}'::jsonb,
  accessibility_preferences jsonb not null default '{}'::jsonb,
  display_preferences jsonb not null default '{}'::jsonb,
  privacy_preferences jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.notification_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  push_enabled boolean not null default true,
  email_enabled boolean not null default true,
  sms_enabled boolean not null default false,
  event_settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.security_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  pin_hash text,
  biometrics_enabled boolean not null default false,
  deleted_at timestamptz,
  anonymized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.blocked_users (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  reason text,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocked_users_not_self check (blocker_id <> blocked_id)
);

create table public.saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  label text not null,
  address text not null,
  latitude numeric(10,7),
  longitude numeric(10,7),
  place_id text,
  city text,
  state text,
  country text not null default 'NG',
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index saved_addresses_one_default
on public.saved_addresses(user_id)
where is_default;

create table public.deliverer_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  transport_type public.transport_type,
  availability_status text not null default 'offline',
  delivery_area jsonb not null default '{}'::jsonb,
  capacity jsonb not null default '{}'::jsonb,
  verification_status public.verification_status not null default 'not_started',
  active_job_count integer not null default 0 check (active_job_count >= 0),
  payout_profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  public_ref text not null unique,
  sender_id uuid not null references public.profiles(id),
  deliverer_id uuid references public.profiles(id),
  service_type public.service_type not null,
  status public.order_status not null default 'draft',
  pickup_address text not null,
  pickup_latitude numeric(10,7),
  pickup_longitude numeric(10,7),
  destination_address text not null,
  destination_latitude numeric(10,7),
  destination_longitude numeric(10,7),
  recipient_name text,
  recipient_phone text,
  parcel_info jsonb not null default '{}'::jsonb,
  service_details jsonb not null default '{}'::jsonb,
  pricing_breakdown jsonb not null default '{}'::jsonb,
  total_amount_minor integer not null default 0 check (total_amount_minor >= 0),
  platform_fee_minor integer not null default 0 check (platform_fee_minor >= 0),
  deliverer_payout_minor integer not null default 0 check (deliverer_payout_minor >= 0),
  currency char(3) not null default 'NGN',
  scheduled_at timestamptz,
  scheduled_timezone text,
  accepted_at timestamptz,
  pickup_at timestamptz,
  delivered_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text,
  payment_status public.payment_status not null default 'created',
  escrow_status public.escrow_status not null default 'created',
  evidence_required boolean not null default true,
  evidence_status text not null default 'missing',
  issue_status text not null default 'none',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index orders_sender_id_idx on public.orders(sender_id, created_at desc);
create index orders_deliverer_id_idx on public.orders(deliverer_id, created_at desc);
create index orders_status_idx on public.orders(status);
create index orders_service_type_idx on public.orders(service_type);

create table public.order_events (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  actor_id uuid references public.profiles(id),
  event_type text not null,
  previous_status public.order_status,
  new_status public.order_status,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles(id) on delete cascade,
  currency char(3) not null default 'NGN',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.wallet_ledger_entries (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallet_accounts(id),
  user_id uuid not null references public.profiles(id),
  order_id uuid references public.orders(id),
  type public.ledger_entry_type not null,
  amount_minor integer not null check (amount_minor <> 0),
  currency char(3) not null default 'NGN',
  idempotency_key text not null unique,
  provider_reference text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index wallet_ledger_user_created_idx on public.wallet_ledger_entries(user_id, created_at desc);
create index wallet_ledger_order_idx on public.wallet_ledger_entries(order_id);

create or replace view public.wallet_balances as
select
  wallet_id,
  user_id,
  currency,
  coalesce(sum(amount_minor), 0)::bigint as balance_minor
from public.wallet_ledger_entries
group by wallet_id, user_id, currency;

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  order_id uuid references public.orders(id),
  provider text not null,
  provider_reference text not null unique,
  status public.payment_status not null default 'created',
  amount_minor integer not null check (amount_minor > 0),
  currency char(3) not null default 'NGN',
  verified_at timestamptz,
  webhook_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.escrows (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  deliverer_id uuid references public.profiles(id),
  status public.escrow_status not null default 'created',
  amount_minor integer not null check (amount_minor >= 0),
  released_amount_minor integer not null default 0 check (released_amount_minor >= 0),
  idempotency_key text not null unique,
  funded_at timestamptz,
  released_at timestamptz,
  refunded_at timestamptz,
  disputed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  deliverer_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(order_id)
);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null,
  attachment_path text,
  client_message_id text,
  delivered_at timestamptz,
  read_at timestamptz,
  created_at timestamptz not null default now(),
  unique(conversation_id, client_message_id)
);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null,
  title text not null,
  body text not null,
  data jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.verification_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  status public.verification_status not null default 'submitted',
  identity_info jsonb not null default '{}'::jsonb,
  transport_info jsonb not null default '{}'::jsonb,
  safety_declarations jsonb not null default '{}'::jsonb,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.verification_documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.verification_applications(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  document_type text not null,
  storage_path text not null,
  mime_type text not null,
  size_bytes integer not null check (size_bytes > 0),
  created_at timestamptz not null default now()
);

create table public.delivery_evidence (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  recipient_name text not null,
  verification_code text,
  photo_path text,
  submitted_by uuid not null references public.profiles(id),
  captured_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint delivery_evidence_code_or_photo check (verification_code is not null or photo_path is not null)
);

create table public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.orders(id),
  reporter_id uuid not null references public.profiles(id),
  category text not null,
  description text not null,
  attachment_paths text[] not null default '{}',
  status public.support_status not null default 'open',
  priority text not null default 'normal',
  assigned_admin_id uuid references public.profiles(id),
  internal_notes text,
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.disputes (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id),
  opened_by uuid not null references public.profiles(id),
  status public.support_status not null default 'open',
  priority text not null default 'normal',
  assigned_admin_id uuid references public.profiles(id),
  resolution text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.payouts (
  id uuid primary key default gen_random_uuid(),
  deliverer_id uuid not null references public.profiles(id),
  amount_minor integer not null check (amount_minor > 0),
  currency char(3) not null default 'NGN',
  status public.payout_status not null default 'pending',
  provider_reference text,
  bank_summary jsonb not null default '{}'::jsonb,
  approved_by uuid references public.profiles(id),
  approved_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.p2p_ads (
  id uuid primary key default gen_random_uuid(),
  deliverer_id uuid not null references public.profiles(id) on delete cascade,
  pickup_coverage jsonb not null default '{}'::jsonb,
  destination_coverage jsonb not null default '{}'::jsonb,
  price_minor integer not null check (price_minor > 0),
  currency char(3) not null default 'NGN',
  availability jsonb not null default '{}'::jsonb,
  transport_type public.transport_type not null,
  notes text,
  status public.ad_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  reviewer_id uuid not null references public.profiles(id),
  reviewee_id uuid not null references public.profiles(id),
  rating integer not null check (rating between 1 and 5),
  review text,
  created_at timestamptz not null default now(),
  unique(order_id, reviewer_id, reviewee_id)
);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.profiles(id),
  action text not null,
  entity text not null,
  entity_id uuid,
  previous_state jsonb,
  new_state jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.user_roles
    where user_id = auth.uid()
      and role in ('support', 'verification_agent', 'finance', 'operations', 'admin', 'super_admin')
  );
$$;

create or replace function public.is_order_participant(order_row public.orders)
returns boolean
language sql
stable
as $$
  select auth.uid() = order_row.sender_id
      or auth.uid() = order_row.deliverer_id
      or public.is_admin();
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'profiles', 'user_roles', 'user_preferences', 'notification_preferences',
    'security_settings', 'blocked_users', 'saved_addresses',
    'deliverer_profiles', 'orders', 'order_events', 'wallet_accounts',
    'wallet_ledger_entries', 'payments', 'escrows', 'conversations',
    'messages', 'notifications', 'verification_applications',
    'verification_documents', 'delivery_evidence', 'support_tickets',
    'disputes', 'payouts', 'p2p_ads', 'ratings', 'audit_logs'
  ]
  loop
    execute format('alter table public.%I enable row level security', table_name);
  end loop;
end $$;

create policy profiles_self_or_admin on public.profiles
for all using (id = auth.uid() or public.is_admin())
with check (id = auth.uid() or public.is_admin());

create policy roles_self_read_admin_write on public.user_roles
for select using (user_id = auth.uid() or public.is_admin());

create policy roles_admin_write on public.user_roles
for all using (public.is_admin())
with check (public.is_admin());

create policy own_preferences on public.user_preferences
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy own_notification_preferences on public.notification_preferences
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy own_security_settings on public.security_settings
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy own_blocks on public.blocked_users
for all using (blocker_id = auth.uid() or public.is_admin())
with check (blocker_id = auth.uid() or public.is_admin());

create policy own_addresses on public.saved_addresses
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy own_deliverer_profile on public.deliverer_profiles
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy order_participants_read on public.orders
for select using (public.is_order_participant(orders));

create policy order_admin_write on public.orders
for all using (public.is_admin())
with check (public.is_admin());

create policy own_order_events on public.order_events
for select using (
  public.is_admin()
  or exists (
    select 1 from public.orders
    where orders.id = order_events.order_id
      and public.is_order_participant(orders)
  )
);

create policy own_wallet_account on public.wallet_accounts
for select using (user_id = auth.uid() or public.is_admin());

create policy own_wallet_ledger on public.wallet_ledger_entries
for select using (user_id = auth.uid() or public.is_admin());

create policy own_payments on public.payments
for select using (user_id = auth.uid() or public.is_admin());

create policy own_escrows on public.escrows
for select using (sender_id = auth.uid() or deliverer_id = auth.uid() or public.is_admin());

create policy own_conversations on public.conversations
for select using (sender_id = auth.uid() or deliverer_id = auth.uid() or public.is_admin());

create policy own_messages on public.messages
for select using (
  public.is_admin()
  or exists (
    select 1 from public.conversations
    where conversations.id = messages.conversation_id
      and (conversations.sender_id = auth.uid() or conversations.deliverer_id = auth.uid())
  )
);

create policy own_notifications on public.notifications
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy own_verification_applications on public.verification_applications
for all using (user_id = auth.uid() or public.is_admin())
with check (user_id = auth.uid() or public.is_admin());

create policy own_verification_documents on public.verification_documents
for select using (user_id = auth.uid() or public.is_admin());

create policy order_evidence_participants on public.delivery_evidence
for select using (
  public.is_admin()
  or exists (
    select 1 from public.orders
    where orders.id = delivery_evidence.order_id
      and public.is_order_participant(orders)
  )
);

create policy own_support_tickets on public.support_tickets
for all using (reporter_id = auth.uid() or assigned_admin_id = auth.uid() or public.is_admin())
with check (reporter_id = auth.uid() or public.is_admin());

create policy dispute_participants_admin on public.disputes
for select using (
  public.is_admin()
  or exists (
    select 1 from public.orders
    where orders.id = disputes.order_id
      and public.is_order_participant(orders)
  )
);

create policy deliverer_payouts on public.payouts
for select using (deliverer_id = auth.uid() or public.is_admin());

create policy p2p_ads_visible on public.p2p_ads
for select using (status = 'published' or deliverer_id = auth.uid() or public.is_admin());

create policy p2p_ads_owner_write on public.p2p_ads
for all using (deliverer_id = auth.uid() or public.is_admin())
with check (deliverer_id = auth.uid() or public.is_admin());

create policy order_ratings_visible on public.ratings
for select using (reviewer_id = auth.uid() or reviewee_id = auth.uid() or public.is_admin());

create policy audit_admin_read on public.audit_logs
for select using (public.is_admin());

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger user_preferences_updated_at before update on public.user_preferences
for each row execute function public.set_updated_at();
create trigger notification_preferences_updated_at before update on public.notification_preferences
for each row execute function public.set_updated_at();
create trigger security_settings_updated_at before update on public.security_settings
for each row execute function public.set_updated_at();
create trigger saved_addresses_updated_at before update on public.saved_addresses
for each row execute function public.set_updated_at();
create trigger deliverer_profiles_updated_at before update on public.deliverer_profiles
for each row execute function public.set_updated_at();
create trigger orders_updated_at before update on public.orders
for each row execute function public.set_updated_at();
create trigger wallet_accounts_updated_at before update on public.wallet_accounts
for each row execute function public.set_updated_at();
create trigger payments_updated_at before update on public.payments
for each row execute function public.set_updated_at();
create trigger escrows_updated_at before update on public.escrows
for each row execute function public.set_updated_at();
create trigger conversations_updated_at before update on public.conversations
for each row execute function public.set_updated_at();
create trigger verification_applications_updated_at before update on public.verification_applications
for each row execute function public.set_updated_at();
create trigger support_tickets_updated_at before update on public.support_tickets
for each row execute function public.set_updated_at();
create trigger disputes_updated_at before update on public.disputes
for each row execute function public.set_updated_at();
create trigger payouts_updated_at before update on public.payouts
for each row execute function public.set_updated_at();
create trigger p2p_ads_updated_at before update on public.p2p_ads
for each row execute function public.set_updated_at();

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('delivery-evidence', 'delivery-evidence', false),
  ('verification-documents', 'verification-documents', false),
  ('parcel-images', 'parcel-images', false),
  ('support-attachments', 'support-attachments', false),
  ('chat-attachments', 'chat-attachments', false)
on conflict (id) do nothing;
