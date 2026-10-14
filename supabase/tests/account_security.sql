-- Run against a disposable Supabase database after both migrations.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
  ('10000000-0000-4000-8000-000000000001', 'account-one@example.test', '{"full_name":"Account One","role":"super_admin"}'),
  ('10000000-0000-4000-8000-000000000002', 'account-two@example.test', '{"full_name":"Account Two"}');

do $$
declare first_address public.saved_addresses; second_address public.saved_addresses;
begin
  if (select count(*) from public.user_roles where user_id = '10000000-0000-4000-8000-000000000001') <> 1
    or not exists (select 1 from public.user_roles where user_id = '10000000-0000-4000-8000-000000000001' and role = 'sender') then
    raise exception 'Signup metadata must not grant privileged roles';
  end if;
  if not exists (select 1 from public.wallet_accounts where user_id = '10000000-0000-4000-8000-000000000001') then
    raise exception 'Signup must provision a wallet';
  end if;
  if has_column_privilege('authenticated', 'public.profiles', 'verification_status', 'UPDATE')
    or has_column_privilege('authenticated', 'public.profiles', 'active_role', 'UPDATE')
    or has_table_privilege('authenticated', 'public.user_roles', 'INSERT')
    or has_table_privilege('authenticated', 'public.verification_applications', 'UPDATE')
    or has_column_privilege('authenticated', 'public.security_settings', 'pin_hash', 'SELECT') then
    raise exception 'Protected account fields exposed';
  end if;
  if has_function_privilege('authenticated', 'public.save_account_address(uuid,uuid,jsonb)', 'EXECUTE') then
    raise exception 'Service-only RPC is exposed';
  end if;
  first_address := public.save_account_address('10000000-0000-4000-8000-000000000001', null,
    '{"label":"Home","address":"Ikeja Lagos","latitude":6.6,"longitude":3.3,"is_default":true}');
  second_address := public.save_account_address('10000000-0000-4000-8000-000000000001', null,
    '{"label":"Office","address":"Yaba Lagos","latitude":6.5,"longitude":3.4,"is_default":true}');
  if (select count(*) from public.saved_addresses where user_id = first_address.user_id and is_default) <> 1 then
    raise exception 'Default address must be unique';
  end if;
  begin
    perform public.save_account_address('10000000-0000-4000-8000-000000000002', first_address.id,
      '{"label":"Other","address":"Other Lagos","latitude":6.5,"longitude":3.4}');
    raise exception 'Cross-account address update was allowed';
  exception when no_data_found then null;
  end;
end;
$$;

insert into public.wallet_ledger_entries(wallet_id, user_id, type, amount_minor, idempotency_key)
select id, user_id, 'topup', 1000, 'account-test-one' from public.wallet_accounts
where user_id = '10000000-0000-4000-8000-000000000001';
insert into public.wallet_ledger_entries(wallet_id, user_id, type, amount_minor, idempotency_key)
select id, user_id, 'topup', 2000, 'account-test-two' from public.wallet_accounts
where user_id = '10000000-0000-4000-8000-000000000002';

do $$
begin
  begin
    update public.wallet_ledger_entries set amount_minor = 5000 where idempotency_key = 'account-test-one';
    raise exception 'Ledger mutation was allowed';
  exception when object_not_in_prerequisite_state then null;
  end;
end;
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
do $$
begin
  if (select count(*) from public.wallet_balances) <> 1 then raise exception 'Wallet view leaked another account'; end if;
  if public.is_admin() then raise exception 'Sender unexpectedly has admin access'; end if;
end;
$$;
reset role;
rollback;
