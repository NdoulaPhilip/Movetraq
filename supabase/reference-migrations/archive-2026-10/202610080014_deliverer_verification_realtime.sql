begin;
-- Owner-only RLS remains in force. Publish eligibility changes, not documents,
-- identity details, delivery-area coordinates or live deliverer locations.
do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime')
    and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='deliverers') then
  alter publication supabase_realtime add table public.deliverers(user_id,verification_status,updated_at);
 end if;
end $$;
commit;
