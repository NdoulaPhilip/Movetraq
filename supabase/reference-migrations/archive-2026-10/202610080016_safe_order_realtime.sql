begin;
-- Status notifications never carry encrypted handover codes or hashes.
create table order_realtime_updates(
 id uuid primary key references orders(id),sender_id uuid not null references profiles(id),
 deliverer_id uuid references profiles(id),status order_status not null,
 payment_status text not null,updated_at timestamptz not null default now()
);
alter table order_realtime_updates enable row level security;
grant select on order_realtime_updates to authenticated;
create policy participant_order_updates on order_realtime_updates for select to authenticated using(sender_id=auth.uid() or deliverer_id=auth.uid());
insert into order_realtime_updates(id,sender_id,deliverer_id,status,payment_status) select id,sender_id,deliverer_id,status,payment_status from orders;
create function publish_order_status() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into order_realtime_updates(id,sender_id,deliverer_id,status,payment_status,updated_at) values(new.id,new.sender_id,new.deliverer_id,new.status,new.payment_status,now())
 on conflict(id) do update set sender_id=excluded.sender_id,deliverer_id=excluded.deliverer_id,status=excluded.status,payment_status=excluded.payment_status,updated_at=excluded.updated_at;
 return new;
end;
$$;
revoke all on function publish_order_status() from public,anon,authenticated;
create trigger order_status_published after insert or update on orders for each row execute function publish_order_status();
do $$
declare safe_columns text;
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  if exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='orders') then
   alter publication supabase_realtime drop table public.orders;
  end if;
  alter publication supabase_realtime add table public.order_realtime_updates;
 end if;
 -- Apply actual column privileges as well as participant RLS.
 select string_agg(quote_ident(attname),',' order by attnum) into safe_columns from pg_attribute
 where attrelid='public.orders'::regclass and attnum>0 and not attisdropped and attname not in ('handover_hash','handover_ciphertext');
 revoke select on orders from authenticated;
 execute 'grant select ('||safe_columns||') on orders to authenticated';
end $$;
commit;
