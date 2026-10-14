begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('30000000-0000-4000-8000-000000000001','delivery-sender@example.test','{}'),
 ('30000000-0000-4000-8000-000000000002','delivery-courier@example.test','{}'),
 ('30000000-0000-4000-8000-000000000003','delivery-stranger@example.test','{}');
insert into public.user_roles(user_id,role) values('30000000-0000-4000-8000-000000000003','support');
insert into public.user_roles(user_id,role) values('30000000-0000-4000-8000-000000000002','deliverer');
insert into public.deliverer_profiles(user_id,transport_type,verification_status,availability_status,delivery_area,capacity,service_preferences)
values('30000000-0000-4000-8000-000000000002','van','approved','online',
 '{"latitude":6.6,"longitude":3.3,"radiusMeters":20000}','{"maxWeightKg":1000,"maxActiveJobs":2}',array['p2p','express','errand','big_move']::public.service_type[]);
insert into public.wallet_ledger_entries(wallet_id,user_id,type,amount_minor,idempotency_key)
select id,user_id,'topup',1000000,'delivery-fixture-topup' from public.wallet_accounts where user_id='30000000-0000-4000-8000-000000000001';
create function pg_temp.quote_for(service public.service_type) returns uuid language plpgsql as $$
declare rule uuid; quote uuid;
begin
  insert into public.pricing_rules(service_type,configuration) values(service,'{}') returning id into rule;
  insert into public.delivery_quotes(user_id,service_type,pricing_rule_id,input,route,pricing_breakdown,total_amount_minor,platform_fee_minor,deliverer_payout_minor,expires_at)
  values('30000000-0000-4000-8000-000000000001',service,rule,
   '{"pickup":{"address":"Ikeja Lagos","latitude":6.6,"longitude":3.3},"destination":{"address":"Yaba Lagos","latitude":6.5,"longitude":3.4},"recipient":{"name":"Recipient","phone":"+2348012345678"},"parcel":{"description":"Test parcel","weightKg":1},"serviceDetails":{}}',
   '{"distanceMeters":12000,"durationSeconds":1200}','{}',100000,10000,90000,now()+interval '1 hour') returning id into quote;
  return quote;
end;
$$;
do $$
declare sender uuid:='30000000-0000-4000-8000-000000000001'; courier uuid:='30000000-0000-4000-8000-000000000002';
 stranger uuid:='30000000-0000-4000-8000-000000000003'; quote uuid; delivery public.orders; retry public.orders;
 state jsonb; code text; step text; conversation uuid; message public.messages; jobs jsonb;
begin
  quote:=pg_temp.quote_for('p2p');
  delivery:=public.create_quoted_order(sender,quote,'delivery-key-one-0001');
  retry:=public.create_quoted_order(sender,quote,'delivery-key-one-0001');
  if delivery.id<>retry.id then raise exception 'Order creation is not idempotent'; end if;
  if delivery.total_amount_minor<>100000 or delivery.recipient_name<>'Recipient' then raise exception 'Quote not copied to order'; end if;
  begin
    perform public.execute_delivery_command(stranger,delivery.id,'fund','{}');
    raise exception 'Another account funded the order';
  exception when insufficient_privilege then null;
  end;
  perform public.execute_delivery_command(sender,delivery.id,'request_payment','{}');
  perform public.execute_delivery_command(sender,delivery.id,'fund','{}');
  perform public.execute_delivery_command(sender,delivery.id,'fund','{}');
  if (select balance_minor from public.wallet_balances where user_id=sender)<>900000 then raise exception 'Funding debited more than once'; end if;
  if (select status from public.escrows where order_id=delivery.id)<>'held' then raise exception 'Funds are not protected'; end if;
  jobs:=public.eligible_delivery_jobs(courier,30,0);
  if jsonb_array_length(jobs)<>1 or jobs->0 ? 'recipient_phone' then raise exception 'Job eligibility/recipient privacy failed'; end if;
  if jsonb_array_length(public.quote_deliverer_candidates(sender,quote))<>1 then raise exception 'Eligible candidate missing'; end if;
  update public.deliverer_profiles set availability_status='offline' where user_id=courier;
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Offline courier eligible'; end if;
  update public.deliverer_profiles set availability_status='online',verification_status='suspended' where user_id=courier;
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Suspended courier eligible'; end if;
  update public.deliverer_profiles set verification_status='approved',active_job_count=2 where user_id=courier;
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Full courier eligible'; end if;
  update public.deliverer_profiles set active_job_count=0,service_preferences=array['express']::public.service_type[] where user_id=courier;
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Service preference ignored'; end if;
  update public.deliverer_profiles set service_preferences=array['p2p','express','errand','big_move']::public.service_type[],capacity='{"maxWeightKg":0,"maxActiveJobs":2}' where user_id=courier;
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Weight capacity ignored'; end if;
  update public.deliverer_profiles set capacity='{"maxWeightKg":1000,"maxActiveJobs":2}',delivery_area='{"latitude":0,"longitude":0,"radiusMeters":100}' where user_id=courier;
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Coverage ignored'; end if;
  update public.deliverer_profiles set delivery_area='{"latitude":6.6,"longitude":3.3,"radiusMeters":20000}' where user_id=courier;
  insert into public.blocked_users(blocker_id,blocked_id) values(sender,courier);
  if public.deliverer_is_eligible(courier,delivery) then raise exception 'Blocked relationship eligible'; end if;
  delete from public.blocked_users where blocker_id=sender and blocked_id=courier;
  begin
    perform public.execute_delivery_command(courier,delivery.id,'accept','{}');
    raise exception 'P2P assignment bypassed sender confirmation';
  exception when raise_exception then
    if sqlerrm='P2P assignment bypassed sender confirmation' then raise; end if;
  end;
  perform public.execute_delivery_command(courier,delivery.id,'offer','{}');
  perform public.execute_delivery_command(sender,delivery.id,'assign',jsonb_build_object('delivererId',courier));
  perform public.execute_delivery_command(courier,delivery.id,'accept','{}');
  select id into conversation from public.conversations where order_id=delivery.id and closed_at is null;
  message:=public.send_order_message(sender,delivery.id,'{"body":"Pickup ready","clientMessageId":"30000000-0000-4000-8000-000000000010"}');
  perform public.send_order_message(sender,delivery.id,'{"body":"Pickup ready","clientMessageId":"30000000-0000-4000-8000-000000000010"}');
  if (select count(*) from public.messages where conversation_id=conversation)<>1 then raise exception 'Message retry duplicated history'; end if;
  if public.order_message_unread_count(sender)<>0 or public.order_message_unread_count(courier)<>1 then raise exception 'Unread count incorrect'; end if;
  perform public.mark_order_messages_read(sender,delivery.id);
  if public.order_message_unread_count(courier)<>1 then raise exception 'Sender marked own message read'; end if;
  perform public.mark_order_messages_read(courier,delivery.id);
  if public.order_message_unread_count(courier)<>0 then raise exception 'Recipient read receipt missing'; end if;
  begin
    perform public.send_order_message(stranger,delivery.id,'{"body":"Intruder","clientMessageId":"30000000-0000-4000-8000-000000000011"}');
    raise exception 'Outsider sent a message';
  exception when insufficient_privilege then null;
  end;
  perform public.record_delivery_location(courier,delivery.id,jsonb_build_object('latitude',6.6,'longitude',3.3,'accuracyMeters',10,'capturedAt',now()));
  if public.latest_delivery_location(sender,delivery.id) is null then raise exception 'Sender cannot see active location'; end if;
  begin
    perform public.execute_delivery_command(courier,delivery.id,'picked_up','{}');
    raise exception 'Delivery skipped pickup stages';
  exception when raise_exception then
    if sqlerrm='Delivery skipped pickup stages' then raise; end if;
  end;
  foreach step in array array['heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff'] loop
    perform public.execute_delivery_command(courier,delivery.id,step,'{}');
  end loop;
  code:=public.sender_handover_code(sender,delivery.id)->>'code';
  begin
    perform public.sender_handover_code(courier,delivery.id);
    raise exception 'Courier read sender handover secret';
  exception when insufficient_privilege then null;
  end;
  state:=public.execute_delivery_command(courier,delivery.id,'handover',jsonb_build_object('recipientName','Recipient','code',case when code='000000' then '000001' else '000000' end));
  if state->>'error'<>'INVALID_HANDOVER_CODE' or (select attempts from public.handover_credentials where order_id=delivery.id)<>1 then
    raise exception 'Invalid handover attempt was not recorded'; end if;
  perform public.execute_delivery_command(courier,delivery.id,'handover',jsonb_build_object('recipientName','Recipient','code',code));
  if (select status from public.orders where id=delivery.id)<>'awaiting_confirmation'
    or (select status from public.escrows where order_id=delivery.id)<>'held' then raise exception 'P2P released before sender confirmation'; end if;
  if exists(select 1 from public.delivery_locations where order_id=delivery.id) then raise exception 'Location retained after handover'; end if;
  perform public.execute_delivery_command(sender,delivery.id,'confirm_receipt','{}');
  perform public.execute_delivery_command(sender,delivery.id,'confirm_receipt','{}');
  if (select balance_minor from public.wallet_balances where user_id=courier)<>90000 then raise exception 'Incorrect or duplicated earnings'; end if;
  if (select count(*) from public.platform_ledger_entries where order_id=delivery.id)<>1 then raise exception 'Platform fee duplicated'; end if;
  if (select active_job_count from public.deliverer_profiles where user_id=courier)<>0 then raise exception 'Active count not decremented'; end if;
  if jsonb_array_length(public.order_chat_history(courier,delivery.id,30,0))<>1 then raise exception 'Completed history not readable'; end if;
  begin
    perform public.send_order_message(sender,delivery.id,'{"body":"After completion","clientMessageId":"30000000-0000-4000-8000-000000000012"}');
    raise exception 'Completed conversation accepted new messages';
  exception when insufficient_privilege then null;
  end;

  delivery:=public.create_quoted_order(sender,pg_temp.quote_for('express'),'delivery-key-two-0002');
  perform public.execute_delivery_command(sender,delivery.id,'request_payment','{}');
  perform public.execute_delivery_command(sender,delivery.id,'fund','{}');
  perform public.execute_delivery_command(sender,delivery.id,'cancel','{"reason":"Change of plan"}');
  perform public.execute_delivery_command(sender,delivery.id,'cancel','{"reason":"Change of plan"}');
  if (select balance_minor from public.wallet_balances where user_id=sender)<>900000 then raise exception 'Cancellation refund incorrect'; end if;

  delivery:=public.create_quoted_order(sender,pg_temp.quote_for('express'),'delivery-key-three-0003');
  perform public.execute_delivery_command(sender,delivery.id,'request_payment','{}');
  perform public.execute_delivery_command(sender,delivery.id,'fund','{}');
  perform public.execute_delivery_command(courier,delivery.id,'accept','{}');
  foreach step in array array['heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff'] loop
    perform public.execute_delivery_command(courier,delivery.id,step,'{}');
  end loop;
  perform public.execute_delivery_command(courier,delivery.id,'report_issue','{"reason":"Recipient unreachable"}');
  perform public.request_delivery_return(courier,delivery.id,'Recipient unreachable');
  perform public.approve_delivery_return(stranger,delivery.id,'Return approved after investigation');
  begin
    perform public.execute_delivery_command(sender,delivery.id,'confirm_receipt','{}');
    raise exception 'Disputed funds were released';
  exception when raise_exception then
    if sqlerrm='Disputed funds were released' then raise; end if;
  end;
  perform public.execute_delivery_command(courier,delivery.id,'returning','{}');
  perform public.execute_delivery_command(courier,delivery.id,'returned','{}');
  if (select balance_minor from public.wallet_balances where user_id=courier)<>90000 then raise exception 'Return earned completion payout'; end if;
  if (select status from public.escrows where order_id=delivery.id)<>'disputed' then raise exception 'Return released disputed funds'; end if;
  delivery:=public.create_quoted_order(sender,pg_temp.quote_for('express'),'delivery-key-four-0004');
  perform public.execute_delivery_command(sender,delivery.id,'request_payment','{}');
  perform public.execute_delivery_command(sender,delivery.id,'fund','{}');
  perform public.execute_delivery_command(courier,delivery.id,'accept','{}');
  foreach step in array array['heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff'] loop
    perform public.execute_delivery_command(courier,delivery.id,step,'{}');
  end loop;
  code:=public.sender_handover_code(sender,delivery.id)->>'code';
  perform public.execute_delivery_command(courier,delivery.id,'handover',jsonb_build_object('recipientName','Recipient','code',code));
  if (select status from public.orders where id=delivery.id)<>'completed' or (select status from public.escrows where order_id=delivery.id)<>'released' then raise exception 'Express handover did not complete'; end if;
  if (select balance_minor from public.wallet_balances where user_id=courier)<>180000 then raise exception 'Express earnings incorrect'; end if;
  if public.deliverer_summary(courier)->>'completedDeliveries'<>'2' then raise exception 'Deliverer summary incorrect'; end if;
  if jsonb_array_length(public.deliverer_past_customers(courier))<>1 then raise exception 'Past customer grouping incorrect'; end if;
  if has_function_privilege('authenticated','public.execute_delivery_command(uuid,uuid,text,jsonb)','EXECUTE') then raise exception 'Client can invoke financial commands directly'; end if;
end;
$$;
rollback;
