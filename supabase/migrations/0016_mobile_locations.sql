-- Legacy identities remain text; no duplicate Supabase Auth accounts are created.
create table public.mobile_saved_addresses (
  id text primary key default gen_random_uuid()::text,
  legacy_user_id text not null check (legacy_user_id ~ '^user_[A-Za-z0-9_-]{1,120}$'),
  label text not null check (length(label) between 1 and 80),
  address text not null check (length(address) between 1 and 1000),
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  place_id text,
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index mobile_addresses_owner on public.mobile_saved_addresses(legacy_user_id);
create unique index mobile_addresses_default on public.mobile_saved_addresses(legacy_user_id) where is_default;
alter table public.mobile_saved_addresses enable row level security;
revoke all on public.mobile_saved_addresses from anon,authenticated;
grant all on public.mobile_saved_addresses to service_role;

create table public.mobile_delivery_routes (
  order_id text primary key,
  sender_id text not null,
  pickup jsonb not null,
  destination jsonb not null,
  route jsonb not null,
  created_at timestamptz not null default now()
);
alter table public.mobile_delivery_routes enable row level security;
revoke all on public.mobile_delivery_routes from anon,authenticated;
grant all on public.mobile_delivery_routes to service_role;

create table public.mobile_delivery_locations (
  order_id text primary key,
  sender_id text not null,
  deliverer_id text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy double precision not null check (accuracy between 0 and 500),
  captured_at timestamptz not null,
  updated_at timestamptz not null default now()
);
create index mobile_locations_retention on public.mobile_delivery_locations(updated_at);
alter table public.mobile_delivery_locations enable row level security;
revoke all on public.mobile_delivery_locations from anon,authenticated;
grant all on public.mobile_delivery_locations to service_role;

create function public.mobile_location_command(p_user text,p_command text,p_input jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb; row_address mobile_saved_addresses; location mobile_delivery_locations;
begin
  if p_user is null or p_user !~ '^user_[A-Za-z0-9_-]{1,120}$' then raise exception 'Invalid mobile identity'; end if;
  -- Serialize default changes for an account without locking unrelated accounts.
  perform pg_advisory_xact_lock(hashtextextended('mobile-address:'||p_user,0));
  if p_command='addresses' then
    select coalesce(jsonb_agg(to_jsonb(a) order by a.created_at),'[]') into result from mobile_saved_addresses a where legacy_user_id=p_user;
    return jsonb_build_object('addresses',result);
  elsif p_command='save-address' then
    if exists(select 1 from mobile_saved_addresses where id=p_input->>'id' and legacy_user_id<>p_user) then raise exception 'Address not found'; end if;
    if coalesce((p_input->>'isDefault')::boolean,false) then update mobile_saved_addresses set is_default=false,updated_at=now() where legacy_user_id=p_user and is_default; end if;
    insert into mobile_saved_addresses(id,legacy_user_id,label,address,latitude,longitude,place_id,is_default)
      values(coalesce(p_input->>'id',gen_random_uuid()::text),p_user,p_input->>'label',p_input->>'address',
        (p_input->>'latitude')::double precision,(p_input->>'longitude')::double precision,p_input->>'placeId',coalesce((p_input->>'isDefault')::boolean,false))
      on conflict(id) do update set label=excluded.label,address=excluded.address,latitude=excluded.latitude,longitude=excluded.longitude,
        place_id=excluded.place_id,is_default=excluded.is_default,updated_at=now() where mobile_saved_addresses.legacy_user_id=p_user
      returning * into row_address;
    if not found then raise exception 'Address not found'; end if;
    return jsonb_build_object('address',to_jsonb(row_address));
  elsif p_command='default-address' then
    if not exists(select 1 from mobile_saved_addresses where id=p_input->>'id' and legacy_user_id=p_user) then raise exception 'Address not found'; end if;
    update mobile_saved_addresses set is_default=false,updated_at=now() where legacy_user_id=p_user and is_default;
    update mobile_saved_addresses set is_default=true,updated_at=now() where id=p_input->>'id' and legacy_user_id=p_user;
    return jsonb_build_object('saved',true);
  elsif p_command='delete-address' then
    delete from mobile_saved_addresses where id=p_input->>'id' and legacy_user_id=p_user;
    return jsonb_build_object('deleted',true);
  elsif p_command='register-order' then
    insert into mobile_delivery_routes(order_id,sender_id,pickup,destination,route)
      values(p_input->>'orderId',p_user,p_input->'pickup',p_input->'destination',p_input->'route');
    return jsonb_build_object('saved',true);
  elsif p_command='location' then
    if not exists(select 1 from verification_applications where legacy_user_id=p_user and status='approved') then raise exception 'Deliverer approval required'; end if;
    if (p_input->>'capturedAt')::timestamptz < now()-interval '2 minutes' or (p_input->>'capturedAt')::timestamptz > now()+interval '30 seconds' then raise exception 'GPS sample is not current'; end if;
    insert into mobile_delivery_locations(order_id,sender_id,deliverer_id,latitude,longitude,accuracy,captured_at)
      values(p_input->>'orderId',p_input->>'senderId',p_user,(p_input->>'latitude')::double precision,
        (p_input->>'longitude')::double precision,(p_input->>'accuracy')::double precision,(p_input->>'capturedAt')::timestamptz)
      on conflict(order_id) do update set deliverer_id=excluded.deliverer_id,latitude=excluded.latitude,longitude=excluded.longitude,
        accuracy=excluded.accuracy,captured_at=excluded.captured_at,updated_at=now()
      where mobile_delivery_locations.sender_id=excluded.sender_id and mobile_delivery_locations.captured_at<excluded.captured_at;
    -- Keep only the latest point, with a bounded operational retention window.
    delete from mobile_delivery_locations where updated_at<now()-interval '24 hours';
    return jsonb_build_object('saved',true);
  elsif p_command='read-location' then
    select * into location from mobile_delivery_locations where order_id=p_input->>'orderId' and (sender_id=p_user or deliverer_id=p_user) and captured_at>now()-interval '2 minutes';
    return jsonb_build_object('location',case when location.order_id is null then null else to_jsonb(location) end);
  end if;
  raise exception 'Unknown location command';
end $$;
revoke all on function public.mobile_location_command(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.mobile_location_command(text,text,jsonb) to service_role;
