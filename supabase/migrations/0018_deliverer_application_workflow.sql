begin;
alter table public.verification_applications add column submitted_at timestamptz;
alter table public.notifications alter column user_id drop not null;
alter table public.notifications add column legacy_user_id text;
alter table public.notifications add constraint notification_recipient check
  ((user_id is not null and legacy_user_id is null) or (user_id is null and legacy_user_id is not null));
create index notifications_mobile_recipient on public.notifications(legacy_user_id,created_at desc) where legacy_user_id is not null;
drop index public.one_open_verification_application;
create unique index one_open_verification_application on public.verification_applications(user_id)
  where status in ('not_started','submitted','pending_approval','under_review');
-- Preserve pending submissions and their original time; drafts are not submitted applications.
update public.verification_applications set status='pending_approval',submitted_at=created_at where status='submitted';
update public.profiles set verification_status='pending_approval' where verification_status='submitted';
update public.deliverer_profiles set verification_status='pending_approval' where verification_status='submitted';
create index verification_queue_status on public.verification_applications(status,submitted_at desc,id);

create function public.validate_deliverer_identity(p_input jsonb) returns void
language plpgsql set search_path='' as $$
begin
  if coalesce(length(trim(p_input->'identity'->>'fullName')),0) not between 2 and 120
    or p_input->'identity'->>'dateOfBirth' is null
    or (p_input->'identity'->>'dateOfBirth')::date > current_date - interval '18 years'
    or p_input->'safety' is distinct from '{"lawfulTransport":true,"safeHandling":true,"termsAccepted":true}'::jsonb then
    raise exception 'Complete identity, age and safety declarations required' using errcode='22023';
  end if;
end $$;

create function public.mobile_verification_notifications(p_user text) returns jsonb
language sql stable set search_path='' as $$
  select coalesce(jsonb_agg(to_jsonb(n) order by n.created_at desc,n.id),'[]'::jsonb) from
    (select id,type,title,body,data,read_at,created_at from public.notifications
     where legacy_user_id=p_user order by created_at desc,id limit 100) n;
$$;

create or replace function public.start_deliverer_application(p_user_id uuid,p_input jsonb) returns public.verification_applications
language plpgsql set search_path='' as $$
declare application public.verification_applications;
begin
  perform public.validate_deliverer_identity(p_input);
  if not public.account_is_active(p_user_id) then raise exception 'Active account required' using errcode='42501'; end if;
  perform 1 from public.profiles where id=p_user_id for update;
  if exists(select 1 from public.deliverer_profiles where user_id=p_user_id and verification_status='approved') then
    raise exception 'Approved transport changes require administrator review' using errcode='P0001'; end if;
  if exists(select 1 from public.verification_applications where user_id=p_user_id and status='suspended') then
    raise exception 'Suspension requires administrator review' using errcode='42501'; end if;
  select * into application from public.verification_applications where user_id=p_user_id and status in ('not_started','pending_approval','submitted','under_review');
  if found then
    if application.status<>'not_started' then raise exception 'Application is already submitted' using errcode='P0001'; end if;
    update public.verification_applications set identity_info=p_input->'identity',transport_info=jsonb_build_object('transportType',p_input->>'transportType'),
      safety_declarations=p_input->'safety',submitted_at=null where id=application.id returning * into application;
  else
    insert into public.verification_applications(user_id,identity_info,transport_info,safety_declarations)
    values(p_user_id,p_input->'identity',jsonb_build_object('transportType',p_input->>'transportType'),p_input->'safety') returning * into application;
  end if;
  insert into public.deliverer_profiles(user_id,transport_type) values(p_user_id,(p_input->>'transportType')::public.transport_type)
  on conflict(user_id) do update set transport_type=excluded.transport_type,verification_status='not_started',availability_status='offline';
  return application;
end;
$$;
create or replace function public.submit_deliverer_application(p_user_id uuid,p_application_id uuid) returns public.verification_applications
language plpgsql set search_path='' as $$
declare application public.verification_applications; requirements text[];
begin
  if not public.account_is_active(p_user_id) then raise exception 'Active account required' using errcode='42501'; end if;
  select * into application from public.verification_applications where id=p_application_id and user_id=p_user_id for update;
  if not found then raise exception 'Application not found' using errcode='P0002'; end if;
  if application.status in ('pending_approval','under_review') then return application; end if;
  if application.status<>'not_started' then raise exception 'Application cannot be submitted' using errcode='P0001'; end if;
  perform public.validate_deliverer_identity(jsonb_build_object('identity',application.identity_info,'safety',application.safety_declarations));
  select required_documents into requirements from public.verification_requirements where transport_type=(application.transport_info->>'transportType')::public.transport_type;
  if requirements is null or exists(select 1 from unnest(requirements) required where not exists(
    select 1 from public.verification_documents where application_id=application.id and document_type=required and upload_verified_at is not null)) then
    raise exception 'Required verification documents are missing' using errcode='P0001'; end if;
  update public.verification_applications set status='pending_approval',submitted_at=now() where id=application.id returning * into application;
  update public.profiles set verification_status='pending_approval' where id=p_user_id;
  update public.deliverer_profiles set verification_status='pending_approval',availability_status='offline' where user_id=p_user_id;
  return application;
end;
$$;
create or replace function public.mobile_deliverer_command(p_user text,p_command text,p_input jsonb) returns jsonb
language plpgsql set search_path='' as $$
declare a public.verification_applications; d public.verification_documents; requirements text[];
begin
  if p_user is null or length(p_user) not between 1 and 128 then raise exception 'Mobile identity required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtext('mobile-deliverer:'||p_user));
  select * into a from public.verification_applications where legacy_user_id=p_user for update;
  if p_command='read_notification' then
    update public.notifications set read_at=coalesce(read_at,now()) where id=(p_input->>'notificationId')::uuid and legacy_user_id=p_user;
    if not found then raise exception 'Notification not found' using errcode='P0002'; end if;
    return jsonb_build_object('read',true);
  elsif p_command='status' then
    return jsonb_build_object('id',a.id,'status',coalesce(a.status::text,'not_started'),'review_notes',a.review_notes,
      'notifications',public.mobile_verification_notifications(p_user),'identity',a.identity_info,'submittedAt',a.submitted_at,'canDeliver',coalesce(a.status='approved',false),'transportType',a.transport_info->>'transportType','requiredDocuments',(select required_documents from public.verification_requirements
        where transport_type=(a.transport_info->>'transportType')::public.transport_type),
      'documents',coalesce((select jsonb_agg(jsonb_build_object('id',x.id,'document_type',x.document_type,'upload_verified_at',x.upload_verified_at))
        from public.verification_documents x where x.application_id=a.id),'[]'::jsonb));
  elsif p_command='start' then
    if a.id is not null and a.status not in ('not_started','rejected') then raise exception 'Application cannot be edited in its current state' using errcode='42501'; end if;
    perform public.validate_deliverer_identity(p_input);
    if (p_input->'identity'->>'dateOfBirth')::date>current_date-interval '18 years'
      or length(trim(p_input->'identity'->>'fullName'))<2
      or p_input->'safety' is distinct from '{"lawfulTransport":true,"safeHandling":true,"termsAccepted":true}'::jsonb then
      raise exception 'Complete identity, age and safety declarations required' using errcode='22023'; end if;
    if not exists(select 1 from public.verification_requirements where transport_type=(p_input->>'transportType')::public.transport_type) then
      raise exception 'Transport verification policy required' using errcode='22023'; end if;
    insert into public.verification_applications(legacy_user_id,legacy_account_email,identity_info,transport_info,safety_declarations,status)
      values(p_user,p_input->>'accountEmail',p_input->'identity',jsonb_build_object('transportType',p_input->>'transportType'),p_input->'safety','not_started')
      on conflict(legacy_user_id) do update set identity_info=excluded.identity_info,transport_info=excluded.transport_info,
        legacy_account_email=excluded.legacy_account_email,safety_declarations=excluded.safety_declarations,submitted_at=null,status='not_started',review_notes=null,reviewed_by=null,reviewed_at=null
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
    if a.status in ('pending_approval','under_review') then return jsonb_build_object('id',a.id,'status',a.status); end if;
    if a.status<>'not_started' then raise exception 'Application cannot be submitted' using errcode='42501'; end if;
    perform public.validate_deliverer_identity(jsonb_build_object('identity',a.identity_info,'safety',a.safety_declarations));
    select required_documents into requirements from public.verification_requirements where transport_type=(a.transport_info->>'transportType')::public.transport_type;
    if requirements is null or exists(select 1 from unnest(requirements) required where not exists
      (select 1 from public.verification_documents where application_id=a.id and document_type=required and upload_verified_at is not null)) then
      raise exception 'Required verification documents are missing' using errcode='P0001'; end if;
    update public.verification_applications set status='pending_approval',submitted_at=now() where id=a.id returning * into a;
  else raise exception 'Unsupported application command' using errcode='22023'; end if;
  return jsonb_build_object('id',a.id,'status',a.status,'canDeliver',false);
end $$;

create or replace function public.review_deliverer_application(p_admin_id uuid,p_application_id uuid,p_status public.verification_status,p_notes text)
returns public.verification_applications language plpgsql set search_path='' as $$
declare a public.verification_applications; previous public.verification_applications; requirements text[];
begin
  if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('verification_agent','admin','super_admin')) then
    raise exception 'Verification review permission required' using errcode='42501'; end if;
  select * into a from public.verification_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found' using errcode='P0002'; end if;
  if p_admin_id=a.user_id or (a.legacy_user_id is not null and lower(a.legacy_account_email)=(select lower(email) from auth.users where id=p_admin_id)) then
    raise exception 'Self approval is prohibited' using errcode='42501'; end if;
  if coalesce(length(trim(p_notes)),0)<3 or length(p_notes)>4000 or p_status is null or not (
    (a.status in ('pending_approval','submitted') and p_status in ('under_review','rejected')) or
    (a.status='under_review' and p_status in ('approved','rejected')) or
    (a.status='approved' and p_status='suspended') or
    (a.status='suspended' and p_status='under_review')) then
    raise exception 'Invalid verification transition or review notes' using errcode='P0001'; end if;
  if p_status='approved' then
    perform public.validate_deliverer_identity(jsonb_build_object('identity',a.identity_info,'safety',a.safety_declarations));
    select required_documents into requirements from public.verification_requirements where transport_type=(a.transport_info->>'transportType')::public.transport_type;
    if requirements is null or exists(select 1 from unnest(requirements) required where not exists
      (select 1 from public.verification_documents where application_id=a.id and document_type=required and upload_verified_at is not null)) then
      raise exception 'Required verified documents missing' using errcode='P0001'; end if;
  end if;
  previous:=a;
  update public.verification_applications set status=p_status,review_notes=trim(p_notes),reviewed_by=p_admin_id,reviewed_at=now() where id=a.id returning * into a;
  if a.user_id is not null then
    update public.profiles set verification_status=p_status,active_role=case when p_status in ('rejected','suspended') then 'sender'::public.user_role else active_role end where id=a.user_id;
    update public.deliverer_profiles set verification_status=p_status,availability_status='offline' where user_id=a.user_id;
    if p_status='approved' then insert into public.user_roles(user_id,role) values(a.user_id,'deliverer') on conflict do nothing;
    elsif p_status in ('rejected','suspended') then delete from public.user_roles where user_id=a.user_id and role='deliverer'; end if;
  end if;
  insert into public.audit_logs(admin_id,action,entity,entity_id,previous_state,new_state)
    values(p_admin_id,case when a.legacy_user_id is null then 'verification_review' else 'mobile_verification_review' end,'verification_application',a.id,
      jsonb_build_object('status',previous.status),jsonb_build_object('status',a.status,'notes',a.review_notes));
  return a;
end $$;

-- Durable notifications are created in the same transaction as the submission/decision.
create function public.notify_deliverer_application() returns trigger language plpgsql set search_path='' as $$
begin
  if new.status=old.status then return new; end if;
  if new.status='pending_approval' then
    insert into public.notifications(user_id,type,title,body,data)
      select distinct r.user_id,'deliverer_application','New deliverer application',
        coalesce(new.identity_info->>'fullName','An applicant') || ' submitted an application for review.',
        jsonb_build_object('applicationId',new.id,'status',new.status)
      from public.user_roles r where r.role in ('verification_agent','admin','super_admin') and public.account_is_active(r.user_id);
  elsif new.status in ('approved','rejected','suspended') then
    insert into public.notifications(user_id,legacy_user_id,type,title,body,data)
      values(new.user_id,new.legacy_user_id,'verification_update',
        case new.status when 'approved' then 'Deliverer application approved' when 'rejected' then 'Deliverer application rejected' else 'Deliverer access suspended' end,
        case new.status when 'approved' then 'Your application is approved. You can now open your delivery workspace.'
          else coalesce(new.review_notes,'Open your application to view the review decision.') end,
        jsonb_build_object('applicationId',new.id,'status',new.status));
  end if;
  return new;
end $$;
create trigger deliverer_application_notifications after update of status on public.verification_applications
for each row execute function public.notify_deliverer_application();

-- Existing pending applications also become visible in each authorized reviewer's inbox.
insert into public.notifications(user_id,type,title,body,data)
  select distinct r.user_id,'deliverer_application','New deliverer application',
    coalesce(a.identity_info->>'fullName','An applicant') || ' is awaiting application review.',
    jsonb_build_object('applicationId',a.id,'status',a.status)
  from public.verification_applications a cross join public.user_roles r
  where a.status in ('pending_approval','under_review') and r.role in ('verification_agent','admin','super_admin')
    and public.account_is_active(r.user_id) and not exists(select 1 from public.notifications n
      where n.user_id=r.user_id and n.type='deliverer_application' and n.data->>'applicationId'=a.id::text);

-- Obsolete review entry point must not bypass the unified document checks.
revoke all on function public.review_supabase_deliverer_application(uuid,uuid,public.verification_status,text) from public,anon,authenticated,service_role;
revoke all on function public.validate_deliverer_identity(jsonb),public.mobile_verification_notifications(text),public.notify_deliverer_application() from public,anon,authenticated;
grant execute on function public.validate_deliverer_identity(jsonb),public.mobile_verification_notifications(text),public.notify_deliverer_application() to service_role;
commit;
