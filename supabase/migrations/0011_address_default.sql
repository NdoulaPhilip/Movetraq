begin;

create function public.set_default_account_address(p_user_id uuid, p_address_id uuid)
returns public.saved_addresses language plpgsql set search_path = '' as $$
declare saved public.saved_addresses;
begin
  -- Use the same account lock as address saves to serialize default changes.
  perform 1 from public.profiles where id = p_user_id for update;
  if not found then raise exception 'Account not found' using errcode = 'P0002'; end if;
  select * into saved from public.saved_addresses
    where id = p_address_id and user_id = p_user_id for update;
  if not found then raise exception 'Address not found' using errcode = 'P0002'; end if;
  update public.saved_addresses set is_default = false
    where user_id = p_user_id and is_default and id <> p_address_id;
  update public.saved_addresses set is_default = true
    where id = p_address_id and user_id = p_user_id returning * into saved;
  return saved;
end;
$$;
revoke all on function public.set_default_account_address(uuid, uuid) from public, anon, authenticated;
grant execute on function public.set_default_account_address(uuid, uuid) to service_role;

commit;
