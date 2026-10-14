begin;
alter table public.user_preferences add column selected_address_id uuid;
alter table public.saved_addresses add constraint saved_address_owner_id unique(user_id,id);
alter table public.user_preferences add constraint selected_address_owner
  foreign key(user_id,selected_address_id) references public.saved_addresses(user_id,id) on delete set null(selected_address_id);

create function public.select_saved_address(p_user_id uuid,p_address_id uuid) returns public.user_preferences
language plpgsql set search_path='' as $$
declare preferences public.user_preferences;
begin
  perform 1 from public.saved_addresses where id=p_address_id and user_id=p_user_id for update;
  if not found then raise exception 'Address not found' using errcode='P0002'; end if;
  update public.user_preferences set selected_address_id=p_address_id where user_id=p_user_id returning * into preferences;
  return preferences;
end;
$$;
create function public.mark_order_messages_read(p_actor_id uuid,p_order_id uuid) returns jsonb language plpgsql set search_path='' as $$
declare unread integer;
begin
  if not exists(select 1 from public.conversations where order_id=p_order_id and p_actor_id in (sender_id,deliverer_id)) then raise exception 'Conversation access required' using errcode='42501'; end if;
  update public.messages m set read_at=now() from public.conversations c where c.id=m.conversation_id and c.order_id=p_order_id
    and p_actor_id in (c.sender_id,c.deliverer_id) and m.sender_id<>p_actor_id and m.read_at is null;
  get diagnostics unread=row_count;
  return jsonb_build_object('markedRead',unread);
end;
$$;
create function public.order_message_unread_count(p_actor_id uuid) returns bigint language sql stable set search_path='' as $$
  select count(*) from public.messages m join public.conversations c on c.id=m.conversation_id
  where p_actor_id in (c.sender_id,c.deliverer_id) and m.sender_id<>p_actor_id and m.read_at is null;
$$;
create or replace function public.send_order_message(p_actor_id uuid,p_order_id uuid,p_input jsonb) returns public.messages language plpgsql set search_path='' as $$
declare conversation public.conversations; message public.messages;
begin
  select * into conversation from public.conversations where order_id=p_order_id and closed_at is null for update;
  if not found or p_actor_id not in (conversation.sender_id,conversation.deliverer_id) or public.people_are_blocked(conversation.sender_id,conversation.deliverer_id) then
    raise exception 'Messaging is unavailable' using errcode='42501'; end if;
  insert into public.messages(conversation_id,sender_id,body,client_message_id,delivered_at)
  values(conversation.id,p_actor_id,p_input->>'body',p_input->>'clientMessageId',now())
  on conflict(conversation_id,client_message_id) do nothing returning * into message;
  if not found then
    select * into message from public.messages where conversation_id=conversation.id and client_message_id=p_input->>'clientMessageId';
    if message.sender_id<>p_actor_id or message.body is distinct from p_input->>'body' then raise exception 'Message retry conflicts with original' using errcode='P0001'; end if;
    return message;
  end if;
  insert into public.notifications(user_id,type,title,body,data) values(
    case when p_actor_id=conversation.sender_id then conversation.deliverer_id else conversation.sender_id end,
    'chat_message','New delivery message','You have a new message about your delivery.',jsonb_build_object('orderId',p_order_id,'messageId',message.id));
  return message;
end;
$$;
create function public.clear_expired_delivery_locations() returns bigint language plpgsql set search_path='' as $$
declare removed bigint;
begin
  delete from public.delivery_locations where updated_at<now()-interval '15 minutes';
  get diagnostics removed=row_count;
  return removed;
end;
$$;
do $$ declare fn regprocedure; relation text;
begin
  for fn in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname=any(array[
    'select_saved_address','mark_order_messages_read','order_message_unread_count','clear_expired_delivery_locations']) loop
    execute format('revoke all on function %s from public,anon,authenticated',fn);
    execute format('grant execute on function %s to service_role',fn);
  end loop;
  if exists(select 1 from pg_publication where pubname='supabase_realtime') then
    foreach relation in array array['orders','messages','notifications','delivery_locations','order_events'] loop
      if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename=relation) then
        execute format('alter publication supabase_realtime add table public.%I',relation);
      end if;
    end loop;
  end if;
end;
$$;
commit;
