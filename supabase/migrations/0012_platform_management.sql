begin;
alter table public.security_settings add column suspended_at timestamptz;

create function public.account_enabled(p_user_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.security_settings where user_id=p_user_id
    and deleted_at is null and suspended_at is null);
$$;
revoke all on function public.account_enabled(uuid) from public, anon;
grant execute on function public.account_enabled(uuid) to authenticated, service_role;
create or replace function public.account_is_active(p_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select public.account_enabled(p_user);
$$;
do $$ declare t text; begin
  for t in select tablename from pg_tables where schemaname='public' and rowsecurity loop
    execute format('create policy enabled_account on public.%I as restrictive for all to authenticated using (public.account_enabled(auth.uid())) with check (public.account_enabled(auth.uid()))', t);
  end loop;
end $$;

create table public.platform_activity (
  id uuid primary key default gen_random_uuid(), user_id uuid references public.profiles(id),
  event_type text not null, entity text not null, entity_id uuid,
  created_at timestamptz not null default now()
);
create index platform_activity_recent on public.platform_activity(created_at desc,id desc);
create index platform_activity_user on public.platform_activity(user_id,created_at desc);
create index profiles_registration_date on public.profiles(created_at desc,id);
create index user_roles_role_user on public.user_roles(role,user_id);
alter table public.platform_activity enable row level security;
revoke all on public.platform_activity from anon, authenticated;
revoke update,delete,truncate on public.platform_activity from service_role;
grant select, insert on public.platform_activity to service_role;

create function public.record_platform_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare u uuid; e text; begin
  if tg_table_name='profiles' then u:=new.id; e:='user_registered';
  elsif tg_table_name='orders' then
    u:=new.sender_id;
    if tg_op='UPDATE' and new.status=old.status then return new; end if;
    e:=case when tg_op='INSERT' then 'order_created' else 'order_'||new.status::text end;
  elsif tg_table_name='order_events' then
    insert into public.platform_activity(user_id,event_type,entity,entity_id)
      values(new.actor_id,'order_action_'||new.event_type,'orders',new.order_id);
    return new;
  elsif tg_table_name='wallet_ledger_entries' then u:=new.user_id; e:='wallet_'||new.type::text;
  elsif tg_table_name='payments' then
    u:=new.user_id;
    if tg_op='UPDATE' and new.status=old.status then return new; end if;
    e:='payment_'||new.status::text;
  elsif tg_table_name='verification_applications' then
    u:=new.user_id;
    if tg_op='UPDATE' and new.status=old.status then return new; end if;
    e:='verification_'||new.status::text;
  elsif tg_table_name='disputes' then u:=new.opened_by; e:='dispute_'||new.status::text;
  else return new; end if;
  insert into public.platform_activity(user_id,event_type,entity,entity_id) values(u,e,tg_table_name,new.id);
  return new;
end $$;
revoke all on function public.record_platform_activity() from public, anon, authenticated;
create trigger platform_registration after insert on public.profiles for each row execute function public.record_platform_activity();
create trigger platform_orders after insert or update on public.orders for each row execute function public.record_platform_activity();
create trigger platform_order_actors after insert on public.order_events for each row execute function public.record_platform_activity();
create trigger platform_wallet after insert on public.wallet_ledger_entries for each row execute function public.record_platform_activity();
create trigger platform_payments after insert or update on public.payments for each row execute function public.record_platform_activity();
create trigger platform_verification after insert or update on public.verification_applications for each row execute function public.record_platform_activity();
create trigger platform_disputes after insert or update on public.disputes for each row execute function public.record_platform_activity();

create view public.admin_user_directory with (security_invoker=true) as
select p.id,p.full_name,p.phone,p.created_at,p.verification_status,
  case when s.deleted_at is not null then null else a.email end as email,
  case when s.deleted_at is not null then 'deactivated' when s.suspended_at is not null then 'suspended' else 'active' end as account_status,
  array(select r.role::text from public.user_roles r where r.user_id=p.id order by r.role) as roles,
  (select max(x.created_at) from public.platform_activity x where x.user_id=p.id) as recent_activity
from public.profiles p join auth.users a on a.id=p.id join public.security_settings s on s.user_id=p.id;
revoke all on public.admin_user_directory from anon,authenticated;
grant select on public.admin_user_directory to service_role;
grant select(id,email) on auth.users to service_role;
create view public.admin_online_deliverers with (security_invoker=true) as
select d.user_id from public.deliverer_profiles d
join public.admin_user_directory u on u.id=d.user_id
where u.account_status='active' and 'deliverer'=any(u.roles)
and d.availability_status='online' and d.verification_status='approved';
revoke all on public.admin_online_deliverers from anon,authenticated;
grant select on public.admin_online_deliverers to service_role;

create function public.manage_platform_user(p_actor uuid,p_target uuid,p_input jsonb,p_action text) returns uuid
language plpgsql set search_path='' as $$
declare before_state jsonb; after_state jsonb; role_value text; begin
  -- Serialize privilege changes, including concurrent removal of the last Super Admin.
  perform pg_advisory_xact_lock(71422012);
  if not public.account_enabled(p_actor) or not exists(select 1 from public.user_roles where user_id=p_actor and role='super_admin') then
    raise exception 'Super Admin required' using errcode='42501';
  end if;
  if p_actor=p_target then raise exception 'Self management is forbidden' using errcode='22023'; end if;
  select to_jsonb(d) into before_state from public.admin_user_directory d where id=p_target;
  if before_state is null then raise exception 'User not found' using errcode='P0002'; end if;
  if before_state->>'account_status'='deactivated' then raise exception 'Account deactivated' using errcode='22023'; end if;
  if p_input ? 'roles' then
    if jsonb_array_length(p_input->'roles')=0 then raise exception 'Roles required' using errcode='22023'; end if;
    if p_input->>'status'='deactivated' then raise exception 'Invalid role change' using errcode='22023'; end if;
  end if;
  if exists(select 1 from public.user_roles where user_id=p_target and role='super_admin')
    and (coalesce(p_input->>'status','active')<>'active' or (p_input ? 'roles' and not p_input->'roles' ? 'super_admin'))
    and not exists(select 1 from public.user_roles r where r.role='super_admin' and r.user_id<>p_target and public.account_enabled(r.user_id)) then
      raise exception 'Last Super Admin protected' using errcode='22023';
  end if;
  if p_input ? 'name' then update public.profiles set full_name=p_input->>'name' where id=p_target; end if;
  if p_input ? 'phone' then update public.profiles set phone=p_input->>'phone' where id=p_target; end if;
  if p_input ? 'roles' then
    delete from public.user_roles where user_id=p_target;
    for role_value in select jsonb_array_elements_text(p_input->'roles') loop
      insert into public.user_roles(user_id,role) values(p_target,role_value::public.user_role) on conflict do nothing;
    end loop;
    update public.profiles set active_role=case when p_input->'roles' ? 'sender' then 'sender'::public.user_role else (p_input->'roles'->>0)::public.user_role end where id=p_target;
  end if;
  if p_input->>'status'='suspended' then
    update public.security_settings set suspended_at=now() where user_id=p_target;
  elsif p_input->>'status'='active' then
    update public.security_settings set suspended_at=null where user_id=p_target;
  elsif p_input->>'status'='deactivated' then
    update public.security_settings set deleted_at=now(),anonymized_at=now() where user_id=p_target;
    update public.profiles set full_name='Deactivated account',phone=null,avatar_path=null where id=p_target;
    delete from public.user_roles where user_id=p_target;
  end if;
  select to_jsonb(d) into after_state from public.admin_user_directory d where id=p_target;
  insert into public.audit_logs(admin_id,action,entity,entity_id,previous_state,new_state,metadata)
    values(p_actor,p_action,'profiles',p_target,before_state - 'email' - 'phone',after_state - 'email' - 'phone',jsonb_build_object('reason',p_input->>'reason'));
  insert into public.platform_activity(user_id,event_type,entity,entity_id) values(p_target,p_action,'profiles',p_target);
  return p_target;
end $$;
revoke all on function public.manage_platform_user(uuid,uuid,jsonb,text) from public,anon,authenticated;
grant execute on function public.manage_platform_user(uuid,uuid,jsonb,text) to service_role;
create function public.record_account_login(p_user_id uuid) returns void
language plpgsql set search_path='' as $$ begin
  if not public.account_enabled(p_user_id) then raise exception 'Account disabled' using errcode='42501'; end if;
  insert into public.platform_activity(user_id,event_type,entity,entity_id) values(p_user_id,'user_login','profiles',p_user_id);
end $$;
revoke all on function public.record_account_login(uuid) from public,anon,authenticated;
grant execute on function public.record_account_login(uuid) to service_role;
commit;
