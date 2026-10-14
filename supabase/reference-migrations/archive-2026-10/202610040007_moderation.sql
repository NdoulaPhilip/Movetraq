begin;
alter table user_reports add column resolution text,add column reviewed_by uuid references profiles(id),add column updated_at timestamptz not null default now();
alter table user_reports add constraint report_not_self check(reporter_id<>reported_user_id),add constraint report_status check(status in ('open','investigating','actioned','dismissed'));
create index user_reports_reporter_created on user_reports(reporter_id,created_at desc);
create index user_reports_status_created on user_reports(status,created_at desc);
grant select on user_reports to authenticated;
create policy own_reports on user_reports for select to authenticated using(reporter_id=auth.uid());
commit;
