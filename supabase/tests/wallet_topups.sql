begin;
insert into auth.users(id, email, raw_user_meta_data)
values ('20000000-0000-4000-8000-000000000001', 'wallet-test@example.test', '{"full_name":"Wallet Test"}');
do $$
declare payment public.payments; duplicate public.payments;
begin
  payment := public.reserve_wallet_topup('20000000-0000-4000-8000-000000000001', 10000, 'wallet-test-key-0001', 'mt-wallet-test-reference');
  duplicate := public.reserve_wallet_topup('20000000-0000-4000-8000-000000000001', 10000, 'wallet-test-key-0001', 'mt-wallet-test-reference');
  if payment.id <> duplicate.id then raise exception 'Reservation is not idempotent'; end if;
  begin
    perform public.reserve_wallet_topup('20000000-0000-4000-8000-000000000001', 20000, 'wallet-test-key-0001', 'mt-wallet-test-reference');
    raise exception 'Conflicting request key accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.credit_verified_topup('mt-wallet-test-reference', 20000, 'NGN');
    raise exception 'Incorrect provider amount accepted';
  exception when invalid_parameter_value then null;
  end;
  begin
    perform public.credit_verified_topup('mt-wallet-test-reference', null, null);
    raise exception 'Null provider amount accepted';
  exception when invalid_parameter_value then null;
  end;
  perform public.credit_verified_topup('mt-wallet-test-reference', 10000, 'NGN');
  perform public.credit_verified_topup('mt-wallet-test-reference', 10000, 'NGN');
  if (select count(*) from public.wallet_ledger_entries where user_id = payment.user_id) <> 1 then
    raise exception 'Duplicate webhook credited twice';
  end if;
  if (select balance_minor from public.wallet_balances where user_id = payment.user_id) <> 10000 then
    raise exception 'Incorrect credited wallet balance';
  end if;
  if has_function_privilege('authenticated', 'public.credit_verified_topup(text,integer,text)', 'EXECUTE') then
    raise exception 'Client can credit a wallet directly';
  end if;
end;
$$;
rollback;
