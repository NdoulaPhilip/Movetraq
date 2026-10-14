begin;
-- Supabase's realtime gateway can return complete source rows even when the
-- publication specifies columns. Use a minimal owner-only projection table.
create table deliverer_verification_updates(
 user_id uuid primary key references deliverers(user_id),
 verification_status verification_status not null,
 updated_at timestamptz not null default now()
);
alter table deliverer_verification_updates enable row level security;
grant select on deliverer_verification_updates to authenticated;
create policy own_eligibility_updates on deliverer_verification_updates for select to authenticated using(user_id=auth.uid());
insert into deliverer_verification_updates(user_id,verification_status) select user_id,verification_status from deliverers;
create function publish_deliverer_eligibility() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into deliverer_verification_updates(user_id,verification_status,updated_at) values(new.user_id,new.verification_status,now())
 on conflict(user_id) do update set verification_status=excluded.verification_status,updated_at=excluded.updated_at;
 return new;
end;
$$;
revoke all on function publish_deliverer_eligibility() from public,anon,authenticated;
create trigger deliverer_eligibility_changed after insert or update of verification_status on deliverers for each row execute function publish_deliverer_eligibility();
do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  if exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='deliverers') then
   alter publication supabase_realtime drop table public.deliverers;
  end if;
  alter publication supabase_realtime add table public.deliverer_verification_updates;
 end if;
end $$;
commit;
