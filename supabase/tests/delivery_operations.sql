begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('50000000-0000-4000-8000-000000000001','operations-sender@example.test','{}'),
 ('50000000-0000-4000-8000-000000000002','operations-finance@example.test','{}');
insert into public.user_roles(user_id,role) values('50000000-0000-4000-8000-000000000002','finance');
do $$
declare sender uuid:='50000000-0000-4000-8000-000000000001'; finance uuid:='50000000-0000-4000-8000-000000000002';
 address_id uuid; rule public.pricing_rules; preferences public.user_preferences;
begin
  insert into public.saved_addresses(user_id,label,address) values(sender,'Home','Ikeja Lagos') returning id into address_id;
  preferences:=public.select_saved_address(sender,address_id);
  if preferences.selected_address_id<>address_id then raise exception 'Address selection not persisted'; end if;
  begin
    perform public.select_saved_address(finance,address_id);
    raise exception 'Selected another account address';
  exception when no_data_found then null;
  end;
  delete from public.saved_addresses where id=address_id;
  if (select selected_address_id from public.user_preferences where user_id=sender) is not null then raise exception 'Deleted selection not cleared'; end if;
  begin
    perform public.activate_pricing_rule(sender,'express','{}');
    raise exception 'Sender activated pricing';
  exception when insufficient_privilege then null;
  end;
  rule:=public.activate_pricing_rule(finance,'express','{"minimumMinor":10000}');
  perform public.activate_pricing_rule(finance,'express','{"minimumMinor":20000}');
  if (select count(*) from public.pricing_rules where service_type='express' and enabled)<>1 then raise exception 'Multiple active tariffs'; end if;
  if (select enabled from public.pricing_rules where id=rule.id) then raise exception 'Previous tariff still active'; end if;
  begin
    update public.pricing_rules set configuration='{}' where id=rule.id;
    raise exception 'Old tariff snapshot modified';
  exception when insufficient_privilege then null;
  end;
  if (select count(*) from public.audit_logs where admin_id=finance and action='pricing_activated')<>2 then raise exception 'Tariff audit missing'; end if;
  if has_function_privilege('authenticated','public.activate_pricing_rule(uuid,public.service_type,jsonb)','EXECUTE') then raise exception 'Client can activate tariffs directly'; end if;
end;
$$;
rollback;
