begin;
alter table public.payments add column idempotency_key text;
alter table public.payments add column checkout_url text;
create unique index payments_user_idempotency on public.payments(user_id, idempotency_key)
where idempotency_key is not null;

create or replace function public.reserve_wallet_topup(p_user_id uuid, p_amount_minor integer, p_key text, p_reference text)
returns public.payments language plpgsql set search_path = ''
as $$
declare payment public.payments;
begin
  if p_amount_minor is null or p_amount_minor < 10000 or p_amount_minor > 100000000
    or p_key is null or length(p_key) < 16 or length(p_key) > 128
    or p_key !~ '^[A-Za-z0-9-]+$' or p_reference is null then
    raise exception 'Invalid topup request' using errcode = '22023';
  end if;
  perform 1 from public.wallet_accounts where user_id = p_user_id and status = 'active' and currency = 'NGN';
  if not found then raise exception 'Active wallet not found' using errcode = 'P0002'; end if;
  insert into public.payments(user_id, provider, provider_reference, amount_minor, currency, idempotency_key)
  values (p_user_id, 'paystack', p_reference, p_amount_minor, 'NGN', p_key)
  on conflict (user_id, idempotency_key) where idempotency_key is not null do nothing;
  select * into payment from public.payments where user_id = p_user_id and idempotency_key = p_key;
  if payment.amount_minor <> p_amount_minor or payment.provider <> 'paystack' or payment.provider_reference <> p_reference then
    raise exception 'Idempotency key conflicts with another request' using errcode = '22023';
  end if;
  return payment;
end;
$$;

create or replace function public.credit_verified_topup(p_reference text, p_amount_minor integer, p_currency text)
returns public.payments language plpgsql set search_path = ''
as $$
declare payment public.payments; wallet public.wallet_accounts;
begin
  select * into payment from public.payments where provider_reference = p_reference for update;
  if not found then raise exception 'Payment not found' using errcode = 'P0002'; end if;
  if payment.provider <> 'paystack' or payment.order_id is not null or payment.idempotency_key is null
    or payment.amount_minor is distinct from p_amount_minor or payment.currency::text is distinct from p_currency then
    raise exception 'Payment verification mismatch' using errcode = '22023';
  end if;
  if payment.status = 'verified' then return payment; end if;
  if payment.status not in ('created', 'initialized', 'pending') then
    raise exception 'Payment cannot be credited in this state' using errcode = '22023';
  end if;
  select * into wallet from public.wallet_accounts where user_id = payment.user_id and currency = payment.currency for update;
  if not found or wallet.status <> 'active' then raise exception 'Active wallet not found' using errcode = 'P0002'; end if;
  insert into public.wallet_ledger_entries(wallet_id, user_id, type, amount_minor, currency, idempotency_key, provider_reference)
  values (wallet.id, wallet.user_id, 'topup', payment.amount_minor, payment.currency, 'topup:' || payment.id::text, p_reference);
  update public.payments set status = 'verified', verified_at = now() where id = payment.id returning * into payment;
  insert into public.notifications(user_id, type, title, body, data)
  values (payment.user_id, 'wallet_topup', 'Payment received', 'Your wallet top-up has been confirmed.',
    jsonb_build_object('paymentId', payment.id, 'amountMinor', payment.amount_minor, 'currency', payment.currency));
  return payment;
end;
$$;

revoke all on function public.reserve_wallet_topup(uuid, integer, text, text) from public, anon, authenticated;
revoke all on function public.credit_verified_topup(text, integer, text) from public, anon, authenticated;
grant execute on function public.reserve_wallet_topup(uuid, integer, text, text) to service_role;
grant execute on function public.credit_verified_topup(text, integer, text) to service_role;
commit;
