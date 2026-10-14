begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('40000000-0000-4000-8000-000000000001','applicant@example.test','{}'),
 ('40000000-0000-4000-8000-000000000002','reviewer@example.test','{}'),
 ('40000000-0000-4000-8000-000000000003','other-applicant@example.test','{}');
insert into public.user_roles(user_id,role) values('40000000-0000-4000-8000-000000000002','verification_agent');
do $$
declare applicant uuid:='40000000-0000-4000-8000-000000000001'; reviewer uuid:='40000000-0000-4000-8000-000000000002';
 application public.verification_applications; document public.verification_documents; kind text;
begin
  application:=public.start_deliverer_application(applicant,'{"identity":{"fullName":"Applicant","dateOfBirth":"1990-01-01"},"transportType":"motorcycle","safety":{"lawfulTransport":true,"safeHandling":true,"termsAccepted":true}}');
  if application.status<>'not_started' or exists(select 1 from public.user_roles where user_id=applicant and role='deliverer') then
    raise exception 'Unverified application granted delivery capability'; end if;
  begin
    perform public.submit_deliverer_application(applicant,application.id);
    raise exception 'Incomplete application was submitted';
  exception when raise_exception then if sqlerrm='Incomplete application was submitted' then raise; end if; end;
  foreach kind in array array['identity','driver_licence','registration','insurance'] loop
    document:=public.reserve_verification_document(applicant,application.id,kind,applicant::text||'/'||application.id::text||'/'||kind||'.pdf','application/pdf');
    begin
      perform public.confirm_verification_document('40000000-0000-4000-8000-000000000003',document.id,document.storage_path,1000);
      raise exception 'Another account confirmed the document';
    exception when raise_exception then if sqlerrm='Another account confirmed the document' then raise; end if; end;
    perform public.confirm_verification_document(applicant,document.id,document.storage_path,1000);
  end loop;
  perform public.submit_deliverer_application(applicant,application.id);
  begin
    perform public.review_deliverer_application(applicant,application.id,'approved','Self approval');
    raise exception 'Applicant approved themselves';
  exception when insufficient_privilege then null; end;
  begin
    perform public.review_deliverer_application(reviewer,application.id,'approved','Skipped review');
    raise exception 'Review stage was skipped';
  exception when raise_exception then if sqlerrm='Review stage was skipped' then raise; end if; end;
  perform public.review_deliverer_application(reviewer,application.id,'under_review','Review started');
  perform public.review_deliverer_application(reviewer,application.id,'approved','Documents checked');
  if not exists(select 1 from public.user_roles where user_id=applicant and role='sender') or
    not exists(select 1 from public.user_roles where user_id=applicant and role='deliverer') then raise exception 'Dual sender/deliverer capability missing'; end if;
  if (select count(*) from public.audit_logs where entity_id=application.id)<>2 then raise exception 'Review audit trail missing'; end if;
  perform public.review_deliverer_application(reviewer,application.id,'suspended','Account suspended');
  if exists(select 1 from public.user_roles where user_id=applicant and role='deliverer') or
    (select availability_status from public.deliverer_profiles where user_id=applicant)<>'offline' then raise exception 'Suspension did not revoke eligibility'; end if;
  if has_function_privilege('authenticated','public.review_deliverer_application(uuid,uuid,public.verification_status,text)','EXECUTE') then
    raise exception 'Client can invoke approval directly'; end if;
end;
$$;
rollback;
