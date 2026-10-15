begin;
insert into auth.users(id,email) values('15000000-0000-4000-8000-000000000001','reviewer@example.test'),('15000000-0000-4000-8000-000000000002','sender@example.test');
insert into public.user_roles(user_id,role) values('15000000-0000-4000-8000-000000000001','admin');
do $$ declare a jsonb; application_id uuid; state jsonb; begin
  state:=public.mobile_deliverer_command('user_approval_fixture','status','{}');
  if state->>'status'<>'not_started' or coalesce((state->>'canDeliver')::boolean,false) then raise exception 'New user has deliverer access'; end if;
  a:=public.mobile_deliverer_command('user_approval_fixture','start','{"identity":{"fullName":"Fixture Applicant","dateOfBirth":"1990-01-01"},"accountEmail":"applicant@example.test","transportType":"walking","safety":{"lawfulTransport":true,"safeHandling":true,"termsAccepted":true}}');
  application_id:=(a->>'id')::uuid;
  begin perform public.mobile_deliverer_command('user_approval_fixture','submit',jsonb_build_object('applicationId',application_id));raise exception 'Submission without documents allowed';exception when sqlstate 'P0001' then
    if sqlerrm='Submission without documents allowed' then raise;end if;end;
  begin perform public.mobile_deliverer_command('user_other_fixture','reserve',jsonb_build_object('applicationId',application_id,'documentType','identity','path','private/path','mimeType','image/jpeg'));raise exception 'Cross-account document access allowed';exception when insufficient_privilege then null;end;
  a:=public.mobile_deliverer_command('user_approval_fixture','reserve',jsonb_build_object('applicationId',application_id,'documentType','identity','path','private/fixture','mimeType','image/jpeg'));
  perform public.mobile_deliverer_command('user_approval_fixture','confirm',jsonb_build_object('documentId',a->>'id','path','private/fixture','size',100));
  perform public.mobile_deliverer_command('user_approval_fixture','submit',jsonb_build_object('applicationId',application_id));
  state:=public.mobile_deliverer_command('user_approval_fixture','status','{}');if (state->>'canDeliver')::boolean then raise exception 'Pending application grants access';end if;
  begin perform public.review_deliverer_application('15000000-0000-4000-8000-000000000002',application_id,'approved','Self approval attempt');raise exception 'Sender approval allowed';exception when insufficient_privilege then null;end;
  perform public.review_deliverer_application('15000000-0000-4000-8000-000000000001',application_id,'under_review','Reviewing documents');
  perform public.review_deliverer_application('15000000-0000-4000-8000-000000000001',application_id,'approved','Documents approved');
  state:=public.mobile_deliverer_command('user_approval_fixture','status','{}');if not (state->>'canDeliver')::boolean then raise exception 'Approved access missing';end if;
  perform public.review_deliverer_application('15000000-0000-4000-8000-000000000001',application_id,'suspended','Safety review required');
  state:=public.mobile_deliverer_command('user_approval_fixture','status','{}');if (state->>'canDeliver')::boolean then raise exception 'Suspended application grants access';end if;
  begin perform public.mobile_deliverer_command('user_approval_fixture','start','{}');raise exception 'Suspension bypass allowed';exception when insufficient_privilege then null;end;
  if not exists(select 1 from public.audit_logs where entity_id=application_id and action='mobile_verification_review') then raise exception 'Review audit missing';end if;
  if has_function_privilege('authenticated','public.mobile_deliverer_command(text,text,jsonb)','EXECUTE') then raise exception 'Direct mobile commands exposed';end if;
end $$;
rollback;
