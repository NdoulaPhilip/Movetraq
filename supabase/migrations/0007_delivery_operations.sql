begin;
create function public.activate_pricing_rule(p_admin_id uuid,p_service_type public.service_type,p_configuration jsonb) returns public.pricing_rules
language plpgsql set search_path='' as $$
declare result public.pricing_rules; previous jsonb;
begin
  if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('finance','admin','super_admin')) then
    raise exception 'Pricing permission required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtext('pricing:'||p_service_type::text));
  select to_jsonb(rule) into previous from public.pricing_rules rule where service_type=p_service_type and enabled;
  update public.pricing_rules set enabled=false where service_type=p_service_type and enabled;
  insert into public.pricing_rules(service_type,configuration,enabled) values(p_service_type,p_configuration,true) returning * into result;
  insert into public.audit_logs(admin_id,action,entity,entity_id,previous_state,new_state)
  values(p_admin_id,'pricing_activated','pricing_rule',result.id,previous,to_jsonb(result));
  return result;
end;
$$;
create function public.quote_deliverer_candidates(p_user_id uuid,p_quote_id uuid) returns jsonb language plpgsql stable set search_path='' as $$
declare quote public.delivery_quotes; potential public.orders;
begin
  select * into quote from public.delivery_quotes where id=p_quote_id and user_id=p_user_id and expires_at>now();
  if not found then raise exception 'Active quote not found' using errcode='P0002'; end if;
  potential:=jsonb_populate_record(null::public.orders,jsonb_build_object('sender_id',p_user_id,'service_type',quote.service_type,
    'pickup_latitude',quote.input#>'{pickup,latitude}','pickup_longitude',quote.input#>'{pickup,longitude}',
    'parcel_info',quote.input->'parcel','service_details',quote.input->'serviceDetails'));
  return (select coalesce(jsonb_agg(to_jsonb(candidate)),'[]') from (
    select p.id,p.full_name,p.avatar_path,d.transport_type,d.verification_status,
      public.distance_meters(potential.pickup_latitude,potential.pickup_longitude,
        (d.delivery_area->>'latitude')::numeric,(d.delivery_area->>'longitude')::numeric) as coverage_distance_meters
    from public.deliverer_profiles d join public.profiles p on p.id=d.user_id
    where public.deliverer_is_eligible(d.user_id,potential) order by coverage_distance_meters,p.id limit 50
  ) candidate);
end;
$$;
create function public.deliverer_summary(p_user_id uuid) returns jsonb language plpgsql stable set search_path='' as $$
begin
  if not exists(select 1 from public.user_roles where user_id=p_user_id and role='deliverer') then raise exception 'Deliverer capability required' using errcode='42501'; end if;
  return jsonb_build_object(
    'availableBalanceMinor',coalesce((select balance_minor from public.wallet_balances where user_id=p_user_id),0),
    'completedDeliveries',(select count(*) from public.orders where deliverer_id=p_user_id and status='completed'),
    'activeDeliveries',(select count(*) from public.orders where deliverer_id=p_user_id and status not in ('completed','cancelled','returned','rejected')),
    'earningsMinor',coalesce((select sum(amount_minor) from public.wallet_ledger_entries where user_id=p_user_id and type='escrow_release'),0),
    'pendingEarningsMinor',coalesce((select sum(o.deliverer_payout_minor) from public.orders o join public.escrows e on e.order_id=o.id
      where o.deliverer_id=p_user_id and o.status='awaiting_confirmation' and e.status in ('held','disputed')),0),
    'currency','NGN');
end;
$$;
create function public.deliverer_past_customers(p_user_id uuid) returns jsonb language plpgsql stable set search_path='' as $$
begin
  if not exists(select 1 from public.user_roles where user_id=p_user_id and role='deliverer') then raise exception 'Deliverer capability required' using errcode='42501'; end if;
  return (select coalesce(jsonb_agg(to_jsonb(customer)),'[]') from (
    select p.id,p.full_name,count(*) as completed_deliveries,max(o.completed_at) as last_delivery_at
    from public.orders o join public.profiles p on p.id=o.sender_id
    where o.deliverer_id=p_user_id and o.status='completed' group by p.id,p.full_name order by last_delivery_at desc,p.id limit 100
  ) customer);
end;
$$;
do $$ declare fn regprocedure;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[
    'activate_pricing_rule','quote_deliverer_candidates','deliverer_summary','deliverer_past_customers']) loop
    execute format('revoke all on function %s from public,anon,authenticated',fn);
    execute format('grant execute on function %s to service_role',fn);
  end loop;
end;
$$;
commit;
