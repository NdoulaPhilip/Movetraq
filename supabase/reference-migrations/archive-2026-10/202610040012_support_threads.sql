begin;
alter table support_notes add column client_note_id uuid;
create unique index support_note_retry on support_notes(author_id,client_note_id) where client_note_id is not null;
create index support_note_history on support_notes(case_id,created_at desc,id desc);
grant select on support_notes to authenticated;
create policy reporter_public_notes on support_notes for select to authenticated using (
  not internal and exists(select 1 from support_cases c where c.id=case_id and c.reporter_id=auth.uid())
);
commit;
