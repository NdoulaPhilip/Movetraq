begin;
create trigger immutable_platform_ledger_truncate before truncate on public.platform_ledger_entries
for each statement execute function public.reject_ledger_mutation();
create trigger immutable_audit_truncate before truncate on public.audit_logs
for each statement execute function public.reject_ledger_mutation();
create function public.guard_pricing_snapshot() returns trigger language plpgsql set search_path='' as $$
begin
  if new.id is distinct from old.id or new.service_type is distinct from old.service_type
    or new.configuration is distinct from old.configuration or new.created_at is distinct from old.created_at then
    raise exception 'Pricing snapshots are immutable; activate a new tariff version' using errcode='42501';
  end if;
  return new;
end;
$$;
revoke all on function public.guard_pricing_snapshot() from public,anon,authenticated;
create trigger immutable_pricing_snapshot before update on public.pricing_rules
for each row execute function public.guard_pricing_snapshot();
commit;
