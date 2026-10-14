import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { ApiError } from '../utils/api-error.js';

export async function reserveTopup(userId: string, amountMinor: number, key: string, reference: string) {
  const { data, error } = await supabaseAdmin.rpc('reserve_wallet_topup', {
    p_user_id: userId, p_amount_minor: amountMinor, p_key: key, p_reference: reference,
  });
  if (error?.code === '22023') {
    throw new ApiError(409, 'IDEMPOTENCY_CONFLICT', 'This request key was already used for a different payment.');
  }
  databaseError(error);
  return data;
}
export async function findPayment(reference: string, userId?: string) {
  let query = supabaseAdmin.from('payments').select('id,user_id,provider_reference,provider,status,amount_minor,currency,checkout_url,verified_at').eq('provider_reference', reference);
  if (userId) query = query.eq('user_id', userId);
  const { data, error } = await query.maybeSingle();
  databaseError(error);
  return data;
}
export async function saveCheckout(reference: string, checkoutUrl: string) {
  const { error } = await supabaseAdmin.from('payments').update({ checkout_url: checkoutUrl, status: 'initialized' })
    .eq('provider_reference', reference).eq('status', 'created');
  databaseError(error);
}
export async function creditVerifiedTopup(reference: string, amountMinor: number, currency: string) {
  const { data, error } = await supabaseAdmin.rpc('credit_verified_topup', {
    p_reference: reference, p_amount_minor: amountMinor, p_currency: currency,
  });
  databaseError(error);
  return data;
}
