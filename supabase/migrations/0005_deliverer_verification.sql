begin;
update storage.buckets set public=false,file_size_limit=10485760,
  allowed_mime_types=array['image/jpeg','image/png','application/pdf'] where id='verification-documents';
update storage.buckets set public=false,file_size_limit=1572864,
  allowed_mime_types=array['image/jpeg','image/png','image/webp'] where id='delivery-evidence';
create trigger immutable_verification_audit before update or delete on public.audit_logs
for each row execute function public.reject_ledger_mutation();
alter table public.verification_applications alter column status set default 'not_started';
alter table public.verification_documents add column upload_verified_at timestamptz;
create unique index verification_document_type on public.verification_documents(application_id,document_type);
create unique index one_open_verification_application on public.verification_applications(user_id)
where status in ('not_started','submitted','under_review');
create table public.verification_requirements (
  transport_type public.transport_type primary key, required_documents text[] not null
);
alter table public.verification_requirements enable row level security;
revoke all on public.verification_requirements from anon,authenticated;
insert into public.verification_requirements(transport_type,required_documents)
select transport,case when transport in ('motorcycle','car','van','other_motor')
  then array['identity','driver_licence','registration','insurance'] else array['identity'] end
from unnest(enum_range(null::public.transport_type)) transport;

create function public.start_deliverer_application(p_user_id uuid,p_input jsonb) returns public.verification_applications
language plpgsql set search_path='' as $$
declare application public.verification_applications;
begin
  if not public.account_is_active(p_user_id) then raise exception 'Active account required' using errcode='42501'; end if;
  perform 1 from public.profiles where id=p_user_id for update;
  if exists(select 1 from public.deliverer_profiles where user_id=p_user_id and verification_status='approved') then
    raise exception 'Approved transport changes require administrator review' using errcode='P0001'; end if;
  select * into application from public.verification_applications where user_id=p_user_id and status in ('not_started','submitted','under_review');
  if found then
    if application.status<>'not_started' then raise exception 'Application is already submitted' using errcode='P0001'; end if;
    update public.verification_applications set identity_info=p_input->'identity',transport_info=jsonb_build_object('transportType',p_input->>'transportType'),
      safety_declarations=p_input->'safety' where id=application.id returning * into application;
  else
    insert into public.verification_applications(user_id,identity_info,transport_info,safety_declarations)
    values(p_user_id,p_input->'identity',jsonb_build_object('transportType',p_input->>'transportType'),p_input->'safety') returning * into application;
  end if;
  insert into public.deliverer_profiles(user_id,transport_type) values(p_user_id,(p_input->>'transportType')::public.transport_type)
  on conflict(user_id) do update set transport_type=excluded.transport_type,verification_status='not_started',availability_status='offline';
  return application;
end;
$$;
create function public.reserve_verification_document(p_user_id uuid,p_application_id uuid,p_type text,p_path text,p_mime text)
returns public.verification_documents language plpgsql set search_path='' as $$
declare application public.verification_applications; document public.verification_documents;
begin
  select * into application from public.verification_applications where id=p_application_id and user_id=p_user_id for update;
  if not found or application.status<>'not_started' then raise exception 'Editable application required' using errcode='42501'; end if;
  insert into public.verification_documents(application_id,user_id,document_type,storage_path,mime_type,size_bytes)
  values(application.id,p_user_id,p_type,p_path,p_mime,1)
  on conflict(application_id,document_type) do update set storage_path=excluded.storage_path,mime_type=excluded.mime_type,size_bytes=1,upload_verified_at=null
  returning * into document;
  return document;
end;
$$;
create function public.confirm_verification_document(p_user_id uuid,p_document_id uuid,p_path text,p_size integer)
returns public.verification_documents language plpgsql set search_path='' as $$
declare document public.verification_documents;
begin
  select d.* into document from public.verification_documents d join public.verification_applications a on a.id=d.application_id
  where d.id=p_document_id and d.user_id=p_user_id and a.status='not_started' for update of a,d;
  if not found or document.storage_path<>p_path or p_size not between 1 and 10485760 then raise exception 'Document cannot be confirmed' using errcode='P0001'; end if;
  update public.verification_documents set size_bytes=p_size,upload_verified_at=now() where id=document.id returning * into document;
  return document;
end;
$$;
create function public.submit_deliverer_application(p_user_id uuid,p_application_id uuid) returns public.verification_applications
language plpgsql set search_path='' as $$
declare application public.verification_applications; requirements text[];
begin
  select * into application from public.verification_applications where id=p_application_id and user_id=p_user_id for update;
  if not found then raise exception 'Application not found' using errcode='P0002'; end if;
  if application.status in ('submitted','under_review') then return application; end if;
  if application.status<>'not_started' then raise exception 'Application cannot be submitted' using errcode='P0001'; end if;
  select required_documents into requirements from public.verification_requirements where transport_type=(application.transport_info->>'transportType')::public.transport_type;
  if requirements is null or exists(select 1 from unnest(requirements) required where not exists(
    select 1 from public.verification_documents where application_id=application.id and document_type=required and upload_verified_at is not null)) then
    raise exception 'Required verification documents are missing' using errcode='P0001'; end if;
  update public.verification_applications set status='submitted' where id=application.id returning * into application;
  update public.profiles set verification_status='submitted' where id=p_user_id;
  update public.deliverer_profiles set verification_status='submitted',availability_status='offline' where user_id=p_user_id;
  return application;
end;
$$;
create function public.review_deliverer_application(p_admin_id uuid,p_application_id uuid,p_status public.verification_status,p_notes text)
returns public.verification_applications language plpgsql set search_path='' as $$
declare application public.verification_applications; previous public.verification_applications;
begin
  if not public.account_is_active(p_admin_id) or not exists(select 1 from public.user_roles where user_id=p_admin_id and role in ('verification_agent','admin','super_admin')) then
    raise exception 'Verification review permission required' using errcode='42501'; end if;
  select * into application from public.verification_applications where id=p_application_id for update;
  if not found then raise exception 'Application not found' using errcode='P0002'; end if;
  if p_admin_id=application.user_id then raise exception 'Self approval is prohibited' using errcode='42501'; end if;
  previous:=application;
  if not ((application.status='submitted' and p_status in ('under_review','rejected')) or
    (application.status='under_review' and p_status in ('approved','rejected')) or
    (application.status='approved' and p_status='suspended')) then raise exception 'Invalid verification transition' using errcode='P0001'; end if;
  update public.verification_applications set status=p_status,reviewed_by=p_admin_id,reviewed_at=now(),review_notes=p_notes
  where id=application.id returning * into application;
  update public.profiles set verification_status=p_status,active_role=case when p_status in ('rejected','suspended') then 'sender'::public.user_role else active_role end where id=application.user_id;
  update public.deliverer_profiles set verification_status=p_status,availability_status='offline' where user_id=application.user_id;
  if p_status='approved' then insert into public.user_roles(user_id,role) values(application.user_id,'deliverer') on conflict do nothing;
  elsif p_status in ('rejected','suspended') then delete from public.user_roles where user_id=application.user_id and role='deliverer'; end if;
  insert into public.audit_logs(admin_id,action,entity,entity_id,previous_state,new_state)
  values(p_admin_id,'verification_review','verification_application',application.id,to_jsonb(previous),to_jsonb(application));
  insert into public.notifications(user_id,type,title,body,data) values(application.user_id,'verification_update','Verification updated',
    'Your delivery verification has been reviewed.',jsonb_build_object('applicationId',application.id,'status',p_status));
  return application;
end;
$$;
do $$ declare fn regprocedure;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[
    'start_deliverer_application','reserve_verification_document','confirm_verification_document','submit_deliverer_application','review_deliverer_application']) loop
    execute format('revoke all on function %s from public,anon,authenticated',fn);
    execute format('grant execute on function %s to service_role',fn);
  end loop;
end;
$$;
commit;
