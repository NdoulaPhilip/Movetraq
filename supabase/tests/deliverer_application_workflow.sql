begin;
insert into auth.users(id,email) values
 ('18000000-0000-4000-8000-000000000001','workflow-admin@example.test'),
 ('18000000-0000-4000-8000-000000000002','workflow-reviewer@example.test'),
 ('18000000-0000-4000-8000-000000000003','workflow-sender@example.test'),
 ('18000000-0000-4000-8000-000000000004','workflow-disabled@example.test'),
 ('18000000-0000-4000-8000-000000000005','workflow-support@example.test');
insert into public.user_roles(user_id,role) values
 ('18000000-0000-4000-8000-000000000001','admin'),
 ('18000000-0000-4000-8000-000000000001','verification_agent'),
 ('18000000-0000-4000-8000-000000000002','verification_agent'),
 ('18000000-0000-4000-8000-000000000004','admin'),
 ('18000000-0000-4000-8000-000000000005','support');
update public.security_settings set suspended_at=now() where user_id='18000000-0000-4000-8000-000000000004';
do $$
declare a jsonb; app uuid; doc uuid; decision_id uuid; result jsonb; native public.verification_applications; native_doc public.verification_documents;
  input jsonb:='{"identity":{"fullName":"Workflow Applicant","dateOfBirth":"1990-01-01"},"accountEmail":"workflow-applicant@example.test","transportType":"walking","safety":{"lawfulTransport":true,"safeHandling":true,"termsAccepted":true}}';
  admin_id uuid:='18000000-0000-4000-8000-000000000001'; sender_id uuid:='18000000-0000-4000-8000-000000000003';
begin
  a:=public.mobile_deliverer_command('user_workflow','start',input);app:=(a->>'id')::uuid;
  if a->>'status'<>'not_started' or exists(select 1 from public.notifications where data->>'applicationId'=app::text) then raise exception 'Draft incorrectly submitted or notified';end if;
  begin
    perform public.mobile_deliverer_command('user_workflow','submit',jsonb_build_object('applicationId',app));
    raise exception 'Missing documents permitted';
  exception when sqlstate 'P0001' then if sqlerrm='Missing documents permitted' then raise;end if;end;
  a:=public.mobile_deliverer_command('user_workflow','reserve',jsonb_build_object('applicationId',app,'documentType','identity','path','workflow/identity','mimeType','image/jpeg'));doc:=(a->>'id')::uuid;
  perform public.mobile_deliverer_command('user_workflow','confirm',jsonb_build_object('documentId',doc,'path','workflow/identity','size',200));
  a:=public.mobile_deliverer_command('user_workflow','submit',jsonb_build_object('applicationId',app));
  if a->>'status'<>'pending_approval' or (select submitted_at from public.verification_applications where id=app) is null then raise exception 'Pending Approval was not persisted';end if;
  if (select count(*) from public.notifications where data->>'applicationId'=app::text)<>2 then raise exception 'Active authorized staff did not receive exactly one notification each';end if;
  perform public.mobile_deliverer_command('user_workflow','submit',jsonb_build_object('applicationId',app));
  if (select count(*) from public.notifications where data->>'applicationId'=app::text)<>2 then raise exception 'Repeated submit duplicated notifications';end if;
  begin perform public.mobile_deliverer_command('user_workflow','start',input);raise exception 'Pending application overwritten';exception when insufficient_privilege then null;end;
  begin perform public.review_deliverer_application(sender_id,app,'under_review','Unauthorized review');raise exception 'Sender reviewed application';exception when insufficient_privilege then null;end;
  begin perform public.review_deliverer_application('18000000-0000-4000-8000-000000000005',app,'rejected','Support reviewed application');raise exception 'Support role reviewed application';exception when insufficient_privilege then null;end;
  begin perform public.review_deliverer_application(admin_id,app,'under_review',null);raise exception 'Null notes allowed';exception when sqlstate 'P0001' then if sqlerrm='Null notes allowed' then raise;end if;end;
  perform public.review_deliverer_application(admin_id,app,'under_review','Checking identity');
  perform public.review_deliverer_application(admin_id,app,'rejected','Identity image is unclear');
  result:=public.mobile_deliverer_command('user_workflow','status','{}');
  if result->>'status'<>'rejected' or (result->>'canDeliver')::boolean or jsonb_array_length(result->'notifications')<>1 then raise exception 'Rejected applicant status or notification missing';end if;
  select id into decision_id from public.notifications where legacy_user_id='user_workflow' and data->>'status'='rejected';
  if decision_id is null then raise exception 'Rejection notification was not saved';end if;
  begin perform public.mobile_deliverer_command('user_another','read_notification',jsonb_build_object('notificationId',decision_id));raise exception 'Another user read the rejection';exception when no_data_found then null;end;
  perform public.mobile_deliverer_command('user_workflow','read_notification',jsonb_build_object('notificationId',decision_id));
  if (select read_at from public.notifications where id=decision_id) is null then raise exception 'Notification read was not persisted';end if;
  perform public.mobile_deliverer_command('user_workflow','start',input);
  begin perform public.mobile_deliverer_command('user_workflow','submit',jsonb_build_object('applicationId',app));raise exception 'Rejected documents reused without re-verification';exception when sqlstate 'P0001' then if sqlerrm='Rejected documents reused without re-verification' then raise;end if;end;
  perform public.mobile_deliverer_command('user_workflow','confirm',jsonb_build_object('documentId',doc,'path','workflow/identity','size',200));
  perform public.mobile_deliverer_command('user_workflow','submit',jsonb_build_object('applicationId',app));
  if (select count(*) from public.notifications where user_id=admin_id and data->>'applicationId'=app::text)<>2 then raise exception 'Resubmission did not notify admin';end if;
  perform public.review_deliverer_application(admin_id,app,'under_review','Rechecking identity');
  perform public.review_deliverer_application(admin_id,app,'approved','Identity verified');
  result:=public.mobile_deliverer_command('user_workflow','status','{}');
  if result->>'status'<>'approved' or not (result->>'canDeliver')::boolean or jsonb_array_length(result->'notifications')<>2 then raise exception 'Approval or applicant notification missing';end if;
  perform public.review_deliverer_application(admin_id,app,'suspended','Additional safety review');
  begin perform public.mobile_deliverer_command('user_workflow','start',input);raise exception 'Suspension bypass';exception when insufficient_privilege then null;end;
  -- An administrator cannot approve a linked mobile account with their own email.
  input:=jsonb_set(input,'{accountEmail}','"WORKFLOW-ADMIN@example.test"');
  a:=public.mobile_deliverer_command('user_self_review','start',input);
  begin perform public.review_deliverer_application(admin_id,(a->>'id')::uuid,'under_review','Self review attempted');raise exception 'Cross-identity self review';exception when insufficient_privilege then null;end;
  -- Native Supabase applicants get the same pending status and decision inbox.
  native:=public.start_deliverer_application(sender_id,input-'accountEmail');
  native_doc:=public.reserve_verification_document(sender_id,native.id,'identity','workflow/native','image/jpeg');
  perform public.confirm_verification_document(sender_id,native_doc.id,native_doc.storage_path,100);
  native:=public.submit_deliverer_application(sender_id,native.id);
  if native.status<>'pending_approval' then raise exception 'Native pending status missing';end if;
  perform public.review_deliverer_application(admin_id,native.id,'under_review','Reviewing native applicant');
  perform public.review_deliverer_application(admin_id,native.id,'approved','Native identity verified');
  if not exists(select 1 from public.user_roles where user_id=sender_id and role='deliverer') or not exists(select 1 from public.notifications where user_id=sender_id and data->>'status'='approved') then raise exception 'Native activation or notification missing';end if;
  if has_table_privilege('authenticated','public.verification_applications','UPDATE') or has_function_privilege('authenticated','public.mobile_verification_notifications(text)','EXECUTE') or has_function_privilege('authenticated','public.review_deliverer_application(uuid,uuid,public.verification_status,text)','EXECUTE') then raise exception 'Applicant can bypass review or read another inbox';end if;
end $$;
rollback;
