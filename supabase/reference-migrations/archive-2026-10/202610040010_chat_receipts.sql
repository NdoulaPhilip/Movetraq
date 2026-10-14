begin;
alter table conversation_members add column last_delivered_at timestamptz;
drop policy own_membership on conversation_members;
create policy participant_receipts on conversation_members for select to authenticated using(conversation_member(conversation_id));
do $$ begin if exists(select 1 from pg_publication where pubname='supabase_realtime') then alter publication supabase_realtime add table conversation_members;end if;end $$;
commit;
