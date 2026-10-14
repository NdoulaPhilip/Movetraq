import { supabaseAdmin } from '../config/supabase.js';
import { ApiError } from '../utils/api-error.js';
import type { AddressInput } from '../validators/account.js';

export function databaseError(error: { code?: string } | null) {
  if (!error) return;
  if (error.code === '23505') throw new ApiError(409, 'CONFLICT', 'This record already exists.');
  if (error.code === '23503') throw new ApiError(404, 'NOT_FOUND', 'The referenced record was not found.');
  if (error.code === 'P0002') throw new ApiError(404, 'NOT_FOUND', 'The record was not found.');
  throw new ApiError(503, 'DATABASE_UNAVAILABLE', 'Could not save or load account data.');
}

export async function loadAccount(userId: string) {
  const results = await Promise.all([
    supabaseAdmin.from('profiles').select('*').eq('id', userId).maybeSingle(),
    supabaseAdmin.from('user_roles').select('role').eq('user_id', userId),
    supabaseAdmin.from('wallet_accounts').select('id,currency,status').eq('user_id', userId).maybeSingle(),
    supabaseAdmin.from('wallet_balances').select('balance_minor').eq('user_id', userId).maybeSingle(),
    supabaseAdmin.from('deliverer_profiles').select('availability_status,transport_type,verification_status').eq('user_id', userId).maybeSingle(),
    supabaseAdmin.from('security_settings').select('deleted_at,suspended_at').eq('user_id', userId).maybeSingle(),
  ]);
  results.forEach((result) => databaseError(result.error));
  const [profile, roles, wallet, balance, deliverer, security] = results;
  if (!profile.data) throw new ApiError(404, 'PROFILE_NOT_FOUND', 'Account setup is incomplete.');
  if (!security.data) throw new ApiError(503, 'ACCOUNT_UNAVAILABLE', 'Could not verify account status.');
  if (security.data.deleted_at || security.data.suspended_at) throw new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
  const balanceMinor = Number(balance.data?.balance_minor ?? 0);
  if (!Number.isSafeInteger(balanceMinor)) throw new ApiError(503, 'INVALID_WALLET_BALANCE', 'Wallet balance requires reconciliation.');
  return { profile: profile.data, roles: roles.data ?? [], wallet: wallet.data,
    balanceMinor, deliverer: deliverer.data };
}

export async function patchProfile(userId: string, patch: Record<string, unknown>) {
  const { data, error } = await supabaseAdmin.from('profiles').update(patch).eq('id', userId).select('id').maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'PROFILE_NOT_FOUND', 'Account setup is incomplete.');
}

export async function listAddresses(userId: string) {
  const { data, error } = await supabaseAdmin.from('saved_addresses').select('*').eq('user_id', userId).order('created_at');
  databaseError(error);
  return data ?? [];
}
export async function saveAddress(userId: string, id: string | null, input: AddressInput) {
  const { data, error } = await supabaseAdmin.rpc('save_account_address', {
    p_user_id: userId, p_address_id: id, p_input: {
      label: input.label, address: input.address, latitude: input.latitude, longitude: input.longitude,
      place_id: input.placeId ?? null, city: input.city ?? null, state: input.state ?? null,
      country: input.country, is_default: input.isDefault,
    },
  });
  databaseError(error);
  return data;
}
export async function deleteAddress(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.from('saved_addresses').delete().eq('user_id', userId).eq('id', id).select('id').maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'ADDRESS_NOT_FOUND', 'Address was not found.');
}

export async function setDefaultAddress(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.rpc('set_default_account_address', {
    p_user_id: userId, p_address_id: id,
  });
  databaseError(error);
  return data;
}

type PreferencesTable = 'user_preferences' | 'notification_preferences';
export async function readPreferences(table: PreferencesTable, userId: string) {
  const { data, error } = await supabaseAdmin.from(table).select('*').eq('user_id', userId).single();
  databaseError(error);
  return data;
}
export async function writePreferences(table: PreferencesTable, userId: string, patch: Record<string, unknown>) {
  const { data, error } = await supabaseAdmin.from(table).update(patch).eq('user_id', userId).select('*').single();
  databaseError(error);
  return data;
}
export async function listBlocks(userId: string) {
  const { data, error } = await supabaseAdmin.from('blocked_users').select('blocked_id,reason,created_at').eq('blocker_id', userId).order('created_at', { ascending: false });
  databaseError(error);
  return data ?? [];
}
export async function blockUser(userId: string, blockedId: string, reason?: string) {
  const { error } = await supabaseAdmin.from('blocked_users').upsert({ blocker_id: userId, blocked_id: blockedId, reason: reason ?? null });
  databaseError(error);
}
export async function unblockUser(userId: string, blockedId: string) {
  const { error } = await supabaseAdmin.from('blocked_users').delete().eq('blocker_id', userId).eq('blocked_id', blockedId);
  databaseError(error);
}
export async function listNotifications(userId: string, limit: number, offset: number) {
  const { data, error } = await supabaseAdmin.from('notifications').select('*').eq('user_id', userId)
    .order('created_at', { ascending: false }).order('id', { ascending: false }).range(offset, offset + limit - 1);
  databaseError(error);
  return data ?? [];
}
export async function readNotification(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.from('notifications').select('id,read_at').eq('user_id', userId).eq('id', id).maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'NOTIFICATION_NOT_FOUND', 'Notification was not found.');
  if (data.read_at) return data;
  const result = await supabaseAdmin.from('notifications').update({ read_at: new Date().toISOString() })
    .eq('user_id', userId).eq('id', id).is('read_at', null).select('id,read_at').maybeSingle();
  databaseError(result.error);
  return result.data ?? data;
}
export async function listLedger(userId: string, limit: number, offset: number) {
  const { data, error } = await supabaseAdmin.from('wallet_ledger_entries')
    .select('id,order_id,type,amount_minor,currency,provider_reference,created_at')
    .eq('user_id', userId).order('created_at', { ascending: false }).order('id', { ascending: false }).range(offset, offset + limit - 1);
  databaseError(error);
  return data ?? [];
}

export async function countUnreadNotifications(userId: string) {
  const { count, error } = await supabaseAdmin.from('notifications')
    .select('id', { count: 'exact', head: true }).eq('user_id', userId).is('read_at', null);
  databaseError(error);
  return count ?? 0;
}

export async function readAllNotifications(userId: string) {
  const { count, error } = await supabaseAdmin.from('notifications')
    .update({ read_at: new Date().toISOString() }, { count: 'exact' })
    .eq('user_id', userId).is('read_at', null);
  databaseError(error);
  return count ?? 0;
}

export async function deleteNotification(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.from('notifications').delete()
    .eq('user_id', userId).eq('id', id).select('id').maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'NOTIFICATION_NOT_FOUND', 'Notification was not found.');
}

export async function clearNotifications(userId: string) {
  const { count, error } = await supabaseAdmin.from('notifications')
    .delete({ count: 'exact' }).eq('user_id', userId);
  databaseError(error);
  return count ?? 0;
}
