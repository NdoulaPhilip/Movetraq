begin;
-- Preserve mobile identities explicitly; they are not Supabase Auth UUIDs.
alter table public.verification_applications alter column user_id drop not null;
alter table public.verification_applications add column legacy_user_id text unique;
alter table public.verification_applications add column legacy_account_email text;
alter table public.verification_applications add constraint application_identity check
  ((user_id is not null and legacy_user_id is null) or (user_id is null and legacy_user_id is not null));
alter table public.verification_documents alter column user_id drop not null;
create function public.mobile_deliverer_command(p_user text,p_command text,p_input jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare a public.verification_applications; d public.verification_documents; requirements text[];
begin
  if p_user is null or length(p_user) not between 1 and 128 then raise exception 'Mobile identity required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtext('mobile-deliverer:'||p_user));
  select * into a from public.verification_applications where legacy_user_id=p_user for update;
  if p_command='status' then
    return jsonb_build_object('id',a.id,'status',coalesce(a.status::text,'not_started'),'review_notes',a.review_notes,
      'canDeliver',coalesce(a.status='approved',false),'transportType',a.transport_info->>'transportType','requiredDocuments',(select required_documents from public.verification_requirements
        where transport_type=(a.transport_info->>'transportType')::public.transport_type),
      'documents',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'document_type',x.document_type,'upload_verified_at',x.upload_verified_at))
        from public.verification_documents x where x.application_id=a.id),'[]'::jsonb));
  elsif p_command='start' then
    if a.id is not null and a.status not in ('not_started','rejected') then raise exception 'Application cannot be edited in its current state' using errcode='42501'; end if;
    if (p_input->'identity'->>'dateOfBirth')::date>current_date-interval '18 years'
      or length(trim(p_input->'identity'->>'fullName'))<2
      or p_input->'safety' is distinct from '{"lawfulTransport":true,"safeHandling":true,"termsAccepted":true}'::jsonb then
      raise exception 'Complete identity, age and safety declarations required' using errcode='22023'; end if;
    if not exists(select 1 from public.verification_requirements where transport_type=(p_input->>'transportType')::public.transport_type) then
      raise exception 'Transport verification policy required' using errcode='22023'; end if;
    insert into public.verification_applications(legacy_user_id,legacy_account_email,identity_info,transport_info,safety_declarations,status)
      values(p_user,p_input->>'accountEmail',p_input->'identity',jsonb_build_object('transportType',p_input->>'transportType'),p_input->'safety','not_started')
      on conflict(legacy_user_id) do update set identity_info=excluded.identity_info,transport_info=excluded.transport_info,
        safety_declarations=excluded.safety_declarations,status='not_started',review_notes=null,reviewed_by=null,reviewed_at=null
      returning * into a;
    update public.verification_documents set upload_verified_at=null where application_id=a.id;
  elsif p_command='reserve' then
    if a.id is null or a.id<>(p_input->>'applicationId')::uuid or a.status<>'not_started' then raise exception 'Editable owned application required' using errcode='42501'; end if;
    if p_input->>'documentType' not in ('identity','driver_licence','registration','insurance')
      or p_input->>'mimeType' not in ('image/jpeg','image/png','application/pdf') then raise exception 'Invalid document' using errcode='22023'; end if;
    insert into public.verification_documents(application_id,document_type,storage_path,mime_type,size_bytes)
      values(a.id,p_input->>'documentType',p_input->>'path',p_input->>'mimeType',1)
      on conflict(application_id,document_type) do update set storage_path=excluded.storage_path,mime_type=excluded.mime_type,size_bytes=1,upload_verified_at=null
      returning * into d;
    return jsonb_build_object('id',d.id);
  elsif p_command='confirm' then
    if a.id is null or a.status<>'not_started' then raise exception 'Editable owned application required' using errcode='42501'; end if;
    update public.verification_documents set upload_verified_at=now(),size_bytes=(p_input->>'size')::integer
      where id=(p_input->>'documentId')::uuid and application_id=a.id and storage_path=p_input->>'path'
        and (p_input->>'size')::integer between 1 and 10485760 returning * into d;
    if not found then raise exception 'Document cannot be confirmed' using errcode='42501'; end if;
    return jsonb_build_object('id',d.id);
  elsif p_command='submit' then
    if a.id is null or a.id<>(p_input->>'applicationId')::uuid then raise exception 'Owned application required' using errcode='42501'; end if;
    if a.status in ('submitted','under_review') then return jsonb_build_object('id',a.id,'status',a.status); end if;
    if a.status<>'not_started' then raise exception 'Application cannot be submitted' using errcode='42501'; end if;
    select required_documents into requirements from public.verification_requirements where transport_type=(a.transport_info->>'transportType')::public.transport_type;
    if requirements is null or exists(select 1 from unnest(requirements) required where not exists
      (select 1 from public.verification_documents where application_id=a.id and document_type=required and upload_verified_at is not null)) then
      raise exception 'Required verification documents are missing' using errcode='P0001'; end if;
    update public.verification_applications set status='submitted' where id=a.id returning * into a;
  else raise exception 'Unsupported application command' using errcode='22023'; end if;
  return jsonb_build_object('id',a.id,'status',a.status,'canDeliver',false);
end $$;
-- Extend the existing audited review path without granting legacy users Auth roles.
alter function public.review_deliverer_application(uuid,uuid,public.verification_status,text) rename to review_supabase_deliverer_application;
create function public.review_deliverer_application(p_admin_id uuid,p_application_id uuid,p_status public.verification_status,p_notes text)
returns public.verification_applications language plpgsql set search_path='' as $$
declare a public.verification_applications; previous public.verification_applications; requirements text[];
begin
  if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('verification_agent','admin','super_admin')) then
    raise exception 'Verification review permission required' using errcode='42501'; end if;
  select * into a from public.verification_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found' using errcode='P0002'; end if;
  if a.legacy_user_id is null then return public.review_supabase_deliverer_application(p_admin_id,p_application_id,p_status,p_notes); end if;
  if lower(a.legacy_account_email)=(select lower(email) from auth.users where id=p_admin_id) then raise exception 'Self approval is prohibited' using errcode='42501'; end if;
  if length(trim(p_notes))<3 or not ((a.status='submitted' and p_status in ('under_review','rejected')) or
    (a.status='under_review' and p_status in ('approved','rejected')) or (a.status='approved' and p_status='suspended') or
    (a.status='suspended' and p_status='under_review')) then raise exception 'Invalid verification transition' using errcode='P0001'; end if;
  select required_documents into requirements from public.verification_requirements where transport_type=(a.transport_info->>'transportType')::public.transport_type;
  if p_status='approved' and (requirements is null or exists(select 1 from unnest(requirements) required where not exists
      (select 1 from public.verification_documents where application_id=a.id and document_type=required and upload_verified_at is not null))) then
    raise exception 'Required verified documents missing' using errcode='P0001'; end if;
  previous:=a;
  update public.verification_applications set status=p_status,review_notes=p_notes,reviewed_by=p_admin_id,reviewed_at=now() where id=a.id returning * into a;
  insert into public.audit_logs(admin_id,action,entity,entity_id,previous_state,new_state)
    values(p_admin_id,'mobile_verification_review','verification_application',a.id,
      jsonb_build_object('status',previous.status,'legacyUserId',a.legacy_user_id),jsonb_build_object('status',a.status,'notes',p_notes));
  return a;
end $$;
revoke all on function public.mobile_deliverer_command(text,text,jsonb),public.review_deliverer_application(uuid,uuid,public.verification_status,text) from public,anon,authenticated;
grant execute on function public.mobile_deliverer_command(text,text,jsonb),public.review_deliverer_application(uuid,uuid,public.verification_status,text) to service_role;
commit;
