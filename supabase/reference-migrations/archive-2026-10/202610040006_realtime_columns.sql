begin;
-- Never publish encrypted recipient codes or their verification hashes.
do $$
declare safe_columns text;
begin
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    select string_agg(quote_ident(attname),',' order by attnum) into safe_columns
    from pg_attribute where attrelid='public.orders'::regclass and attnum>0 and not attisdropped
      and attname not in ('handover_hash','handover_ciphertext');
    alter publication supabase_realtime drop table public.orders;
    execute 'alter publication supabase_realtime add table public.orders ('||safe_columns||')';
  end if;
end $$;
commit;
