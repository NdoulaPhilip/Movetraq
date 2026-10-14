begin;
create table public.evidence_uploads (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
 submitted_by uuid not null references public.profiles(id), storage_path text not null unique,
 mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
 size_bytes integer check(size_bytes between 1 and 1572864), verified_at timestamptz,
 consumed_at timestamptz, created_at timestamptz not null default now()
);
create table public.return_requests (
 order_id uuid primary key references public.orders(id), requested_by uuid not null references public.profiles(id),
 reason text not null, status text not null check(status in ('return_requested','return_approved','returning','returned')),
 approved_by uuid references public.profiles(id), approved_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.dispute_settlements (
 order_id uuid primary key references public.orders(id), admin_id uuid not null references public.profiles(id),
 decision text not null check(decision in ('release','refund')), idempotency_key text not null,
 resolution text not null, amount_minor integer not null check(amount_minor>0), created_at timestamptz not null default now(),
 unique(admin_id,idempotency_key)
);
alter table public.support_tickets add column idempotency_key text;
create unique index support_request_idempotency on public.support_tickets(reporter_id,idempotency_key) where idempotency_key is not null;
do $$ declare relation text;
begin
 foreach relation in array array['evidence_uploads','return_requests','dispute_settlements'] loop
  execute format('alter table public.%I enable row level security',relation);
  execute format('revoke all on public.%I from anon,authenticated',relation);
 end loop;
end;
$$;
revoke select on public.support_tickets,public.delivery_evidence from authenticated;
grant select(id,order_id,reporter_id,category,description,status,priority,resolution,created_at,updated_at) on public.support_tickets to authenticated;
grant select(id,order_id,recipient_name,submitted_by,captured_at,created_at) on public.delivery_evidence to authenticated;
create trigger immutable_dispute_settlements before update or delete on public.dispute_settlements
for each row execute function public.reject_ledger_mutation();
create trigger immutable_dispute_settlements_truncate before truncate on public.dispute_settlements
for each statement execute function public.reject_ledger_mutation();

create function public.reserve_evidence_upload(p_actor_id uuid,p_order_id uuid,p_path text,p_mime text) returns public.evidence_uploads
language plpgsql set search_path='' as $$
declare delivery public.orders; upload public.evidence_uploads;
begin
 select * into delivery from public.orders where id=p_order_id for update;
 if not found or delivery.deliverer_id is distinct from p_actor_id or delivery.status<>'arrived_dropoff'
  or delivery.issue_status<>'none' or not public.account_is_active(p_actor_id) then raise exception 'Active dropoff required' using errcode='42501'; end if;
 insert into public.evidence_uploads(order_id,submitted_by,storage_path,mime_type) values(p_order_id,p_actor_id,p_path,p_mime) returning * into upload;
 return upload;
end;
$$;
create function public.confirm_evidence_upload(p_actor_id uuid,p_upload_id uuid,p_path text,p_size integer) returns jsonb
language plpgsql set search_path='' as $$
declare upload public.evidence_uploads; delivery public.orders;
begin
 select o.* into delivery from public.orders o join public.evidence_uploads u on u.order_id=o.id where u.id=p_upload_id for update of o;
 select * into upload from public.evidence_uploads where id=p_upload_id for update;
 if not found or upload.submitted_by<>p_actor_id or upload.storage_path<>p_path or delivery.deliverer_id is distinct from p_actor_id
  or delivery.status<>'arrived_dropoff' or upload.consumed_at is not null or p_size not between 1 and 1572864 then
  raise exception 'Evidence cannot be confirmed' using errcode='42501'; end if;
 update public.evidence_uploads set size_bytes=p_size,verified_at=now() where id=p_upload_id;
 return jsonb_build_object('id',p_upload_id,'verified',true);
end;
$$;

alter function public.execute_delivery_command(uuid,uuid,text,jsonb) rename to execute_delivery_command_internal;
create function public.execute_delivery_command(p_actor_id uuid,p_order_id uuid,p_command text,p_input jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare delivery public.orders; result jsonb; upload public.evidence_uploads;
begin
 select * into delivery from public.orders where id=p_order_id for update;
 if p_command in ('returning','returned') and not exists(select 1 from public.return_requests where order_id=p_order_id and status in ('return_approved','returning','returned')) then
  raise exception 'Approved return required' using errcode='P0001'; end if;
 if p_command='handover' and p_input->>'evidenceUploadId' is not null then
  select * into upload from public.evidence_uploads where id=(p_input->>'evidenceUploadId')::uuid for update;
  if not found or upload.order_id<>p_order_id or upload.submitted_by<>p_actor_id or upload.verified_at is null then
   raise exception 'Verified order evidence required' using errcode='42501'; end if;
  if upload.consumed_at is not null and delivery.evidence_status<>'verified' then raise exception 'Evidence already consumed' using errcode='P0001'; end if;
  if upload.consumed_at is null and delivery.evidence_status='verified' then raise exception 'Completed handover evidence is immutable' using errcode='P0001'; end if;
 end if;
 result:=public.execute_delivery_command_internal(p_actor_id,p_order_id,p_command,p_input);
 if result ? 'error' then return result; end if;
 if p_command='handover' and upload.id is not null and upload.consumed_at is null then
  update public.delivery_evidence set photo_path=upload.storage_path where order_id=p_order_id and submitted_by=p_actor_id;
  update public.evidence_uploads set consumed_at=now() where id=upload.id;
 end if;
 if p_command in ('returning','returned') then
  update public.return_requests set status=p_command,updated_at=now() where order_id=p_order_id;
 end if;
 return result;
end;
$$;
create function public.open_support_case(p_actor_id uuid,p_order_id uuid,p_category text,p_description text,p_key text) returns jsonb
language plpgsql set search_path='' as $$
declare delivery public.orders; ticket public.support_tickets;
begin
 select * into delivery from public.orders where id=p_order_id for update;
 if not found or p_actor_id not in (delivery.sender_id,coalesce(delivery.deliverer_id,delivery.sender_id)) or not public.account_is_active(p_actor_id) then
  raise exception 'Order participant required' using errcode='42501'; end if;
 select * into ticket from public.support_tickets where reporter_id=p_actor_id and idempotency_key=p_key;
 if found then
  if ticket.order_id<>p_order_id or ticket.category<>p_category or ticket.description<>p_description then raise exception 'Support retry conflicts' using errcode='P0001'; end if;
  return to_jsonb(ticket)-'internal_notes'-'attachment_paths';
 end if;
 if delivery.escrow_status='held' then
  update public.orders set issue_status='open',escrow_status='disputed' where id=p_order_id;
  update public.escrows set status='disputed',disputed_at=now() where order_id=p_order_id;
  insert into public.disputes(order_id,opened_by) values(p_order_id,p_actor_id);
 end if;
 insert into public.support_tickets(order_id,reporter_id,category,description,idempotency_key)
 values(p_order_id,p_actor_id,p_category,p_description,p_key) returning * into ticket;
 return to_jsonb(ticket)-'internal_notes'-'attachment_paths';
end;
$$;
create function public.request_delivery_return(p_actor_id uuid,p_order_id uuid,p_reason text) returns public.return_requests
language plpgsql set search_path='' as $$
declare delivery public.orders; request public.return_requests;
begin
 select * into delivery from public.orders where id=p_order_id for update;
 if not found or not public.account_is_active(p_actor_id) or p_actor_id not in (delivery.sender_id,coalesce(delivery.deliverer_id,delivery.sender_id)) or delivery.status not in ('picked_up','heading_to_dropoff','arrived_dropoff','failed') then
  raise exception 'Active collected delivery required' using errcode='42501'; end if;
 select * into request from public.return_requests where order_id=p_order_id;
 if found then return request; end if;
 perform public.open_support_case(p_actor_id,p_order_id,'return',p_reason,'return:'||p_order_id::text);
 insert into public.return_requests(order_id,requested_by,reason,status) values(p_order_id,p_actor_id,p_reason,'return_requested') returning * into request;
 return request;
end;
$$;
create function public.approve_delivery_return(p_admin_id uuid,p_order_id uuid,p_notes text) returns public.return_requests
language plpgsql set search_path='' as $$
declare request public.return_requests;
begin
 if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('support','operations','admin','super_admin')) then raise exception 'Return review permission required' using errcode='42501'; end if;
 perform 1 from public.orders where id=p_order_id and p_admin_id not in (sender_id,coalesce(deliverer_id,sender_id)) for update;
 if not found then raise exception 'Independent return reviewer required' using errcode='42501'; end if;
 select * into request from public.return_requests where order_id=p_order_id for update;
 if not found then raise exception 'Return request not found' using errcode='P0002'; end if;
 if request.status<>'return_requested' then return request; end if;
 update public.return_requests set status='return_approved',approved_by=p_admin_id,approved_at=now(),updated_at=now() where order_id=p_order_id returning * into request;
 insert into public.audit_logs(admin_id,action,entity,entity_id,new_state) values(p_admin_id,'return_approved','order',p_order_id,jsonb_build_object('notes',p_notes));
 return request;
end;
$$;
create function public.review_support_case(p_admin_id uuid,p_case_id uuid,p_input jsonb) returns public.support_tickets
language plpgsql set search_path='' as $$
declare ticket public.support_tickets; previous jsonb;
begin
 if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('support','operations','admin','super_admin')) then raise exception 'Support permission required' using errcode='42501'; end if;
 select * into ticket from public.support_tickets where id=p_case_id for update;
 if not found then raise exception 'Support case not found' using errcode='P0002'; end if;
 previous:=to_jsonb(ticket);
 if ticket.status in ('resolved','closed') then raise exception 'Case is already resolved' using errcode='P0001'; end if;
 if p_input->>'status' in ('resolved','closed') and exists(select 1 from public.escrows where order_id=ticket.order_id and status='disputed') then
  raise exception 'Finance must settle held funds before closing this case' using errcode='P0001'; end if;
 update public.support_tickets set status=(p_input->>'status')::public.support_status,priority=p_input->>'priority',
  assigned_admin_id=p_admin_id,internal_notes=p_input->>'internalNotes',resolution=p_input->>'resolution' where id=p_case_id returning * into ticket;
 insert into public.audit_logs(admin_id,action,entity,entity_id,previous_state,new_state) values(p_admin_id,'support_review','support_ticket',p_case_id,previous,to_jsonb(ticket));
 return ticket;
end;
$$;
create function public.settle_delivery_dispute(p_admin_id uuid,p_order_id uuid,p_decision text,p_resolution text,p_key text) returns public.dispute_settlements
language plpgsql set search_path='' as $$
declare delivery public.orders; escrow public.escrows; wallet public.wallet_accounts; settlement public.dispute_settlements;
begin
 if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('finance','admin','super_admin')) then raise exception 'Settlement permission required' using errcode='42501'; end if;
 select * into delivery from public.orders where id=p_order_id for update;
 if not found or p_admin_id in (delivery.sender_id,coalesce(delivery.deliverer_id,delivery.sender_id)) then raise exception 'Independent settlement reviewer required' using errcode='42501'; end if;
 select * into settlement from public.dispute_settlements where order_id=p_order_id;
 if found then
  if settlement.admin_id<>p_admin_id or settlement.decision<>p_decision or settlement.resolution<>p_resolution or settlement.idempotency_key<>p_key then raise exception 'Dispute already settled' using errcode='P0001'; end if;
  return settlement;
 end if;
 select * into escrow from public.escrows where order_id=p_order_id for update;
 if not found or escrow.status<>'disputed' then raise exception 'Disputed funds required' using errcode='P0001'; end if;
 if p_decision not in ('release','refund') then raise exception 'Invalid settlement decision' using errcode='22023'; end if;
 if p_decision='release' and (delivery.status<>'awaiting_confirmation' or delivery.evidence_status<>'verified' or exists(select 1 from public.return_requests where order_id=p_order_id)) then raise exception 'Verified non-returned delivery required for release' using errcode='P0001'; end if;
 if p_decision='refund' and delivery.status not in ('awaiting_deliverer','offer_received','deliverer_assigned','accepted','awaiting_confirmation','returned') then raise exception 'Return parcel before refunding an active collected delivery' using errcode='P0001'; end if;
 update public.support_tickets set status='resolved',resolution=p_resolution,assigned_admin_id=p_admin_id where order_id=p_order_id and status not in ('resolved','closed');
 update public.disputes set status='resolved',resolution=p_resolution,assigned_admin_id=p_admin_id where order_id=p_order_id and status not in ('resolved','closed');
 update public.orders set issue_status='none' where id=p_order_id;
 if p_decision='release' then
  update public.escrows set status='held' where id=escrow.id;
  update public.orders set escrow_status='held' where id=p_order_id;
  perform public.release_delivery_escrow(p_order_id);
  update public.orders set status='completed',completed_at=now() where id=p_order_id;
 else
  select * into wallet from public.wallet_accounts where user_id=delivery.sender_id and currency=delivery.currency for update;
  if not found then raise exception 'Refund wallet unavailable' using errcode='P0001'; end if;
  insert into public.wallet_ledger_entries(wallet_id,user_id,order_id,type,amount_minor,currency,idempotency_key)
   values(wallet.id,wallet.user_id,p_order_id,'refund',escrow.amount_minor,delivery.currency,'refund:'||p_order_id::text);
  update public.escrows set status='refunded',refunded_at=now() where id=escrow.id;
  if delivery.status='awaiting_confirmation' then update public.orders set status='disputed' where id=p_order_id; end if;
  update public.orders set status=case when delivery.status='returned' then 'returned'::public.order_status else 'cancelled'::public.order_status end,
   payment_status='refunded',escrow_status='refunded',cancelled_at=case when delivery.status<>'returned' then now() else cancelled_at end where id=p_order_id;
 end if;
 if delivery.deliverer_id is not null and delivery.status<>'returned' then update public.deliverer_profiles set active_job_count=greatest(0,active_job_count-1) where user_id=delivery.deliverer_id; end if;
 update public.conversations set closed_at=now() where order_id=p_order_id and closed_at is null;
 delete from public.delivery_locations where order_id=p_order_id;
 insert into public.dispute_settlements(order_id,admin_id,decision,idempotency_key,resolution,amount_minor)
 values(p_order_id,p_admin_id,p_decision,p_key,p_resolution,case when p_decision='refund' then escrow.amount_minor else delivery.deliverer_payout_minor end) returning * into settlement;
 insert into public.audit_logs(admin_id,action,entity,entity_id,new_state) values(p_admin_id,'dispute_settled','order',p_order_id,to_jsonb(settlement));
 insert into public.order_events(order_id,actor_id,event_type,previous_status,new_status) select p_order_id,p_admin_id,'dispute_'||p_decision,delivery.status,status from public.orders where id=p_order_id;
 insert into public.notifications(user_id,type,title,body,data) values(delivery.sender_id,'dispute_resolution','Delivery dispute resolved',p_resolution,jsonb_build_object('orderId',p_order_id,'decision',p_decision));
 return settlement;
end;
$$;
create function public.rate_completed_delivery(p_actor_id uuid,p_order_id uuid,p_rating integer,p_review text) returns public.ratings
language plpgsql set search_path='' as $$
declare delivery public.orders; result public.ratings; target uuid;
begin
 select * into delivery from public.orders where id=p_order_id for update;
 if not found or delivery.status<>'completed' or p_actor_id not in (delivery.sender_id,coalesce(delivery.deliverer_id,delivery.sender_id)) or not public.account_is_active(p_actor_id) then raise exception 'Completed participant delivery required' using errcode='42501'; end if;
 target:=case when p_actor_id=delivery.sender_id then delivery.deliverer_id else delivery.sender_id end;
 select * into result from public.ratings where order_id=p_order_id and reviewer_id=p_actor_id and reviewee_id=target;
 if found then
  if result.rating<>p_rating or result.review is distinct from p_review then raise exception 'Delivery already rated' using errcode='P0001'; end if;
  return result;
 end if;
 insert into public.ratings(order_id,reviewer_id,reviewee_id,rating,review) values(p_order_id,p_actor_id,target,p_rating,p_review) returning * into result;
 return result;
end;
$$;
do $$ declare fn regprocedure;
begin
 for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[
  'reserve_evidence_upload','confirm_evidence_upload','execute_delivery_command','open_support_case','request_delivery_return','approve_delivery_return',
  'review_support_case','settle_delivery_dispute','rate_completed_delivery']) loop
  execute format('revoke all on function %s from public,anon,authenticated',fn);
  execute format('grant execute on function %s to service_role',fn);
 end loop;
end;
$$;
commit;
