begin;

-- Operational roles use narrowly scoped backend APIs, not unrestricted RLS access.
create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role in ('admin', 'super_admin')
  );
$$;
revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated, service_role;

alter view public.wallet_balances set (security_invoker = true);
revoke all on public.wallet_balances from anon;
grant select on public.wallet_balances to authenticated, service_role;

-- RLS limits rows; column grants additionally protect approval and review fields.
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (full_name, phone, avatar_path) on public.profiles to authenticated;
revoke insert, update, delete on public.deliverer_profiles,
  public.user_roles, public.security_settings, public.verification_applications,
  public.verification_documents, public.support_tickets, public.orders,
  public.order_events, public.wallet_accounts, public.wallet_ledger_entries,
  public.payments, public.escrows, public.conversations, public.messages,
  public.delivery_evidence, public.disputes, public.payouts,
  public.ratings, public.audit_logs, public.saved_addresses
from anon, authenticated;
revoke all on public.security_settings from anon, authenticated;
grant select (user_id, biometrics_enabled, deleted_at, anonymized_at, created_at, updated_at)
  on public.security_settings to authenticated;
revoke insert, update on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

create or replace function public.provision_account()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles(id, full_name, phone)
  values (new.id,
    coalesce(nullif(left(trim(new.raw_user_meta_data ->> 'full_name'), 120), ''), 'MoveTraq user'),
    case when new.raw_user_meta_data ->> 'phone' ~ '^\+[1-9][0-9]{7,14}$'
      then new.raw_user_meta_data ->> 'phone' else null end)
  on conflict (id) do nothing;
  insert into public.user_roles(user_id, role) values (new.id, 'sender') on conflict do nothing;
  insert into public.user_preferences(user_id) values (new.id) on conflict do nothing;
  insert into public.notification_preferences(user_id) values (new.id) on conflict do nothing;
  insert into public.security_settings(user_id) values (new.id) on conflict do nothing;
  insert into public.wallet_accounts(user_id) values (new.id) on conflict do nothing;
  return new;
end;
$$;
revoke all on function public.provision_account() from public, anon, authenticated;
create trigger auth_user_account_created after insert on auth.users
for each row execute function public.provision_account();

-- Complete accounts created before the provisioning trigger was installed.
insert into public.profiles(id, full_name, phone)
select id, coalesce(nullif(left(trim(raw_user_meta_data ->> 'full_name'), 120), ''), 'MoveTraq user'),
  case when raw_user_meta_data ->> 'phone' ~ '^\+[1-9][0-9]{7,14}$'
    then raw_user_meta_data ->> 'phone' else null end
from auth.users on conflict (id) do nothing;
insert into public.user_roles(user_id, role) select id, 'sender' from public.profiles on conflict do nothing;
insert into public.user_preferences(user_id) select id from public.profiles on conflict do nothing;
insert into public.notification_preferences(user_id) select id from public.profiles on conflict do nothing;
insert into public.security_settings(user_id) select id from public.profiles on conflict do nothing;
insert into public.wallet_accounts(user_id) select id from public.profiles on conflict do nothing;

alter table public.saved_addresses
  add constraint saved_addresses_latitude check (latitude between -90 and 90),
  add constraint saved_addresses_longitude check (longitude between -180 and 180);

create or replace function public.save_account_address(p_user_id uuid, p_address_id uuid, p_input jsonb)
returns public.saved_addresses language plpgsql set search_path = ''
as $$
declare saved public.saved_addresses;
begin
  -- Serialize default changes per account, including concurrent first inserts.
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then raise exception 'Account not found' using errcode = 'P0002'; end if;
  if p_address_id is not null then
    perform 1 from public.saved_addresses where id = p_address_id and user_id = p_user_id;
    if not found then raise exception 'Address not found' using errcode = 'P0002'; end if;
  end if;
  if coalesce((p_input ->> 'is_default')::boolean, false) then
    update public.saved_addresses set is_default = false where user_id = p_user_id and is_default;
  end if;
  if p_address_id is null then
    insert into public.saved_addresses(user_id, label, address, latitude, longitude, place_id, city, state, country, is_default)
    values (p_user_id, p_input ->> 'label', p_input ->> 'address',
      (p_input ->> 'latitude')::numeric, (p_input ->> 'longitude')::numeric,
      p_input ->> 'place_id', p_input ->> 'city', p_input ->> 'state',
      coalesce(p_input ->> 'country', 'NG'), coalesce((p_input ->> 'is_default')::boolean, false))
    returning * into saved;
  else
    update public.saved_addresses set
      label = p_input ->> 'label', address = p_input ->> 'address',
      latitude = (p_input ->> 'latitude')::numeric, longitude = (p_input ->> 'longitude')::numeric,
      place_id = p_input ->> 'place_id', city = p_input ->> 'city', state = p_input ->> 'state',
      country = coalesce(p_input ->> 'country', 'NG'), is_default = coalesce((p_input ->> 'is_default')::boolean, false)
    where id = p_address_id and user_id = p_user_id returning * into saved;
  end if;
  return saved;
end;
$$;
revoke all on function public.save_account_address(uuid, uuid, jsonb) from public, anon, authenticated;
grant execute on function public.save_account_address(uuid, uuid, jsonb) to service_role;

alter table public.wallet_accounts add constraint wallet_identity_currency unique (id, user_id, currency);
alter table public.wallet_ledger_entries add constraint ledger_wallet_identity
  foreign key (wallet_id, user_id, currency) references public.wallet_accounts(id, user_id, currency);

create or replace function public.reject_ledger_mutation()
returns trigger language plpgsql set search_path = ''
as $$
begin
  raise exception 'Ledger entries are immutable; post a compensating entry' using errcode = '55000';
end;
$$;
revoke all on function public.reject_ledger_mutation() from public, anon, authenticated;
create trigger immutable_wallet_ledger before update or delete on public.wallet_ledger_entries
for each row execute function public.reject_ledger_mutation();
create trigger immutable_wallet_ledger_truncate before truncate on public.wallet_ledger_entries
for each statement execute function public.reject_ledger_mutation();

commit;
