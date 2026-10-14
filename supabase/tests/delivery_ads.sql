begin;
insert into auth.users(id,email) values
 ('14000000-0000-4000-8000-000000000001','ads-sender@example.test'),
 ('14000000-0000-4000-8000-000000000002','ads-worker@example.test'),
 ('14000000-0000-4000-8000-000000000003','ads-other@example.test');
insert into public.user_roles(user_id,role) values('14000000-0000-4000-8000-000000000002','deliverer');
insert into public.deliverer_profiles(user_id,transport_type,verification_status,availability_status,service_preferences,capacity,delivery_area)
 values('14000000-0000-4000-8000-000000000002','bicycle','approved','online','{p2p}',
 '{"maxActiveJobs":2,"maxWeightKg":10}','{"latitude":6.6,"longitude":3.3,"radiusMeters":50000}');
insert into public.pricing_rules(service_type,configuration,enabled) values('p2p','{"minimumMinor":10000}',true);
do $$
declare sender uuid:='14000000-0000-4000-8000-000000000001'; worker uuid:='14000000-0000-4000-8000-000000000002';
 other uuid:='14000000-0000-4000-8000-000000000003'; payload jsonb; result jsonb; ad_id uuid; route jsonb;
begin
  payload:=jsonb_build_object('title','Ikeja delivery','pickupCoverage','{"latitude":6.6,"longitude":3.3,"radiusMeters":10000,"label":"Ikeja"}'::jsonb,
    'destinationCoverage','{"latitude":6.5,"longitude":3.4,"radiusMeters":10000,"label":"Yaba"}'::jsonb,
    'priceMinor',20000,'availableFrom',to_char((now()-interval '1 hour') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')||'Z',
    'availableUntil',to_char((now()+interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')||'Z','notes','Handle carefully');
  route:='{"pickupLatitude":6.6,"pickupLongitude":3.3,"destinationLatitude":6.5,"destinationLongitude":3.4,"weightKg":2}';
  begin perform public.save_delivery_ad(sender,null,payload,'ad-create-test-key-001'); raise exception 'Sender published ad';
  exception when insufficient_privilege then null; end;
  result:=public.save_delivery_ad(worker,null,payload,'ad-create-test-key-001'); ad_id:=(result->>'id')::uuid;
  if result ? 'creation_key' or result ? 'creation_input' then raise exception 'Private replay metadata exposed'; end if;
  if public.save_delivery_ad(worker,null,payload,'ad-create-test-key-001')->>'id'<>ad_id::text then raise exception 'Ad retry created duplicate'; end if;
  begin perform public.save_delivery_ad(worker,null,payload||'{"priceMinor":30000}','ad-create-test-key-001'); raise exception 'Conflicting retry accepted';
  exception when raise_exception then if SQLERRM='Conflicting retry accepted' then raise; end if; end;
  begin perform public.save_delivery_ad(other,ad_id,payload,null); raise exception 'Cross-owner update accepted';
  exception when insufficient_privilege then null; end;
  begin perform public.change_delivery_ad_status(other,ad_id,'paused'); raise exception 'Cross-owner status accepted';
  exception when no_data_found then null; end;
  begin perform public.save_delivery_ad(worker,ad_id,payload||'{"priceMinor":1}',null); raise exception 'Below-minimum ad accepted';
  exception when invalid_parameter_value then null; end;
  begin perform public.save_delivery_ad(worker,ad_id,payload||'{"pickupCoverage":{"latitude":91,"longitude":3,"radiusMeters":1000,"label":"Invalid"}}',null); raise exception 'Invalid coverage accepted';
  exception when invalid_parameter_value then null; end;
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>1 then raise exception 'Eligible ad missing'; end if;
  if jsonb_array_length(public.browse_delivery_ads(worker,route))<>0 then raise exception 'Own ad shown as candidate'; end if;
  if jsonb_array_length(public.browse_delivery_ads(sender,route||'{"weightKg":20}'))<>0 then raise exception 'Capacity ignored'; end if;
  if jsonb_array_length(public.browse_delivery_ads(sender,route||'{"destinationLatitude":10}'))<>0 then raise exception 'Destination coverage ignored'; end if;
  insert into public.blocked_users(blocker_id,blocked_id) values(worker,sender);
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>0 then raise exception 'Reverse block ignored'; end if;
  delete from public.blocked_users where blocker_id=worker;
  perform public.change_delivery_ad_status(worker,ad_id,'paused');
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>0 then raise exception 'Paused ad discoverable'; end if;
  perform public.change_delivery_ad_status(worker,ad_id,'published');
  update public.deliverer_profiles set availability_status='offline' where user_id=worker;
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>0 then raise exception 'Offline deliverer advertised'; end if;
  update public.deliverer_profiles set availability_status='online',verification_status='suspended' where user_id=worker;
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>0 then raise exception 'Suspended deliverer advertised'; end if;
  begin perform public.change_delivery_ad_status(worker,ad_id,'published'); raise exception 'Suspended deliverer resumed ad';
  exception when insufficient_privilege then null; end;
  update public.deliverer_profiles set verification_status='approved' where user_id=worker;
  update public.deliverer_profiles set active_job_count=2 where user_id=worker;
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>0 then raise exception 'Active job count ignored'; end if;
  update public.deliverer_profiles set active_job_count=0 where user_id=worker;
  update public.p2p_ads set availability=jsonb_build_object('from',to_char((now()-interval '2 days') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')||'Z',
    'until',to_char((now()-interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')||'Z') where id=ad_id;
  if jsonb_array_length(public.browse_delivery_ads(sender,route))<>0 then raise exception 'Expired ad discoverable'; end if;
  begin perform public.change_delivery_ad_status(worker,ad_id,'published'); raise exception 'Expired ad resumed';
  exception when raise_exception then if SQLERRM='Expired ad resumed' then raise; end if; end;
  perform public.change_delivery_ad_status(worker,ad_id,'deleted');
  perform public.change_delivery_ad_status(worker,ad_id,'deleted');
  begin perform public.change_delivery_ad_status(worker,ad_id,'published'); raise exception 'Deleted ad resumed';
  exception when raise_exception then if SQLERRM='Deleted ad resumed' then raise; end if; end;
  if has_function_privilege('authenticated','public.save_delivery_ad(uuid,uuid,jsonb,text)','EXECUTE')
    or has_function_privilege('anon','public.browse_delivery_ads(uuid,jsonb)','EXECUTE')
    or has_table_privilege('authenticated','public.p2p_ads','INSERT') then raise exception 'Ad mutation exposed to clients'; end if;
end;
$$;
set local role authenticated;
select set_config('request.jwt.claim.sub','14000000-0000-4000-8000-000000000001',true);
do $$ begin
  if exists(select 1 from public.p2p_ads) then raise exception 'RLS exposes another deliverer ad'; end if;
end; $$;
reset role;
rollback;
