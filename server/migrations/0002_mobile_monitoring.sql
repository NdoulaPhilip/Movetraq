begin;
select pg_advisory_xact_lock(hashtext('movetraq-mobile-monitoring-schema'));
alter table legacy_wallet_topups add column if not exists provider_status text;
alter table legacy_wallet_topups add column if not exists last_checked_at timestamptz;
alter table legacy_wallet_topups add column if not exists last_error_code text;
create table if not exists mobile_activity (
  id bigint generated always as identity primary key,
  entity text not null, entity_id text not null, user_id text, order_id text,
  event_type text not null, category text not null, outcome text not null,
  previous_status text, new_status text, reference text,
  metadata jsonb not null default '{}', created_at timestamptz not null default now()
);
create index if not exists mobile_activity_time on mobile_activity(created_at desc,id desc);
create index if not exists mobile_activity_reference on mobile_activity(reference);
create index if not exists mobile_activity_user on mobile_activity(user_id,created_at desc);
create table if not exists mobile_operation_records (
  entity text not null, entity_id text not null, user_id text, order_id text,
  record jsonb not null, observed_at timestamptz not null default now(), primary key(entity,entity_id)
);
create table if not exists mobile_request_attempts (
  id uuid primary key, actor_id text, staff_id uuid, method text not null, route text not null,
  category text not null, order_id text, reference text, status integer,
  outcome text not null default 'pending', error_code text,
  started_at timestamptz not null default now(), finished_at timestamptz
);
create index if not exists mobile_attempt_time on mobile_request_attempts(started_at desc);
revoke all on mobile_activity,mobile_operation_records,mobile_request_attempts from public;
create or replace function mobile_safe_record(n jsonb) returns jsonb language sql immutable as $$
  select coalesce(jsonb_object_agg(key,value),'{}') from jsonb_each(n)
  where key=any(array['id','uid','name','activeRole','verified','verificationStatus','delivererOnline',
    'vehicleType','totalDeliveries','code','senderId','senderName','delivererId','delivererName',
    'targetDelivererId','matchingMode','isP2P','isExpress','price','payout','status','createdAt',
    'deliveredAt','releasedAt','dStage','escrowHeld','escrowReleased','escrowRefunded','type',
    'amount','read','senderId','delivered_at','read_at','subject','category','priority',
    'reference','user_id','kind','amount_minor','balance_after_minor','provider_reference',
    'currency','verified_at','created_at','provider_status','last_checked_at','last_error_code','deleted']);
$$;
create or replace function mobile_project(p_entity text,p_id text,p_user text,p_order text,n jsonb) returns void language plpgsql as $$
declare prior jsonb; safe jsonb:=mobile_safe_record(n); c text; s text; old_status text;
begin
  select record into prior from mobile_operation_records where entity=p_entity and entity_id=p_id;
  if prior is not distinct from safe then return; end if;
  c:=case when p_entity in ('payments','ledger','wallet_transactions') then 'finance'
    when p_entity='orders' then 'orders' when p_entity in ('messages','notifications') then 'communication'
    when p_entity='support_tickets' then 'support' else 'accounts' end;
  s:=case when safe->>'status'='verified' then 'verified' else coalesce(safe->>'provider_status',safe->>'status') end;
  old_status:=case when prior->>'status'='verified' then 'verified' else coalesce(prior->>'provider_status',prior->>'status') end;
  insert into mobile_operation_records(entity,entity_id,user_id,order_id,record) values(p_entity,p_id,p_user,p_order,safe)
    on conflict(entity,entity_id) do update set record=excluded.record,user_id=excluded.user_id,order_id=excluded.order_id,observed_at=now();
  insert into mobile_activity(entity,entity_id,user_id,order_id,event_type,category,outcome,previous_status,new_status,reference,metadata)
    values(p_entity,p_id,p_user,p_order,p_entity||case when prior is null then '_recorded' else '_updated' end,c,
      case when safe->>'last_error_code' is not null or s in ('failed','abandoned','reversed') then 'failed' when s in ('created','initialized','pending','processing') then 'pending' else 'successful' end,
      old_status,s,coalesce(safe->>'reference',safe->>'provider_reference',safe->>'code'),safe);
end; $$;
create or replace function mobile_observe_row() returns trigger language plpgsql as $$
declare n jsonb:=to_jsonb(new); old_n jsonb; item jsonb; previous jsonb; owner text; key text; order_key text;
begin
  if tg_op='UPDATE' then old_n:=to_jsonb(old); end if;
  if tg_table_name in ('legacy_wallet_topups','legacy_wallet_ledger') then
    perform mobile_project(case when tg_table_name='legacy_wallet_topups' then 'payments' else 'ledger' end,
      coalesce(n->>'reference',n->>'id'),n->>'user_id',null,n); return new;
  end if;
  if tg_op='UPDATE' and n->'data' is not distinct from old_n->'data' then return new; end if;
  owner:=coalesce(n->>'uid',n->>'user_id'); order_key:=n->>'order_id';
  if jsonb_typeof(n->'data')='array' then
    for item in select value from jsonb_array_elements(n->'data') loop
      key:=coalesce(item->>'id',md5(item::text));
      perform mobile_project(case when tg_table_name='order_messages' then 'messages' else tg_table_name end,
        coalesce(owner,order_key)||':'||key,coalesce(item->>'senderId',owner),order_key,item);
    end loop;
    if tg_op='UPDATE' then
      for item in select value from jsonb_array_elements(old_n->'data') loop
        key:=coalesce(item->>'id',md5(item::text));
        if not exists(select 1 from jsonb_array_elements(n->'data') e where coalesce(e->>'id',md5(e::text))=key) then
          perform mobile_project(case when tg_table_name='order_messages' then 'messages' else tg_table_name end,
            coalesce(owner,order_key)||':'||key,coalesce(item->>'senderId',owner),order_key,item||'{"deleted":true}');
        end if;
      end loop;
    end if;
  else
    perform mobile_project(tg_table_name,coalesce(n->>'uid',n->>'id',owner),
      coalesce(owner,n->'data'->>'senderId'),case when tg_table_name='orders' then n->>'id' end,n->'data');
    if tg_table_name='orders' and old_n->'data'->'courierLocation' is distinct from n->'data'->'courierLocation'
      and n->'data'->'courierLocation' is not null then
      insert into mobile_activity(entity,entity_id,user_id,order_id,event_type,category,outcome)
        values('orders',n->>'id',n->'data'->>'delivererId',n->>'id','tracking_updated','orders','successful');
    end if;
  end if;
  return new;
end; $$;
do $$ declare t text; begin
  foreach t in array array['users','orders','order_messages','wallet_transactions','notifications','saved_addresses','security_settings','support_tickets','legacy_wallet_topups','legacy_wallet_ledger'] loop
    if not exists(select 1 from pg_trigger where tgname='mobile_monitor' and tgrelid=('public.'||t)::regclass) then
      execute format('create trigger mobile_monitor after insert or update on public.%I for each row execute function mobile_observe_row()',t);
    end if;
  end loop;
end $$;
-- Recover existing records, explicitly labelled as observations, never invented historical actions.
do $$ declare r record; t text; item jsonb; begin
  for r in select uid,data from users loop perform mobile_project('users',r.uid,r.uid,null,r.data); end loop;
  for r in select id,data from orders loop perform mobile_project('orders',r.id,r.data->>'senderId',r.id,r.data); end loop;
  for r in select * from legacy_wallet_topups loop perform mobile_project('payments',r.reference,r.user_id,null,to_jsonb(r)); end loop;
  for r in select * from legacy_wallet_ledger loop perform mobile_project('ledger',r.id,r.user_id,null,to_jsonb(r)); end loop;
  foreach t in array array['order_messages','wallet_transactions','notifications','saved_addresses','security_settings','support_tickets'] loop
    for r in execute format('select to_jsonb(x) as n from public.%I x',t) loop
      if jsonb_typeof(r.n->'data')='array' then
        for item in select value from jsonb_array_elements(r.n->'data') loop
          perform mobile_project(case when t='order_messages' then 'messages' else t end,
            coalesce(r.n->>'user_id',r.n->>'order_id')||':'||coalesce(item->>'id',md5(item::text)),
            coalesce(item->>'senderId',r.n->>'user_id'),r.n->>'order_id',item);
        end loop;
      else perform mobile_project(t,r.n->>'user_id',r.n->>'user_id',null,r.n->'data'); end if;
    end loop;
  end loop;
end $$;
create or replace function mobile_immutable_event() returns trigger language plpgsql as $$
begin raise exception 'Activity events are immutable' using errcode='42501'; end; $$;
drop trigger if exists mobile_activity_immutable on mobile_activity;
create trigger mobile_activity_immutable before update or delete on mobile_activity for each row execute function mobile_immutable_event();
drop trigger if exists mobile_activity_no_truncate on mobile_activity;
create trigger mobile_activity_no_truncate before truncate on mobile_activity for each statement execute function mobile_immutable_event();
revoke all on function mobile_safe_record(jsonb),mobile_project(text,text,text,text,jsonb),mobile_observe_row(),mobile_immutable_event() from public;
commit;
