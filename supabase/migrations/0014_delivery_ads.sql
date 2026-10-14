begin;

alter table public.p2p_ads add column title text not null default 'Delivery offer';
alter table public.p2p_ads add column creation_key text;
alter table public.p2p_ads add column creation_input jsonb;
create unique index delivery_ad_creation_key on public.p2p_ads(deliverer_id,creation_key) where creation_key is not null;
create index delivery_ads_owner_created on public.p2p_ads(deliverer_id,created_at desc,id);
create index delivery_ads_published on public.p2p_ads(created_at desc,id) where status='published';

create function public.valid_ad_coverage(p_value jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
begin
  return coalesce(jsonb_typeof(p_value)='object'
    and jsonb_typeof(p_value->'latitude')='number' and (p_value->>'latitude')::numeric between -90 and 90
    and jsonb_typeof(p_value->'longitude')='number' and (p_value->>'longitude')::numeric between -180 and 180
    and jsonb_typeof(p_value->'radiusMeters')='number' and (p_value->>'radiusMeters')::numeric between 100 and 100000
    and (p_value->>'radiusMeters')::numeric=trunc((p_value->>'radiusMeters')::numeric)
    and jsonb_typeof(p_value->'label')='string' and length(btrim(p_value->>'label')) between 2 and 120,false);
exception when others then return false;
end;
$$;
create function public.valid_ad_availability(p_value jsonb) returns boolean
language plpgsql immutable set search_path='' as $$
begin
  return coalesce(jsonb_typeof(p_value)='object' and jsonb_typeof(p_value->'from')='string'
    and jsonb_typeof(p_value->'until')='string'
    and (p_value->>'from')~'^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
    and (p_value->>'until')~'^\d{4}-\d{2}-\d{2}T.*(Z|[+-]\d{2}:\d{2})$'
    and isfinite((p_value->>'from')::timestamptz) and isfinite((p_value->>'until')::timestamptz)
    and (p_value->>'until')::timestamptz>(p_value->>'from')::timestamptz,false);
exception when others then return false;
end;
$$;
-- Existing prototype rows are retained, but new/changed rows must be valid.
alter table public.p2p_ads add constraint delivery_ad_coverage_valid
  check(status='deleted' or (public.valid_ad_coverage(pickup_coverage) and public.valid_ad_coverage(destination_coverage))) not valid;
alter table public.p2p_ads add constraint delivery_ad_availability_valid
  check(status='deleted' or public.valid_ad_availability(availability)) not valid;
alter table public.p2p_ads add constraint delivery_ad_fields_valid
  check(status='deleted' or (length(btrim(title)) between 3 and 120 and price_minor<=100000000 and currency='NGN'
    and (notes is null or length(notes)<=2000))) not valid;

create function public.ad_publish_permission(p_actor uuid) returns boolean
language sql stable set search_path='' as $$
  select public.account_is_active(p_actor) and exists(
    select 1 from public.deliverer_profiles d join public.user_roles r on r.user_id=d.user_id
    where d.user_id=p_actor and r.role='deliverer' and d.verification_status='approved');
$$;
create function public.public_ad_record(p_ad public.p2p_ads) returns jsonb
language sql immutable set search_path='' as $$
  select to_jsonb(p_ad)-'creation_key'-'creation_input';
$$;
create function public.save_delivery_ad(p_actor uuid,p_id uuid,p_input jsonb,p_key text) returns jsonb
language plpgsql set search_path='' as $$
declare result public.p2p_ads; worker public.deliverer_profiles; v_availability jsonb; minimum_price numeric;
begin
  select * into worker from public.deliverer_profiles where user_id=p_actor for update;
  if not public.ad_publish_permission(p_actor) then raise exception 'Approved deliverer capability required' using errcode='42501'; end if;
  if p_id is null then
    if p_key is null or p_key!~'^[A-Za-z0-9-]{16,128}$' then raise exception 'Valid idempotency key required' using errcode='22023'; end if;
    select * into result from public.p2p_ads where deliverer_id=p_actor and creation_key=p_key;
    if found then
      if result.creation_input is distinct from p_input then raise exception 'Idempotency key input conflict' using errcode='P0001'; end if;
      return public.public_ad_record(result);
    end if;
  else
    select * into result from public.p2p_ads where id=p_id and deliverer_id=p_actor and status<>'deleted' for update;
    if not found then raise exception 'Delivery ad not found' using errcode='P0002'; end if;
  end if;
  v_availability:=jsonb_build_object('from',p_input->>'availableFrom','until',p_input->>'availableUntil');
  if not public.valid_ad_coverage(p_input->'pickupCoverage') or not public.valid_ad_coverage(p_input->'destinationCoverage')
    or not public.valid_ad_availability(v_availability) then raise exception 'Invalid ad coverage or availability' using errcode='22023'; end if;
  if (v_availability->>'until')::timestamptz<=now() then raise exception 'Availability must end in the future' using errcode='P0001'; end if;
  select (configuration->>'minimumMinor')::numeric into minimum_price from public.pricing_rules where service_type='p2p' and enabled;
  if minimum_price is null or minimum_price<=0 or minimum_price>100000000 then raise exception 'Approved P2P pricing is not configured' using errcode='P0001'; end if;
  if jsonb_typeof(p_input->'priceMinor') is distinct from 'number' or (p_input->>'priceMinor')::numeric<minimum_price
    or (p_input->>'priceMinor')::numeric<>trunc((p_input->>'priceMinor')::numeric) then raise exception 'Ad price is below the configured minimum or invalid' using errcode='22023'; end if;
  if p_id is null then
    insert into public.p2p_ads(deliverer_id,title,pickup_coverage,destination_coverage,price_minor,availability,transport_type,notes,status,creation_key,creation_input)
      values(p_actor,btrim(p_input->>'title'),p_input->'pickupCoverage',p_input->'destinationCoverage',(p_input->>'priceMinor')::integer,
        v_availability,worker.transport_type,coalesce(p_input->>'notes',''),'published',p_key,p_input) returning * into result;
  else
    update public.p2p_ads set title=btrim(p_input->>'title'),pickup_coverage=p_input->'pickupCoverage',destination_coverage=p_input->'destinationCoverage',
      price_minor=(p_input->>'priceMinor')::integer,availability=v_availability,transport_type=worker.transport_type,notes=coalesce(p_input->>'notes','')
      where id=p_id returning * into result;
  end if;
  return public.public_ad_record(result);
end;
$$;

create function public.change_delivery_ad_status(p_actor uuid,p_id uuid,p_status text) returns jsonb
language plpgsql set search_path='' as $$
declare result public.p2p_ads; worker public.deliverer_profiles; minimum_price numeric;
begin
  if p_status is null or p_status not in ('published','paused','deleted') then raise exception 'Invalid ad status' using errcode='22023'; end if;
  select * into worker from public.deliverer_profiles where user_id=p_actor for update;
  select * into result from public.p2p_ads where id=p_id and deliverer_id=p_actor for update;
  if not found then raise exception 'Delivery ad not found' using errcode='P0002'; end if;
  if result.status='deleted' then
    if p_status='deleted' then return public.public_ad_record(result); end if;
    raise exception 'Deleted advertisements cannot be resumed' using errcode='P0001';
  end if;
  if p_status='published' then
    if not public.ad_publish_permission(p_actor) then raise exception 'Approved deliverer capability required' using errcode='42501'; end if;
    if not public.valid_ad_availability(result.availability) or not public.valid_ad_coverage(result.pickup_coverage)
      or not public.valid_ad_coverage(result.destination_coverage) then raise exception 'Update coverage and availability before publishing' using errcode='P0001'; end if;
    if (result.availability->>'until')::timestamptz<=now() then raise exception 'Update availability before resuming' using errcode='P0001'; end if;
    select (configuration->>'minimumMinor')::numeric into minimum_price from public.pricing_rules where service_type='p2p' and enabled;
    if minimum_price is null or result.price_minor<minimum_price then raise exception 'Update the price to meet approved pricing' using errcode='P0001'; end if;
  end if;
  update public.p2p_ads set status=p_status::public.ad_status,transport_type=coalesce(worker.transport_type,transport_type)
    where id=p_id returning * into result;
  return public.public_ad_record(result);
end;
$$;

create function public.ad_matches_delivery(p_ad public.p2p_ads,p_actor uuid,p_input jsonb) returns boolean
language plpgsql stable set search_path='' as $$
declare worker public.deliverer_profiles; minimum_price numeric;
begin
  if p_ad.status<>'published' or p_ad.deliverer_id=p_actor or not public.ad_publish_permission(p_ad.deliverer_id)
    or public.people_are_blocked(p_actor,p_ad.deliverer_id) or not public.valid_ad_coverage(p_ad.pickup_coverage)
    or not public.valid_ad_coverage(p_ad.destination_coverage) or not public.valid_ad_availability(p_ad.availability) then return false; end if;
  select * into worker from public.deliverer_profiles where user_id=p_ad.deliverer_id;
  select (configuration->>'minimumMinor')::numeric into minimum_price from public.pricing_rules where service_type='p2p' and enabled;
  return coalesce(minimum_price>0 and p_ad.price_minor>=minimum_price and worker.availability_status='online'
    and worker.transport_type=p_ad.transport_type and 'p2p'=any(worker.service_preferences)
    and worker.active_job_count<(worker.capacity->>'maxActiveJobs')::integer
    and (p_input->>'weightKg')::numeric<=(worker.capacity->>'maxWeightKg')::numeric
    and (p_ad.availability->>'from')::timestamptz<=now() and (p_ad.availability->>'until')::timestamptz>now()
    and public.distance_meters((p_input->>'pickupLatitude')::numeric,(p_input->>'pickupLongitude')::numeric,
      (worker.delivery_area->>'latitude')::numeric,(worker.delivery_area->>'longitude')::numeric)<=(worker.delivery_area->>'radiusMeters')::numeric
    and public.distance_meters((p_input->>'pickupLatitude')::numeric,(p_input->>'pickupLongitude')::numeric,
      (p_ad.pickup_coverage->>'latitude')::numeric,(p_ad.pickup_coverage->>'longitude')::numeric)<=(p_ad.pickup_coverage->>'radiusMeters')::numeric
    and public.distance_meters((p_input->>'destinationLatitude')::numeric,(p_input->>'destinationLongitude')::numeric,
      (p_ad.destination_coverage->>'latitude')::numeric,(p_ad.destination_coverage->>'longitude')::numeric)<=(p_ad.destination_coverage->>'radiusMeters')::numeric,false);
exception when others then return false;
end;
$$;
create function public.browse_delivery_ads(p_actor uuid,p_input jsonb) returns jsonb
language plpgsql stable set search_path='' as $$
begin
  if not public.account_is_active(p_actor) then raise exception 'Active account required' using errcode='42501'; end if;
  if coalesce((p_input->>'weightKg')::numeric,0)<=0
    or coalesce((p_input->>'pickupLatitude')::numeric,999) not between -90 and 90
    or coalesce((p_input->>'destinationLatitude')::numeric,999) not between -90 and 90
    or coalesce((p_input->>'pickupLongitude')::numeric,999) not between -180 and 180
    or coalesce((p_input->>'destinationLongitude')::numeric,999) not between -180 and 180 then
    raise exception 'Valid route coordinates and parcel weight required' using errcode='22023'; end if;
  return (select coalesce(jsonb_agg(candidate.record),'[]'::jsonb) from (
    select public.public_ad_record(a)||jsonb_build_object('delivererName',p.full_name) as record
    from public.p2p_ads a join public.profiles p on p.id=a.deliverer_id
    where public.ad_matches_delivery(a,p_actor,p_input)
    order by a.created_at desc,a.id limit least(50,greatest(1,coalesce((p_input->>'limit')::integer,25)))
    offset least(10000,greatest(0,coalesce((p_input->>'offset')::integer,0)))
  ) candidate);
end;
$$;

-- Public discovery is API-only so availability and two-way blocks cannot be bypassed.
drop policy p2p_ads_visible on public.p2p_ads;
drop policy p2p_ads_owner_write on public.p2p_ads;
revoke all on public.p2p_ads from anon,authenticated;
grant select on public.p2p_ads to authenticated;
create policy delivery_ads_owner_read on public.p2p_ads for select using(deliverer_id=auth.uid() or public.is_admin());
do $$ declare fn regprocedure;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname=any(array['valid_ad_coverage','valid_ad_availability','ad_publish_permission',
      'public_ad_record','save_delivery_ad','change_delivery_ad_status','ad_matches_delivery','browse_delivery_ads']) loop
    execute format('revoke all on function %s from public,anon,authenticated',fn);
    execute format('grant execute on function %s to service_role',fn);
  end loop;
end;
$$;
commit;
