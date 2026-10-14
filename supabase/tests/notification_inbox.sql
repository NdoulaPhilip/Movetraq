begin;
insert into auth.users(id, email, raw_user_meta_data) values
  ('10000000-0000-4000-8000-000000000001', 'inbox-one@example.test', '{}'),
  ('10000000-0000-4000-8000-000000000002', 'inbox-two@example.test', '{}');

insert into public.notifications(user_id, type, title, body, read_at) values
  ('10000000-0000-4000-8000-000000000001', 'order', 'New order', 'Unread', null),
  ('10000000-0000-4000-8000-000000000001', 'order', 'Old order', 'Read', '2026-01-01T00:00:00Z'),
  ('10000000-0000-4000-8000-000000000002', 'order', 'Other order', 'Unread', null);

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-4000-8000-000000000001', true);
do $$
begin
  if (select count(*) from public.notifications) <> 2 then
    raise exception 'Notification reads leaked another account';
  end if;
  if (select count(*) from public.notifications where read_at is null) <> 1 then
    raise exception 'Unread notification count is incorrect';
  end if;
  update public.notifications set read_at = now() where read_at is null;
  if (select read_at from public.notifications where title = 'Old order') <> '2026-01-01T00:00:00Z'::timestamptz then
    raise exception 'Existing read timestamp was overwritten';
  end if;
  delete from public.notifications;
  if exists (select 1 from public.notifications) then
    raise exception 'Own notification clear failed';
  end if;
end;
$$;
reset role;
do $$
begin
  if (select count(*) from public.notifications) <> 1
    or not exists (select 1 from public.notifications
      where user_id = '10000000-0000-4000-8000-000000000002' and read_at is null) then
    raise exception 'Notification changes affected another account';
  end if;
end;
$$;
rollback;
