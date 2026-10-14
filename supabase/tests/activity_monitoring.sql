begin;
insert into auth.users(id,email) values
('14000000-0000-4000-8000-000000000001','monitor-sender@example.test'),
('14000000-0000-4000-8000-000000000002','monitor-courier@example.test');
insert into public.orders(id,public_ref,sender_id,deliverer_id,service_type,pickup_address,destination_address)
values('14000000-0000-4000-8000-000000000003','MONITOR-TEST','14000000-0000-4000-8000-000000000001','14000000-0000-4000-8000-000000000002','p2p','Pickup','Destination');
insert into public.conversations(id,order_id,sender_id,deliverer_id)
values('14000000-0000-4000-8000-000000000004','14000000-0000-4000-8000-000000000003','14000000-0000-4000-8000-000000000001','14000000-0000-4000-8000-000000000002');
insert into public.messages(id,conversation_id,sender_id,body)
values('14000000-0000-4000-8000-000000000005','14000000-0000-4000-8000-000000000004','14000000-0000-4000-8000-000000000001','PRIVATE-MESSAGE-MUST-NOT-LEAK');
update public.messages set delivered_at=now() where id='14000000-0000-4000-8000-000000000005';
update public.messages set read_at=now() where id='14000000-0000-4000-8000-000000000005';
insert into public.payments(user_id,provider,provider_reference,status,amount_minor,webhook_payload)
values('14000000-0000-4000-8000-000000000001','paystack','MONITOR-FAILED','failed',10000,'{"private":"SECRET-PAYMENT-PAYLOAD"}');
select public.record_account_login('14000000-0000-4000-8000-000000000001');
do $$ declare metrics jsonb; begin
  if not exists(select 1 from public.platform_activity where event_type='message_sent' and actor_id='14000000-0000-4000-8000-000000000001' and order_id='14000000-0000-4000-8000-000000000003') then raise exception 'Chat actor/order missing'; end if;
  if not exists(select 1 from public.platform_activity where event_type='message_read') then raise exception 'Read status missing'; end if;
  if not exists(select 1 from public.platform_activity where reference='MONITOR-FAILED' and outcome='failed' and category='finance') then raise exception 'Financial failure missing'; end if;
  if exists(select 1 from public.platform_activity where to_jsonb(platform_activity)::text like '%PRIVATE-MESSAGE%' or to_jsonb(platform_activity)::text like '%SECRET-PAYMENT%') then raise exception 'Sensitive content leaked'; end if;
  if has_table_privilege('authenticated','public.platform_activity','SELECT') then raise exception 'Direct activity access exposed'; end if;
  metrics:=public.activity_metrics();
  if (metrics->>'totalOrders')::int<>1 or (metrics->>'failedTransactions')::int<>1 or jsonb_array_length(metrics->'series')<>14 then raise exception 'Metrics incorrect'; end if;
  begin
    update public.platform_activity set description='tampered';
    raise exception 'Activity update allowed';
  exception when sqlstate '55000' then null; end;
  begin
    delete from public.platform_activity;
    raise exception 'Activity delete allowed';
  exception when sqlstate '55000' then null; end;
  begin
    truncate public.platform_activity;
    raise exception 'Activity truncate allowed';
  exception when sqlstate '55000' then null; end;
end $$;
savepoint aborted_change;
insert into public.notifications(user_id,type,title,body) values('14000000-0000-4000-8000-000000000001','aborted-test','Private title','Private body');
rollback to aborted_change;
do $$ begin
  if exists(select 1 from public.platform_activity where entity='notifications') then raise exception 'Rolled-back notification event retained'; end if;
end $$;
rollback;
