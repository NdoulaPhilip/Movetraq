begin;
select pg_advisory_xact_lock(hashtext('movetraq-legacy-payment-schema'));
create table if not exists legacy_wallet_ledger (
  id text primary key, user_id text not null references users(uid), kind text not null,
  amount_minor bigint not null, balance_after_minor bigint not null check(balance_after_minor>=0),
  provider_reference text unique, created_at timestamptz not null default now()
);
create table if not exists legacy_wallet_topups (
  reference text primary key, user_id text not null references users(uid), request_key text not null,
  amount_minor integer not null check(amount_minor between 10000 and 100000000),
  currency text not null default 'NGN' check(currency='NGN'),
  status text not null default 'created' check(status in ('created','initialized','verified')),
  checkout_url text, created_at timestamptz not null default now(), verified_at timestamptz,
  unique(user_id,request_key)
);
revoke all on legacy_wallet_ledger,legacy_wallet_topups from public;
create or replace function legacy_immutable_wallet_record() returns trigger language plpgsql as $$
begin raise exception 'Wallet ledger entries are immutable' using errcode='42501'; end; $$;
drop trigger if exists legacy_wallet_immutable on legacy_wallet_ledger;
create trigger legacy_wallet_immutable before update or delete on legacy_wallet_ledger
  for each row execute function legacy_immutable_wallet_record();
drop trigger if exists legacy_wallet_no_truncate on legacy_wallet_ledger;
create trigger legacy_wallet_no_truncate before truncate on legacy_wallet_ledger
  for each statement execute function legacy_immutable_wallet_record();
create or replace function legacy_open_wallet() returns trigger language plpgsql as $$
begin
  insert into legacy_wallet_ledger(id,user_id,kind,amount_minor,balance_after_minor)
    values('opening:'||new.uid,new.uid,'opening',round(coalesce((new.data->>'walletBalance')::numeric,0)*100),
      round(coalesce((new.data->>'walletBalance')::numeric,0)*100)) on conflict(id) do nothing;
  return new;
end; $$;
drop trigger if exists legacy_wallet_opening on users;
create trigger legacy_wallet_opening after insert on users for each row execute function legacy_open_wallet();
create or replace function legacy_guard_wallet_snapshot() returns trigger language plpgsql as $$
begin
  if old.data ? 'walletRevision' and (
    coalesce((new.data->>'walletRevision')::bigint,-1)<(old.data->>'walletRevision')::bigint
    or (coalesce((new.data->>'walletBalance')::numeric,0)<>coalesce((old.data->>'walletBalance')::numeric,0)
      and coalesce((new.data->>'walletRevision')::bigint,-1)<=(old.data->>'walletRevision')::bigint)) then
    raise exception 'Stale wallet snapshot; retry the request' using errcode='40001';
  end if;
  return new;
end; $$;
drop trigger if exists legacy_wallet_snapshot_guard on users;
create trigger legacy_wallet_snapshot_guard before update on users for each row execute function legacy_guard_wallet_snapshot();
create or replace function legacy_guard_payment_record() returns trigger language plpgsql as $$
begin
  if new.reference<>old.reference or new.user_id<>old.user_id or new.request_key<>old.request_key
    or new.amount_minor<>old.amount_minor or new.currency<>old.currency
    or (old.status='verified' and new is distinct from old) then
    raise exception 'Payment identity and verified records are immutable' using errcode='42501';
  end if;
  return new;
end; $$;
drop trigger if exists legacy_payment_guard on legacy_wallet_topups;
create trigger legacy_payment_guard before update on legacy_wallet_topups for each row execute function legacy_guard_payment_record();
update users set data=jsonb_set(data,'{walletRevision}','0') where not data ? 'walletRevision';
insert into legacy_wallet_ledger(id,user_id,kind,amount_minor,balance_after_minor)
  select 'opening:'||uid,uid,'opening',round(coalesce((data->>'walletBalance')::numeric,0)*100),
    round(coalesce((data->>'walletBalance')::numeric,0)*100) from users on conflict(id) do nothing;
commit;
