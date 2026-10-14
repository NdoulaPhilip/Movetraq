begin;
insert into auth.users(id,email) values
('13000000-0000-4000-8000-000000000001','super@example.test'),
('13000000-0000-4000-8000-000000000002','target@example.test');
insert into public.user_roles(user_id,role) values ('13000000-0000-4000-8000-000000000001','super_admin');
insert into public.wallet_ledger_entries(wallet_id,user_id,type,amount_minor,idempotency_key)
select id,user_id,'topup',10000,'platform-retention-fixture' from public.wallet_accounts where user_id='13000000-0000-4000-8000-000000000002';
do $$ begin
  if has_function_privilege('authenticated','public.manage_platform_user(uuid,uuid,jsonb,text)','EXECUTE') then raise exception 'Management RPC exposed'; end if;
  begin
    perform public.manage_platform_user('13000000-0000-4000-8000-000000000002','13000000-0000-4000-8000-000000000001','{"roles":["sender"]}','user_updated');
    raise exception 'Non-super actor allowed';
  exception when insufficient_privilege then null; end;
  begin
    perform public.manage_platform_user('13000000-0000-4000-8000-000000000001','13000000-0000-4000-8000-000000000001','{"roles":["sender"]}','user_updated');
    raise exception 'Self privilege change allowed';
  exception when invalid_parameter_value then null; end;
  perform public.manage_platform_user('13000000-0000-4000-8000-000000000001','13000000-0000-4000-8000-000000000002','{"roles":["sender","admin"],"status":"suspended","reason":"Test suspension"}','user_updated');
  if public.account_enabled('13000000-0000-4000-8000-000000000002') then raise exception 'Suspension ineffective'; end if;
  if not exists(select 1 from public.audit_logs where entity_id='13000000-0000-4000-8000-000000000002' and action='user_updated') then raise exception 'Audit missing'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','13000000-0000-4000-8000-000000000002',true);
do $$ begin
  if exists(select 1 from public.profiles) then raise exception 'Suspended admin bypasses RLS'; end if;
end $$;
reset role;
select public.manage_platform_user('13000000-0000-4000-8000-000000000001','13000000-0000-4000-8000-000000000002','{"status":"active","reason":"Reactivated"}','user_updated');
select public.manage_platform_user('13000000-0000-4000-8000-000000000001','13000000-0000-4000-8000-000000000002','{"status":"deactivated","reason":"Retention test"}','user_deactivated');
do $$ begin
  if (select balance_minor from public.wallet_balances where user_id='13000000-0000-4000-8000-000000000002')<>10000 then raise exception 'Ledger lost'; end if;
  if exists(select 1 from public.user_roles where user_id='13000000-0000-4000-8000-000000000002') then raise exception 'Privileges retained'; end if;
  if (select full_name from public.profiles where id='13000000-0000-4000-8000-000000000002')<>'Deactivated account' then raise exception 'Profile not anonymized'; end if;
end $$;
rollback;
