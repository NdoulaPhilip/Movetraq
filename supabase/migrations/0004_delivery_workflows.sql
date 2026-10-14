begin;
create table public.pricing_rules (
  id uuid primary key default gen_random_uuid(), service_type public.service_type not null,
  configuration jsonb not null, enabled boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index one_enabled_pricing_rule on public.pricing_rules(service_type) where enabled;
create table public.delivery_quotes (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
  service_type public.service_type not null, pricing_rule_id uuid not null references public.pricing_rules(id),
  input jsonb not null, route jsonb not null, pricing_breakdown jsonb not null,
  total_amount_minor integer not null check (total_amount_minor > 0),
  platform_fee_minor integer not null check (platform_fee_minor >= 0),
  deliverer_payout_minor integer not null check (deliverer_payout_minor > 0),
  expires_at timestamptz not null, created_at timestamptz not null default now(),
  check (total_amount_minor = platform_fee_minor + deliverer_payout_minor)
);
alter table public.orders add column quote_id uuid unique references public.delivery_quotes(id);
alter table public.orders add column idempotency_key text;
create unique index orders_sender_idempotency on public.orders(sender_id,idempotency_key) where idempotency_key is not null;
create table public.order_offers (
  order_id uuid not null references public.orders(id), deliverer_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(), primary key(order_id,deliverer_id)
);
create table public.handover_credentials (
  order_id uuid primary key references public.orders(id), code text not null,
  attempts integer not null default 0, expires_at timestamptz not null, used_at timestamptz
);
create table public.delivery_locations (
  order_id uuid primary key references public.orders(id), deliverer_id uuid not null references public.profiles(id),
  latitude numeric(10,7) not null check (latitude between -90 and 90),
  longitude numeric(10,7) not null check (longitude between -180 and 180),
  accuracy_meters numeric not null check (accuracy_meters between 0 and 500),
  captured_at timestamptz not null, updated_at timestamptz not null default now()
);
create table public.platform_ledger_entries (
  id uuid primary key default gen_random_uuid(), order_id uuid not null unique references public.orders(id),
  amount_minor integer not null check(amount_minor >= 0), currency char(3) not null,
  created_at timestamptz not null default now()
);
alter table public.deliverer_profiles add column service_preferences public.service_type[] not null default '{}';
alter table public.conversations drop constraint conversations_order_id_key;
alter table public.conversations add column closed_at timestamptz;
create unique index one_active_order_conversation on public.conversations(order_id) where closed_at is null;

do $$ declare relation text;
begin
  foreach relation in array array['pricing_rules','delivery_quotes','order_offers','handover_credentials','delivery_locations','platform_ledger_entries'] loop
    execute format('alter table public.%I enable row level security',relation);
    execute format('revoke all on public.%I from anon, authenticated',relation);
  end loop;
end;
$$;
grant select on public.delivery_quotes,public.delivery_locations,public.order_offers to authenticated;
create policy own_delivery_quotes on public.delivery_quotes for select using(user_id=auth.uid() or public.is_admin());
create policy participant_delivery_locations on public.delivery_locations for select using(exists(
  select 1 from public.orders where id=delivery_locations.order_id and public.is_order_participant(orders)));
create policy participant_order_offers on public.order_offers for select using(deliverer_id=auth.uid() or exists(
  select 1 from public.orders where id=order_offers.order_id and sender_id=auth.uid()));
create trigger immutable_quote before update on public.delivery_quotes for each row execute function public.reject_ledger_mutation();
create trigger immutable_platform_ledger before update or delete on public.platform_ledger_entries for each row execute function public.reject_ledger_mutation();

create function public.account_is_active(p_user uuid) returns boolean language sql stable set search_path='' as $$
  select exists(select 1 from public.security_settings where user_id=p_user and deleted_at is null);
$$;
create function public.people_are_blocked(p_one uuid,p_two uuid) returns boolean language sql stable set search_path='' as $$
  select exists(select 1 from public.blocked_users where (blocker_id=p_one and blocked_id=p_two) or (blocker_id=p_two and blocked_id=p_one));
$$;
create function public.distance_meters(p_lat numeric,p_lng numeric,p_other_lat numeric,p_other_lng numeric)
returns double precision language sql immutable set search_path='' as $$
  select 6371000 * 2 * asin(sqrt(least(1.0,power(sin(radians((p_other_lat-p_lat)::double precision)/2),2)+
    cos(radians(p_lat::double precision))*cos(radians(p_other_lat::double precision))*power(sin(radians((p_other_lng-p_lng)::double precision)/2),2))));
$$;
create function public.deliverer_is_eligible(p_user uuid,p_order public.orders) returns boolean language sql stable set search_path='' as $$
  select exists(select 1 from public.deliverer_profiles d where d.user_id=p_user
    and public.account_is_active(p_user) and p_order.sender_id<>p_user
    and d.verification_status='approved' and d.availability_status='online'
    and exists(select 1 from public.user_roles where user_id=p_user and role='deliverer')
    and not public.people_are_blocked(p_user,p_order.sender_id)
    and p_order.service_type=any(d.service_preferences)
    and d.active_job_count<coalesce((d.capacity->>'maxActiveJobs')::integer,0)
    and (p_order.parcel_info->>'weightKg')::numeric<=coalesce((d.capacity->>'maxWeightKg')::numeric,0)
    and (p_order.service_type<>'big_move' or
      (p_order.service_details->>'vehicleSize'='car' and d.transport_type in ('car','van','other_motor')) or
      (p_order.service_details->>'vehicleSize' in ('van','large_van') and d.transport_type in ('van','other_motor')))
    and public.distance_meters(p_order.pickup_latitude,p_order.pickup_longitude,
      (d.delivery_area->>'latitude')::numeric,(d.delivery_area->>'longitude')::numeric)<=coalesce((d.delivery_area->>'radiusMeters')::numeric,0));
$$;

create function public.guard_order_status() returns trigger language plpgsql set search_path='' as $$
declare allowed text[];
begin
  if new.status=old.status then return new; end if;
  allowed:=case old.status
    when 'draft' then array['pending_payment','cancelled']
    when 'pending_payment' then array['awaiting_deliverer','cancelled','failed']
    when 'awaiting_deliverer' then array['offer_received','deliverer_assigned','cancelled']
    when 'offer_received' then array['deliverer_assigned','rejected','cancelled']
    when 'deliverer_assigned' then array['accepted','rejected','cancelled']
    when 'accepted' then array['heading_to_pickup','cancelled']
    when 'heading_to_pickup' then array['arrived_pickup','failed','returning']
    when 'arrived_pickup' then array['picked_up','failed','returning']
    when 'picked_up' then array['heading_to_dropoff','failed','returning']
    when 'heading_to_dropoff' then array['arrived_dropoff','failed','returning']
    when 'arrived_dropoff' then array['awaiting_confirmation','failed','returning']
    when 'awaiting_confirmation' then array['completed','disputed']
    when 'rejected' then array['awaiting_deliverer']
    when 'failed' then array['returning','disputed']
    when 'returning' then array['returned','disputed']
    when 'returned' then array['disputed']
    when 'disputed' then array['completed','cancelled','returned']
    else array[]::text[] end;
  if not new.status::text=any(allowed) then raise exception 'Invalid order transition: % to %',old.status,new.status using errcode='P0001'; end if;
  return new;
end;
$$;
create trigger guarded_order_status before update of status on public.orders for each row execute function public.guard_order_status();

create function public.create_quoted_order(p_user_id uuid,p_quote_id uuid,p_key text) returns public.orders
language plpgsql set search_path='' as $$
declare q public.delivery_quotes; result public.orders; input jsonb; bytes bytea; code text;
begin
  if not public.account_is_active(p_user_id) or not exists(select 1 from public.user_roles where user_id=p_user_id and role='sender') then
    raise exception 'Sender account is unavailable' using errcode='42501'; end if;
  perform 1 from public.profiles where id=p_user_id for update;
  select * into result from public.orders where sender_id=p_user_id and idempotency_key=p_key;
  if found then
    if result.quote_id is distinct from p_quote_id then raise exception 'Idempotency key conflicts with quote' using errcode='P0001'; end if;
    return result;
  end if;
  select * into q from public.delivery_quotes where id=p_quote_id and user_id=p_user_id for update;
  if not found then raise exception 'Quote not found' using errcode='P0002'; end if;
  if q.expires_at<=now() then raise exception 'Quote expired' using errcode='P0001'; end if;
  input:=q.input;
  if input->>'scheduledAt' is not null and (input->>'scheduledAt')::timestamptz<=now() then raise exception 'Scheduled time has passed' using errcode='P0001'; end if;
  insert into public.orders(public_ref,sender_id,service_type,pickup_address,pickup_latitude,pickup_longitude,
    destination_address,destination_latitude,destination_longitude,recipient_name,recipient_phone,parcel_info,service_details,
    pricing_breakdown,total_amount_minor,platform_fee_minor,deliverer_payout_minor,scheduled_at,scheduled_timezone,quote_id,idempotency_key)
  values('MT-'||upper(replace(gen_random_uuid()::text,'-','')),p_user_id,q.service_type,input#>>'{pickup,address}',
    (input#>>'{pickup,latitude}')::numeric,(input#>>'{pickup,longitude}')::numeric,input#>>'{destination,address}',
    (input#>>'{destination,latitude}')::numeric,(input#>>'{destination,longitude}')::numeric,
    input#>>'{recipient,name}',input#>>'{recipient,phone}',input->'parcel',input->'serviceDetails',q.pricing_breakdown,
    q.total_amount_minor,q.platform_fee_minor,q.deliverer_payout_minor,(input->>'scheduledAt')::timestamptz,input->>'scheduledTimezone',q.id,p_key)
  returning * into result;
  bytes:=public.gen_random_bytes(4);
  code:=lpad(((get_byte(bytes,0)::bigint*16777216+get_byte(bytes,1)::bigint*65536+get_byte(bytes,2)::bigint*256+get_byte(bytes,3))%1000000)::text,6,'0');
  insert into public.handover_credentials(order_id,code,expires_at) values(result.id,code,coalesce(result.scheduled_at,now())+interval '7 days');
  insert into public.order_events(order_id,actor_id,event_type,new_status) values(result.id,p_user_id,'order_created','draft');
  return result;
end;
$$;

create function public.release_delivery_escrow(p_order_id uuid) returns void language plpgsql set search_path='' as $$
declare p_order public.orders; escrow public.escrows; wallet public.wallet_accounts;
begin
  select * into p_order from public.orders where id=p_order_id for update;
  if not found or p_order.status<>'awaiting_confirmation' then raise exception 'Delivery is not awaiting confirmation' using errcode='P0001'; end if;
  select * into escrow from public.escrows where order_id=p_order.id for update;
  if not found or escrow.status<>'held' or p_order.issue_status<>'none' or p_order.evidence_status<>'verified'
    or p_order.deliverer_id is null then raise exception 'Delivery escrow cannot be released' using errcode='P0001'; end if;
  if exists(select 1 from public.support_tickets where order_id=p_order.id and status not in ('resolved','closed'))
    or exists(select 1 from public.disputes where order_id=p_order.id and status not in ('resolved','closed')) then
    raise exception 'Unresolved delivery issue prevents release' using errcode='P0001'; end if;
  select * into wallet from public.wallet_accounts where user_id=p_order.deliverer_id and status='active' and currency=p_order.currency for update;
  if not found then raise exception 'Deliverer wallet unavailable' using errcode='P0001'; end if;
  insert into public.wallet_ledger_entries(wallet_id,user_id,order_id,type,amount_minor,currency,idempotency_key)
  values(wallet.id,wallet.user_id,p_order.id,'escrow_release',p_order.deliverer_payout_minor,p_order.currency,'release:'||p_order.id::text);
  insert into public.platform_ledger_entries(order_id,amount_minor,currency) values(p_order.id,p_order.platform_fee_minor,p_order.currency);
  update public.escrows set status='released',released_at=now(),released_amount_minor=amount_minor where id=escrow.id;
  update public.orders set escrow_status='released' where id=p_order.id;
end;
$$;

create function public.execute_delivery_command(p_actor_id uuid,p_order_id uuid,p_command text,p_input jsonb)
returns jsonb language plpgsql set search_path='' as $$
declare result public.orders; previous public.order_status; wallet public.wallet_accounts; balance bigint;
  chosen uuid; credential public.handover_credentials; is_sender boolean; is_deliverer boolean;
begin
  if not public.account_is_active(p_actor_id) then raise exception 'Account unavailable' using errcode='42501'; end if;
  select * into result from public.orders where id=p_order_id for update;
  if not found then raise exception 'Order not found' using errcode='P0002'; end if;
  previous:=result.status; is_sender:=result.sender_id=p_actor_id; is_deliverer:=coalesce(result.deliverer_id=p_actor_id,false);
  if not is_sender and not is_deliverer and p_command not in ('offer','accept') then raise exception 'Order access denied' using errcode='42501'; end if;
  if p_command in ('request_payment','fund','assign','confirm_receipt','cancel') and not is_sender then raise exception 'Sender action required' using errcode='42501'; end if;
  if p_command in ('heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff','handover','reject','returning','returned') and not is_deliverer then
    raise exception 'Assigned deliverer required' using errcode='42501'; end if;
  if result.issue_status<>'none' and p_command not in ('report_issue','returning','returned') then raise exception 'Unresolved delivery issue' using errcode='P0001'; end if;
  if p_command='request_payment' then
    if result.status='pending_payment' then return to_jsonb(result); end if;
    update public.orders set status='pending_payment' where id=result.id;
  elsif p_command='fund' then
    if result.payment_status='verified' then return to_jsonb(result); end if;
    if result.status<>'pending_payment' then raise exception 'Order is not awaiting payment' using errcode='P0001'; end if;
    select * into wallet from public.wallet_accounts where user_id=p_actor_id and status='active' and currency=result.currency for update;
    if not found then raise exception 'Wallet unavailable' using errcode='P0001'; end if;
    select coalesce(sum(amount_minor),0) into balance from public.wallet_ledger_entries where wallet_id=wallet.id;
    if balance<result.total_amount_minor then raise exception 'Insufficient wallet funds' using errcode='P0001'; end if;
    insert into public.wallet_ledger_entries(wallet_id,user_id,order_id,type,amount_minor,currency,idempotency_key)
    values(wallet.id,p_actor_id,result.id,'escrow_hold',-result.total_amount_minor,result.currency,'hold:'||result.id::text);
    insert into public.escrows(order_id,sender_id,status,amount_minor,idempotency_key,funded_at)
    values(result.id,p_actor_id,'held',result.total_amount_minor,'escrow:'||result.id::text,now());
    update public.orders set status='awaiting_deliverer',payment_status='verified',escrow_status='held' where id=result.id;
  elsif p_command='offer' then
    if result.service_type<>'p2p' or result.status not in ('awaiting_deliverer','offer_received') or not public.deliverer_is_eligible(p_actor_id,result) then
      raise exception 'Offer is not eligible' using errcode='42501'; end if;
    insert into public.order_offers(order_id,deliverer_id) values(result.id,p_actor_id) on conflict do nothing;
    update public.orders set status='offer_received' where id=result.id;
  elsif p_command='assign' or (p_command='accept' and not is_deliverer) then
    chosen:=case when p_command='assign' then (p_input->>'delivererId')::uuid else p_actor_id end;
    perform 1 from public.deliverer_profiles where user_id=chosen for update;
    if result.status not in ('awaiting_deliverer','offer_received') or result.escrow_status<>'held' or not public.deliverer_is_eligible(chosen,result) then
      raise exception 'Deliverer is no longer eligible' using errcode='P0001'; end if;
    if result.service_type='p2p' and (p_command<>'assign' or not exists(select 1 from public.order_offers where order_id=result.id and deliverer_id=chosen)) then
      raise exception 'Sender must confirm a P2P offer' using errcode='P0001'; end if;
    update public.orders set status='deliverer_assigned',deliverer_id=chosen where id=result.id;
    update public.deliverer_profiles set active_job_count=active_job_count+1 where user_id=chosen;
    update public.escrows set deliverer_id=chosen where order_id=result.id;
    insert into public.conversations(order_id,sender_id,deliverer_id) values(result.id,result.sender_id,chosen);
    if p_command='accept' then
      insert into public.order_events(order_id,actor_id,event_type,previous_status,new_status) values(result.id,p_actor_id,'assigned',previous,'deliverer_assigned');
      previous:='deliverer_assigned';
      update public.orders set status='accepted',accepted_at=now() where id=result.id;
    end if;
  elsif p_command='accept' then
    if result.status='accepted' then return to_jsonb(result); end if;
    if result.status<>'deliverer_assigned' or public.people_are_blocked(p_actor_id,result.sender_id)
      or not exists(select 1 from public.deliverer_profiles where user_id=p_actor_id and verification_status='approved') then
      raise exception 'Assignment cannot be accepted' using errcode='P0001'; end if;
    update public.orders set status='accepted',accepted_at=now() where id=result.id;
  elsif p_command in ('heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff','returning','returned') then
    if result.escrow_status not in ('held','disputed') then raise exception 'Delivery is not funded' using errcode='P0001'; end if;
    if result.status::text=p_command then return to_jsonb(result); end if;
    update public.orders set status=p_command::public.order_status,
      pickup_at=case when p_command='picked_up' then now() else pickup_at end where id=result.id;
    if p_command='arrived_dropoff' then update public.handover_credentials set expires_at=now()+interval '24 hours' where order_id=result.id; end if;
    if p_command='returned' then
      update public.deliverer_profiles set active_job_count=greatest(0,active_job_count-1) where user_id=p_actor_id;
      delete from public.delivery_locations where order_id=result.id;
    end if;
  elsif p_command='handover' then
    if result.evidence_status='verified' then return to_jsonb(result); end if;
    if result.status<>'arrived_dropoff' or result.escrow_status<>'held' then raise exception 'Handover cannot be recorded' using errcode='P0001'; end if;
    select * into credential from public.handover_credentials where order_id=result.id for update;
    if not found or credential.used_at is not null or credential.attempts>=5 or credential.expires_at<=now() then raise exception 'Handover code is unavailable' using errcode='P0001'; end if;
    if credential.code is distinct from p_input->>'code' then
      update public.handover_credentials set attempts=attempts+1 where order_id=result.id;
      return jsonb_build_object('error','INVALID_HANDOVER_CODE','message','Handover code is invalid.');
    end if;
    update public.handover_credentials set used_at=now(),code='' where order_id=result.id;
    insert into public.delivery_evidence(order_id,recipient_name,verification_code,submitted_by,captured_at)
    values(result.id,p_input->>'recipientName','verified_otp',p_actor_id,now());
    update public.orders set status='awaiting_confirmation',evidence_status='verified',delivered_at=now() where id=result.id returning * into result;
    if result.service_type<>'p2p' then
      insert into public.order_events(order_id,actor_id,event_type,previous_status,new_status) values(result.id,p_actor_id,'handover',previous,'awaiting_confirmation');
      previous:='awaiting_confirmation';
      perform public.release_delivery_escrow(result.id);
      update public.orders set status='completed',completed_at=now() where id=result.id;
      update public.deliverer_profiles set active_job_count=greatest(0,active_job_count-1) where user_id=p_actor_id;
    end if;
    delete from public.delivery_locations where order_id=result.id;
  elsif p_command='confirm_receipt' then
    if result.status='completed' and result.escrow_status='released' then return to_jsonb(result); end if;
    if result.status<>'awaiting_confirmation' then raise exception 'Delivery is not awaiting confirmation' using errcode='P0001'; end if;
    perform public.release_delivery_escrow(result.id);
    update public.orders set status='completed',completed_at=now() where id=result.id;
    update public.deliverer_profiles set active_job_count=greatest(0,active_job_count-1) where user_id=result.deliverer_id;
  elsif p_command='cancel' then
    if result.status='cancelled' then return to_jsonb(result); end if;
    if result.status not in ('draft','pending_payment','awaiting_deliverer','offer_received','deliverer_assigned','accepted') then raise exception 'Cancellation is unavailable after pickup progress begins' using errcode='P0001'; end if;
    if result.escrow_status='held' then
      perform 1 from public.escrows where order_id=result.id and status='held' for update;
      select * into wallet from public.wallet_accounts where user_id=result.sender_id and currency=result.currency for update;
      insert into public.wallet_ledger_entries(wallet_id,user_id,order_id,type,amount_minor,currency,idempotency_key)
      values(wallet.id,wallet.user_id,result.id,'refund',result.total_amount_minor,result.currency,'refund:'||result.id::text);
      update public.escrows set status='refunded',refunded_at=now() where order_id=result.id;
    end if;
    update public.orders set status='cancelled',cancelled_at=now(),cancellation_reason=p_input->>'reason',
      escrow_status=case when escrow_status='held' then 'refunded'::public.escrow_status else escrow_status end,
      payment_status=case when payment_status='verified' then 'refunded'::public.payment_status else payment_status end where id=result.id;
    if result.deliverer_id is not null then update public.deliverer_profiles set active_job_count=greatest(0,active_job_count-1) where user_id=result.deliverer_id; end if;
  elsif p_command='reject' then
    if result.status not in ('deliverer_assigned','accepted') then raise exception 'Rejection is unavailable after pickup progress begins' using errcode='P0001'; end if;
    update public.orders set status='rejected' where id=result.id;
    insert into public.order_events(order_id,actor_id,event_type,previous_status,new_status,metadata)
    values(result.id,p_actor_id,'rejected',previous,'rejected',jsonb_build_object('reason',p_input->>'reason'));
    previous:='rejected';
    update public.orders set status='awaiting_deliverer',deliverer_id=null,accepted_at=null where id=result.id;
    update public.deliverer_profiles set active_job_count=greatest(0,active_job_count-1) where user_id=p_actor_id;
    update public.escrows set deliverer_id=null where order_id=result.id;
    update public.conversations set closed_at=now() where order_id=result.id and closed_at is null;
    delete from public.delivery_locations where order_id=result.id;
    delete from public.order_offers where order_id=result.id and deliverer_id=p_actor_id;
  elsif p_command='report_issue' then
    if result.status in ('completed','cancelled') then raise exception 'Use support for a closed delivery' using errcode='P0001'; end if;
    insert into public.support_tickets(order_id,reporter_id,category,description) values(result.id,p_actor_id,'delivery_issue',p_input->>'reason');
    update public.orders set issue_status='open',escrow_status=case when escrow_status='held' then 'disputed'::public.escrow_status else escrow_status end where id=result.id;
    update public.escrows set status='disputed',disputed_at=now() where order_id=result.id and status='held';
    insert into public.disputes(order_id,opened_by) values(result.id,p_actor_id);
  else raise exception 'Unknown delivery command' using errcode='22023'; end if;
  select * into result from public.orders where id=p_order_id;
  insert into public.order_events(order_id,actor_id,event_type,previous_status,new_status)
  values(result.id,p_actor_id,p_command,previous,result.status);
  insert into public.notifications(user_id,type,title,body,data)
  values(result.sender_id,'order_update','Delivery updated','Your delivery has a new update.',jsonb_build_object('orderId',result.id,'status',result.status));
  if result.status in ('completed','cancelled') then
    update public.conversations set closed_at=now() where order_id=result.id and closed_at is null;
    delete from public.delivery_locations where order_id=result.id;
  end if;
  return to_jsonb(result);
end;
$$;

create function public.sender_handover_code(p_actor_id uuid,p_order_id uuid) returns jsonb language plpgsql set search_path='' as $$
declare code_row public.handover_credentials;
begin
  if not exists(select 1 from public.orders where id=p_order_id and sender_id=p_actor_id) then raise exception 'Sender access required' using errcode='42501'; end if;
  select * into code_row from public.handover_credentials where order_id=p_order_id and used_at is null;
  if not found then raise exception 'Handover code unavailable' using errcode='P0002'; end if;
  return jsonb_build_object('code',code_row.code,'expiresAt',code_row.expires_at);
end;
$$;
create function public.eligible_delivery_jobs(p_user_id uuid,p_limit integer,p_offset integer) returns jsonb language sql stable set search_path='' as $$
  select coalesce(jsonb_agg(to_jsonb(jobs)),'[]') from (
    select o.id,o.public_ref,o.service_type,o.pickup_address,o.destination_address,o.parcel_info,o.scheduled_at,o.deliverer_payout_minor
    from public.orders o where o.status in ('awaiting_deliverer','offer_received') and o.escrow_status='held'
      and public.deliverer_is_eligible(p_user_id,o) order by o.created_at,o.id limit p_limit offset p_offset
  ) jobs;
$$;
create function public.set_deliverer_availability(p_user_id uuid,p_input jsonb) returns public.deliverer_profiles language plpgsql set search_path='' as $$
declare profile public.deliverer_profiles;
begin
  select * into profile from public.deliverer_profiles where user_id=p_user_id for update;
  if not found or profile.verification_status<>'approved' then raise exception 'Approved deliverer required' using errcode='42501'; end if;
  if profile.transport_type::text is distinct from p_input->>'transportType' then raise exception 'Transport change requires verification review' using errcode='P0001'; end if;
  update public.deliverer_profiles set availability_status=case when (p_input->>'online')::boolean then 'online' else 'offline' end,
    delivery_area=p_input->'deliveryArea',capacity=p_input->'capacity',service_preferences=array(select jsonb_array_elements_text(p_input->'servicePreferences')::public.service_type)
  where user_id=p_user_id returning * into profile;
  return profile;
end;
$$;
create function public.record_delivery_location(p_user_id uuid,p_order_id uuid,p_input jsonb) returns jsonb language plpgsql set search_path='' as $$
declare delivery public.orders; existing public.delivery_locations; captured timestamptz;
begin
  select * into delivery from public.orders where id=p_order_id and deliverer_id=p_user_id for update;
  if not found or delivery.status not in ('accepted','heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff','returning') then
    raise exception 'Tracking requires an active assigned delivery' using errcode='42501'; end if;
  captured:=(p_input->>'capturedAt')::timestamptz;
  if captured<now()-interval '2 minutes' or captured>now()+interval '30 seconds' then raise exception 'Stale location timestamp' using errcode='22023'; end if;
  select * into existing from public.delivery_locations where order_id=p_order_id;
  if found and (existing.updated_at>now()-interval '5 seconds' or captured<=existing.captured_at) then return jsonb_build_object('throttled',true); end if;
  insert into public.delivery_locations(order_id,deliverer_id,latitude,longitude,accuracy_meters,captured_at)
  values(p_order_id,p_user_id,(p_input->>'latitude')::numeric,(p_input->>'longitude')::numeric,(p_input->>'accuracyMeters')::numeric,captured)
  on conflict(order_id) do update set latitude=excluded.latitude,longitude=excluded.longitude,accuracy_meters=excluded.accuracy_meters,captured_at=excluded.captured_at,updated_at=now();
  return jsonb_build_object('recorded',true);
end;
$$;
create function public.latest_delivery_location(p_actor_id uuid,p_order_id uuid) returns jsonb language plpgsql stable set search_path='' as $$
begin
  if not exists(select 1 from public.orders where id=p_order_id and p_actor_id in (sender_id,deliverer_id)) then raise exception 'Order access required' using errcode='42501'; end if;
  return (select to_jsonb(location) from public.delivery_locations location where order_id=p_order_id and updated_at>now()-interval '10 minutes');
end;
$$;
create function public.order_chat_history(p_actor_id uuid,p_order_id uuid,p_limit integer,p_offset integer) returns jsonb language plpgsql stable set search_path='' as $$
begin
  if not exists(select 1 from public.conversations where order_id=p_order_id and p_actor_id in (sender_id,deliverer_id)) then raise exception 'Conversation access required' using errcode='42501'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(history)),'[]') from (
    select m.* from public.messages m join public.conversations c on c.id=m.conversation_id
    where c.order_id=p_order_id and p_actor_id in (c.sender_id,c.deliverer_id) order by m.created_at desc,m.id limit p_limit offset p_offset
  ) history);
end;
$$;
create function public.send_order_message(p_actor_id uuid,p_order_id uuid,p_input jsonb) returns public.messages language plpgsql set search_path='' as $$
declare conversation public.conversations; message public.messages;
begin
  select * into conversation from public.conversations where order_id=p_order_id and closed_at is null for update;
  if not found or p_actor_id not in (conversation.sender_id,conversation.deliverer_id) or public.people_are_blocked(conversation.sender_id,conversation.deliverer_id) then
    raise exception 'Messaging is unavailable' using errcode='42501'; end if;
  insert into public.messages(conversation_id,sender_id,body,client_message_id,delivered_at)
  values(conversation.id,p_actor_id,p_input->>'body',p_input->>'clientMessageId',now())
  on conflict(conversation_id,client_message_id) do nothing;
  select * into message from public.messages where conversation_id=conversation.id and client_message_id=p_input->>'clientMessageId';
  if message.sender_id<>p_actor_id or message.body is distinct from p_input->>'body' then raise exception 'Message retry conflicts with original' using errcode='P0001'; end if;
  return message;
end;
$$;

-- All business commands run through the authenticated backend, never client RPCs.
do $$ declare fn regprocedure;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[
    'account_is_active','people_are_blocked','distance_meters','deliverer_is_eligible','guard_order_status','create_quoted_order',
    'release_delivery_escrow','execute_delivery_command','sender_handover_code','eligible_delivery_jobs','set_deliverer_availability',
    'record_delivery_location','latest_delivery_location','order_chat_history','send_order_message']) loop
    execute format('revoke all on function %s from public,anon,authenticated',fn);
    execute format('grant execute on function %s to service_role',fn);
  end loop;
end;
$$;
commit;
