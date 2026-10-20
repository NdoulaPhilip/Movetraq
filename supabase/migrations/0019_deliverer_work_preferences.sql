begin;

-- Work configuration belongs to the reviewed application, including legacy mobile identities.
alter table public.verification_applications add column work_preferences jsonb not null default '{}'::jsonb
  check (jsonb_typeof(work_preferences)='object');

create function public.mobile_deliverer_preferences(p_user text,p_patch jsonb default null) returns jsonb
language plpgsql set search_path='' as $$
declare a public.verification_applications; defaults jsonb; item record;
begin
  select * into a from public.verification_applications where legacy_user_id=p_user for update;
  if not found or a.status<>'approved' then
    raise exception 'Approved deliverer required for work preferences' using errcode='42501';
  end if;
  defaults:=jsonb_build_object('transport',a.transport_info->>'transportType','delivery_area','',
    'p2p',true,'express',false,'errand',false,'big_move',false,'new_job_alerts',true,'pickup_reminders',true);
  if p_patch is not null then
    if jsonb_typeof(p_patch)<>'object' or p_patch='{}'::jsonb then
      raise exception 'Provide work preferences' using errcode='22023';
    end if;
    for item in select key,value from jsonb_each(p_patch) loop
      if item.key in ('p2p','express','errand','big_move','new_job_alerts','pickup_reminders') then
        if jsonb_typeof(item.value)<>'boolean' then raise exception 'Invalid work preference' using errcode='22023'; end if;
      elsif item.key='delivery_area' then
        if jsonb_typeof(item.value)<>'string' or length(item.value#>>'{}')>200 then raise exception 'Invalid delivery area' using errcode='22023'; end if;
      elsif item.key='transport' then
        if jsonb_typeof(item.value)<>'string' or (item.value#>>'{}') is distinct from a.transport_info->>'transportType' then
          raise exception 'Transport change requires verification review' using errcode='P0001'; end if;
      else raise exception 'Unknown work preference' using errcode='22023';
      end if;
    end loop;
    update public.verification_applications set work_preferences=work_preferences||p_patch where id=a.id returning * into a;
  end if;
  return jsonb_build_object('delivery_preferences',defaults||a.work_preferences,'verification_status',a.status);
end $$;

revoke all on function public.mobile_deliverer_preferences(text,jsonb) from public,anon,authenticated;
grant execute on function public.mobile_deliverer_preferences(text,jsonb) to service_role;
-- Keep the existing column-level application write restrictions for client roles.
commit;
