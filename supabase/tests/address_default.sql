begin;
insert into auth.users(id,email) values
 ('12000000-0000-4000-8000-000000000001','default-one@example.test'),
 ('12000000-0000-4000-8000-000000000002','default-two@example.test');

do $$
declare first_address public.saved_addresses; second_address public.saved_addresses;
begin
  if has_function_privilege('authenticated','public.set_default_account_address(uuid,uuid)','EXECUTE')
     or has_function_privilege('anon','public.set_default_account_address(uuid,uuid)','EXECUTE') then
    raise exception 'Default-address RPC is exposed';
  end if;
  first_address := public.save_account_address('12000000-0000-4000-8000-000000000001',null,
    '{"label":"Home","address":"Ikeja Lagos","latitude":6.6,"longitude":3.3,"is_default":true}');
  second_address := public.save_account_address(first_address.user_id,null,
    '{"label":"Office","address":"Yaba Lagos","latitude":6.5,"longitude":3.4}');
  perform public.set_default_account_address(first_address.user_id,second_address.id);
  perform public.set_default_account_address(first_address.user_id,second_address.id);
  if (select count(*) from public.saved_addresses where user_id=first_address.user_id and is_default) <> 1 then
    raise exception 'Default uniqueness failed';
  end if;
  if not (select is_default from public.saved_addresses where id=second_address.id) then
    raise exception 'Requested address was not marked default';
  end if;
  if (select address from public.saved_addresses where id=second_address.id) <> 'Yaba Lagos' then
    raise exception 'Default change overwrote address fields';
  end if;
  begin
    perform public.set_default_account_address('12000000-0000-4000-8000-000000000002',second_address.id);
    raise exception 'Cross-account default change was allowed';
  exception when no_data_found then null;
  end;
  if not (select is_default from public.saved_addresses where id=second_address.id) then
    raise exception 'Rejected update changed default';
  end if;
end;
$$;
rollback;
