begin;
create table support_attachments (
  id uuid primary key default gen_random_uuid(),
  case_id uuid not null references support_cases(id),
  upload_id uuid not null unique references uploads(id),
  created_at timestamptz not null default now()
);
create index support_attachment_case on support_attachments(case_id,created_at,id);
alter table support_attachments enable row level security;
grant select on support_attachments to authenticated;
create policy reporter_support_attachments on support_attachments for select to authenticated
using(exists(select 1 from support_cases c where c.id=case_id and c.reporter_id=auth.uid()));
commit;
