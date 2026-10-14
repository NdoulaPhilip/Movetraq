begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('60000000-0000-4000-8000-000000000001','case-sender@example.test','{}'),
 ('60000000-0000-4000-8000-000000000002','case-courier@example.test','{}'),
 ('60000000-0000-4000-8000-000000000003','case-support@example.test','{}'),
 ('60000000-0000-4000-8000-000000000004','case-finance@example.test','{}');
insert into public.user_roles(user_id,role) values
 ('60000000-0000-4000-8000-000000000002','deliverer'),
 ('60000000-0000-4000-8000-000000000003','support'),
 ('60000000-0000-4000-8000-000000000004','finance');
insert into public.deliverer_profiles(user_id,transport_type,verification_status,availability_status,delivery_area,capacity,service_preferences)
values('60000000-0000-4000-8000-000000000002','van','approved','online',
 '{"latitude":6.6,"longitude":3.3,"radiusMeters":20000}','{"maxWeightKg":1000,"maxActiveJobs":2}',array['p2p']::public.service_type[]);
insert into public.wallet_ledger_entries(wallet_id,user_id,type,amount_minor,idempotency_key)
select id,user_id,'topup',1000000,'support-fixture-topup' from public.wallet_accounts where user_id='60000000-0000-4000-8000-000000000001';
create function pg_temp.delivery_for(p_key text) returns public.orders language plpgsql as $$
declare rule uuid; quote uuid; delivery public.orders; step text;
begin
 insert into public.pricing_rules(service_type,configuration) values('p2p','{}') returning id into rule;
 insert into public.delivery_quotes(user_id,service_type,pricing_rule_id,input,route,pricing_breakdown,total_amount_minor,platform_fee_minor,deliverer_payout_minor,expires_at)
 values('60000000-0000-4000-8000-000000000001','p2p',rule,
 '{"pickup":{"address":"Ikeja Lagos","latitude":6.6,"longitude":3.3},"destination":{"address":"Yaba Lagos","latitude":6.5,"longitude":3.4},"recipient":{"name":"Recipient","phone":"+2348012345678"},"parcel":{"description":"Parcel","weightKg":1},"serviceDetails":{}}',
 '{}','{}',100000,10000,90000,now()+interval '1 hour') returning id into quote;
 delivery:=public.create_quoted_order('60000000-0000-4000-8000-000000000001',quote,p_key);
 perform public.execute_delivery_command(delivery.sender_id,delivery.id,'request_payment','{}');
 perform public.execute_delivery_command(delivery.sender_id,delivery.id,'fund','{}');
 perform public.execute_delivery_command('60000000-0000-4000-8000-000000000002',delivery.id,'offer','{}');
 perform public.execute_delivery_command(delivery.sender_id,delivery.id,'assign','{"delivererId":"60000000-0000-4000-8000-000000000002"}');
 foreach step in array array['accept','heading_to_pickup','arrived_pickup','picked_up','heading_to_dropoff','arrived_dropoff'] loop
  perform public.execute_delivery_command('60000000-0000-4000-8000-000000000002',delivery.id,step,'{}');
 end loop;
 select * into delivery from public.orders where id=delivery.id;
 return delivery;
end;
$$;
do $$
declare sender uuid:='60000000-0000-4000-8000-000000000001'; courier uuid:='60000000-0000-4000-8000-000000000002';
 support uuid:='60000000-0000-4000-8000-000000000003'; finance uuid:='60000000-0000-4000-8000-000000000004';
 delivery public.orders; upload public.evidence_uploads; secret text; ticket jsonb;
begin
 delivery:=pg_temp.delivery_for('support-delivery-one');
 upload:=public.reserve_evidence_upload(courier,delivery.id,'private/order/random.png','image/png');
 secret:=public.sender_handover_code(sender,delivery.id)->>'code';
 begin
  perform public.execute_delivery_command(courier,delivery.id,'handover',jsonb_build_object('recipientName','Recipient','code',secret,'evidenceUploadId',upload.id));
  raise exception 'Unverified photo accepted';
 exception when insufficient_privilege then null; end;
 perform public.confirm_evidence_upload(courier,upload.id,upload.storage_path,100);
 perform public.execute_delivery_command(courier,delivery.id,'handover',jsonb_build_object('recipientName','Recipient','code',secret,'evidenceUploadId',upload.id));
 if (select photo_path from public.delivery_evidence where order_id=delivery.id)<>upload.storage_path then raise exception 'Verified photo not attached'; end if;
 ticket:=public.open_support_case(sender,delivery.id,'damaged_parcel','Parcel damaged','support-case-request-one');
 perform public.open_support_case(sender,delivery.id,'damaged_parcel','Parcel damaged','support-case-request-one');
 if (select count(*) from public.support_tickets where order_id=delivery.id)<>1 then raise exception 'Case retry duplicated'; end if;
 begin
  perform public.settle_delivery_dispute(support,delivery.id,'release','Recipient confirms safe contents','settlement-key-one');
  raise exception 'Support released financial hold';
 exception when insufficient_privilege then null; end;
 perform public.settle_delivery_dispute(finance,delivery.id,'release','Recipient confirms safe contents','settlement-key-one');
 perform public.settle_delivery_dispute(finance,delivery.id,'release','Recipient confirms safe contents','settlement-key-one');
 if (select balance_minor from public.wallet_balances where user_id=courier)<>90000 then raise exception 'Duplicate dispute payout'; end if;
 begin
  perform public.settle_delivery_dispute(finance,delivery.id,'refund','Different decision','settlement-key-two');
  raise exception 'Settled order refunded again';
 exception when raise_exception then if sqlerrm='Settled order refunded again' then raise; end if; end;
 perform public.rate_completed_delivery(sender,delivery.id,5,'Delivered safely');
 perform public.rate_completed_delivery(sender,delivery.id,5,'Delivered safely');
 if (select count(*) from public.ratings where order_id=delivery.id)<>1 then raise exception 'Rating retry duplicated'; end if;
 delivery:=pg_temp.delivery_for('support-delivery-two');
 perform public.request_delivery_return(courier,delivery.id,'Recipient unreachable');
 begin
  perform public.execute_delivery_command(courier,delivery.id,'returning','{}');
  raise exception 'Unapproved return started';
 exception when raise_exception then if sqlerrm='Unapproved return started' then raise; end if; end;
 perform public.approve_delivery_return(support,delivery.id,'Contact attempted, return approved');
 perform public.execute_delivery_command(courier,delivery.id,'returning','{}');
 perform public.execute_delivery_command(courier,delivery.id,'returned','{}');
 begin
  perform public.settle_delivery_dispute(finance,delivery.id,'release','Return delivered','settlement-key-three');
  raise exception 'Return paid normal earnings';
 exception when raise_exception then if sqlerrm='Return paid normal earnings' then raise; end if; end;
 perform public.settle_delivery_dispute(finance,delivery.id,'refund','Parcel returned to sender','settlement-key-four');
 perform public.settle_delivery_dispute(finance,delivery.id,'refund','Parcel returned to sender','settlement-key-four');
 if (select balance_minor from public.wallet_balances where user_id=sender)<>900000 then raise exception 'Return refund incorrect'; end if;
 if (select balance_minor from public.wallet_balances where user_id=courier)<>90000 then raise exception 'Return credited earnings'; end if;
 if (select status from public.orders where id=delivery.id)<>'returned' then raise exception 'Refund changed return to completion'; end if;
 if has_function_privilege('authenticated','public.settle_delivery_dispute(uuid,uuid,text,text,text)','EXECUTE') then raise exception 'Client can settle directly'; end if;
 if has_column_privilege('authenticated','public.support_tickets','internal_notes','SELECT') then raise exception 'Client can read internal notes'; end if;
 if has_column_privilege('authenticated','public.delivery_evidence','photo_path','SELECT') then raise exception 'Client can read private photo paths'; end if;
end;
$$;
rollback;
