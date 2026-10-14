begin;
alter table public.platform_activity
  add column actor_id uuid references public.profiles(id),
  add column category text not null default 'system' check(category in ('orders','finance','accounts','deliverers','communication','support','security','system')),
  add column description text not null default '',
  add column outcome text not null default 'successful' check(outcome in ('successful','failed','pending','rejected')),
  add column previous_status text,
  add column new_status text,
  add column order_id uuid references public.orders(id),
  add column reference text,
  add column error_code text,
  add column request_id uuid,
  add column source text not null default 'database' check(source in ('database','http','legacy')),
  add column metadata jsonb not null default '{}'::jsonb;
update public.platform_activity set source='legacy',description=replace(event_type,'_',' '),
  outcome=case when event_type ~ '_failed$' then 'failed' when event_type ~ '_rejected$' then 'rejected'
    when event_type ~ '_(initialized|pending|submitted|under_review|release_pending)$' then 'pending' else 'successful' end,
  order_id=case when entity='orders' then entity_id else null end,
  category=case when entity='orders' then 'orders' when entity in ('payments','wallet_ledger_entries') then 'finance'
    when entity='verification_applications' then 'deliverers' when entity='disputes' then 'support' when entity='profiles' then 'accounts' else 'system' end;
create index activity_category_date on public.platform_activity(category,created_at desc,id);
create index activity_actor_date on public.platform_activity(actor_id,created_at desc);
create index activity_order_date on public.platform_activity(order_id,created_at desc);
create index activity_reference on public.platform_activity(reference) where reference is not null;
create unique index activity_http_request on public.platform_activity(request_id) where source='http';
create trigger activity_append_only before update or delete on public.platform_activity
for each row execute function public.reject_ledger_mutation();
create trigger activity_no_truncate before truncate on public.platform_activity
for each statement execute function public.reject_ledger_mutation();

-- Only an explicit allowlist is copied; raw rows, document paths, GPS, message
-- bodies and provider webhook payloads must never enter the activity stream.
create or replace function public.record_platform_activity() returns trigger
language plpgsql security definer set search_path='' as $$
declare n jsonb:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  o jsonb:=case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else '{}'::jsonb end;
  u uuid; a uuid; related uuid; entity_key uuid; e text; c text; prev text; curr text; ref text; m jsonb:='{}';
begin
  entity_key:=coalesce(n->>'id',n->>'order_id',n->>'user_id')::uuid;
  u:=coalesce(n->>'user_id',n->>'sender_id',n->>'deliverer_id',n->>'reporter_id',n->>'opened_by',n->>'blocker_id')::uuid;
  related:=(n->>'order_id')::uuid;
  a:=coalesce(n->>'actor_id',n->>'admin_id',n->>'submitted_by')::uuid;
  prev:=coalesce(o->>'status',o->>'availability_status'); curr:=coalesce(n->>'status',n->>'availability_status');
  ref:=coalesce(n->>'provider_reference',n->>'public_ref');
  e:=tg_table_name||case when tg_op='INSERT' then '_created' when tg_op='DELETE' then '_removed' else '_updated' end;
  c:=case when tg_table_name in ('orders','order_events','order_offers','delivery_evidence','return_requests','delivery_locations') then 'orders'
    when tg_table_name in ('payments','wallet_ledger_entries','escrows','payouts','platform_ledger_entries','dispute_settlements') then 'finance'
    when tg_table_name in ('verification_applications','verification_documents','deliverer_profiles','p2p_ads') then 'deliverers'
    when tg_table_name in ('messages','notifications') then 'communication'
    when tg_table_name in ('support_tickets','disputes') then 'support'
    when tg_table_name='audit_logs' then 'security' else 'accounts' end;
  if tg_table_name='profiles' then
    u:=(n->>'id')::uuid; e:=case when tg_op='INSERT' then 'user_registered' else 'profile_updated' end;
    if tg_op='UPDATE' and (n-'updated_at')=(o-'updated_at') then return new; end if;
  elsif tg_table_name='orders' then
    related:=(n->>'id')::uuid;
    if tg_op='UPDATE' and new.status=old.status and new.deliverer_id is not distinct from old.deliverer_id then return new; end if;
    e:=case when tg_op='INSERT' then 'order_created' when new.deliverer_id is distinct from old.deliverer_id then 'deliverer_assignment_changed' else 'order_'||new.status::text end;
    m:=jsonb_build_object('delivererId',new.deliverer_id,'previousDelivererId',o->>'deliverer_id');
  elsif tg_table_name='order_events' then
    u:=new.actor_id; a:=new.actor_id; related:=new.order_id;
    e:='order_action_'||new.event_type; prev:=new.previous_status::text; curr:=new.new_status::text;
  elsif tg_table_name='verification_applications' then
    if tg_op='UPDATE' and new.status=old.status then return new; end if;
    a:=case when tg_op='INSERT' then new.user_id else new.reviewed_by end;
    e:='verification_'||new.status::text;
  elsif tg_table_name='messages' then
    select order_id into related from public.conversations where id=(n->>'conversation_id')::uuid;
    u:=(n->>'sender_id')::uuid;
    if tg_op='DELETE' then e:='message_removed'; curr:='removed';
    elsif tg_op='INSERT' then a:=new.sender_id; e:='message_sent'; curr:='sent';
    elsif new.read_at is distinct from old.read_at then e:='message_read'; curr:='read';
    elsif new.delivered_at is distinct from old.delivered_at then e:='message_delivered'; curr:='delivered';
    else return new; end if;
  elsif tg_table_name='delivery_locations' then
    -- Bound history volume to at most one tracking event per order per minute.
    if exists(select 1 from public.platform_activity where order_id=related and event_type='tracking_updated' and created_at>now()-interval '1 minute') then return new; end if;
    a:=new.deliverer_id; e:='tracking_updated';
  elsif tg_table_name='audit_logs' then
    a:=new.admin_id; u:=null; related:=case when new.entity='orders' then new.entity_id else null end;
    e:=new.action; entity_key:=new.entity_id;
  elsif tg_table_name='notifications' then
    e:=case when tg_op='INSERT' then 'notification_created' when tg_op='DELETE' then 'notification_removed' else 'notification_read' end;
    if tg_op='UPDATE' and new.read_at is not distinct from old.read_at then return new; end if;
  elsif tg_table_name='blocked_users' then
    a:=coalesce(n->>'blocker_id',o->>'blocker_id')::uuid; u:=a; entity_key:=coalesce(n->>'blocked_id',o->>'blocked_id')::uuid;
  elsif tg_table_name='security_settings' then
    if n->>'deleted_at' is distinct from o->>'deleted_at' then e:='account_deactivated';
    elsif n->>'suspended_at' is distinct from o->>'suspended_at' then e:=case when n->>'suspended_at' is null then 'account_reactivated' else 'account_suspended' end;
    else return new; end if;
  elsif tg_table_name='user_roles' then
    u:=coalesce(n->>'user_id',o->>'user_id')::uuid; entity_key:=u;
    m:=jsonb_build_object('role',coalesce(n->>'role',o->>'role'));
  elsif tg_op='UPDATE' and (n-'updated_at')=(o-'updated_at') then return new;
  end if;
  if c='finance' then
    m:=m||jsonb_strip_nulls(jsonb_build_object('amountMinor',n->'amount_minor','currency',n->'currency','provider',n->'provider','ledgerType',n->'type'));
  end if;
  insert into public.platform_activity(user_id,actor_id,event_type,category,description,entity,entity_id,previous_status,new_status,order_id,reference,outcome,metadata)
  values(u,a,e,c,replace(e,'_',' '),tg_table_name,entity_key,prev,curr,related,ref,
    case when curr in ('failed','rejected') then curr when curr in ('created','initialized','pending','processing','submitted','under_review','release_pending') then 'pending' else 'successful' end,m);
  return case when tg_op='DELETE' then old else new end;
end $$;

do $$ declare t text; begin
  -- Existing lifecycle triggers call the upgraded function. New tables join it.
  foreach t in array array['profiles','escrows','payouts','platform_ledger_entries','delivery_evidence','return_requests','dispute_settlements','support_tickets','messages','notifications','verification_documents','deliverer_profiles','delivery_locations','order_offers','blocked_users','security_settings','user_roles','p2p_ads','audit_logs'] loop
    execute format('create trigger monitor_changes after insert or update or delete on public.%I for each row execute function public.record_platform_activity()',t);
  end loop;
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach t in array array['platform_activity','audit_logs'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=t) then
        execute format('alter publication supabase_realtime add table public.%I',t);
      end if;
    end loop;
  end if;
end $$;
-- Avoid duplicate registration rows from the old registration trigger.
drop trigger platform_registration on public.profiles;
create or replace function public.record_account_login(p_user_id uuid) returns void
language sql security definer set search_path='' as $$
  insert into public.platform_activity(user_id,actor_id,event_type,category,description,entity,entity_id)
  values(p_user_id,p_user_id,'user_login','accounts','user login','profiles',p_user_id);
$$;

create function public.activity_metrics() returns jsonb language sql stable set search_path='' as $$
  select jsonb_build_object(
    'totalOrders',(select count(*) from public.orders),
    'activeDeliveries',(select count(*) from public.orders where status in ('deliverer_assigned','accepted','heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff','awaiting_confirmation','returning')),
    'completedOrders',(select count(*) from public.orders where status='completed'),
    'pendingPayments',(select count(*) from public.payments where status in ('created','initialized','pending')),
    'successfulPayments',(select count(*) from public.payments where status='verified'),
    'failedTransactions',(select count(*) from public.payments where status='failed'),
    'openDisputes',(select count(*) from public.disputes where status not in ('resolved','closed')),
    'pendingPayouts',(select count(*) from public.payouts where status in ('pending','approved','processing')),
    'registrations7d',(select count(*) from public.profiles where created_at>=now()-interval '7 days'),
    'series',(select jsonb_agg(x order by day) from (
      select d::date as day,
        (select count(*) from public.orders where created_at>=d and created_at<d+interval '1 day') as orders,
        (select count(*) from public.payments where status='verified' and verified_at>=d and verified_at<d+interval '1 day') as payments,
        (select coalesce(sum(amount_minor),0)::text from public.platform_ledger_entries where created_at>=d and created_at<d+interval '1 day') as revenue_minor,
        (select count(distinct coalesce(actor_id,user_id)) from public.platform_activity where created_at>=d and created_at<d+interval '1 day') as users
      from generate_series(date_trunc('day',now() at time zone 'UTC') at time zone 'UTC'-interval '13 days',date_trunc('day',now() at time zone 'UTC') at time zone 'UTC',interval '1 day') d
    ) x)
  );
$$;
revoke all on function public.activity_metrics() from public,anon,authenticated;
grant execute on function public.activity_metrics() to service_role;
commit;
