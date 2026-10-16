begin;
do $$
declare result jsonb; point jsonb;
begin
  if has_function_privilege('authenticated','public.mobile_location_command(text,text,jsonb)','EXECUTE')
    or has_table_privilege('authenticated','public.mobile_saved_addresses','SELECT') then
    raise exception 'Mobile location data exposed to clients';
  end if;
  perform public.mobile_location_command('user_address_owner','save-address',
    '{"id":"address_fixture","label":"Home","address":"Fixture street","latitude":6.5,"longitude":3.4,"isDefault":true}');
  perform public.mobile_location_command('user_address_owner','save-address',
    '{"id":"address_second","label":"Work","address":"Second street","latitude":6.6,"longitude":3.5,"isDefault":true}');
  if (select count(*) from public.mobile_saved_addresses where legacy_user_id='user_address_owner' and is_default)<>1 then
    raise exception 'Account has multiple default addresses';
  end if;
  result:=public.mobile_location_command('user_address_other','addresses');
  if jsonb_array_length(result->'addresses')<>0 then raise exception 'Cross-account address read allowed'; end if;
  begin
    perform public.mobile_location_command('user_address_other','save-address',
      '{"id":"address_fixture","label":"Stolen","address":"Other street","latitude":6,"longitude":3}');
    raise exception 'Cross-account address update allowed';
  exception when raise_exception then
    if sqlerrm<>'Address not found' then raise; end if;
  end;
  perform public.mobile_location_command('user_address_other','delete-address','{"id":"address_fixture"}');
  if not exists(select 1 from public.mobile_saved_addresses where id='address_fixture') then
    raise exception 'Cross-account deletion allowed';
  end if;
  point:=jsonb_build_object('orderId','order_location_fixture','senderId','user_address_owner',
    'latitude',6.5,'longitude',3.4,'accuracy',10,'capturedAt',now());
  begin
    perform public.mobile_location_command('user_location_deliverer','location',point);
    raise exception 'Unapproved location write allowed';
  exception when raise_exception then
    if sqlerrm<>'Deliverer approval required' then raise; end if;
  end;
  insert into public.verification_applications(legacy_user_id,status) values('user_location_deliverer','approved');
  perform public.mobile_location_command('user_location_deliverer','location',point);
  result:=public.mobile_location_command('user_address_owner','read-location','{"orderId":"order_location_fixture"}');
  if result->'location'->>'deliverer_id'<>'user_location_deliverer' then raise exception 'Sender tracking missing'; end if;
  result:=public.mobile_location_command('user_address_other','read-location','{"orderId":"order_location_fixture"}');
  if result->'location'<>'null'::jsonb then raise exception 'Cross-account tracking allowed'; end if;
  begin
    perform public.mobile_location_command('user_location_deliverer','location',
      point||jsonb_build_object('capturedAt',now()-interval '3 minutes'));
    raise exception 'Stale GPS accepted';
  exception when raise_exception then
    if sqlerrm<>'GPS sample is not current' then raise; end if;
  end;
  perform public.mobile_location_command('user_location_deliverer','location',
    point||jsonb_build_object('capturedAt',now()-interval '1 second','latitude',7));
  if (select latitude from public.mobile_delivery_locations where order_id='order_location_fixture')<>6.5 then
    raise exception 'Older GPS replaced the latest point';
  end if;
  update public.mobile_delivery_locations set captured_at=now()-interval '3 minutes' where order_id='order_location_fixture';
  result:=public.mobile_location_command('user_address_owner','read-location','{"orderId":"order_location_fixture"}');
  if result->'location'<>'null'::jsonb then raise exception 'Stale location exposed as live'; end if;
end $$;
rollback;
