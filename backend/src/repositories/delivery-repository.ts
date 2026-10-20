import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { ApiError } from '../utils/api-error.js';

export function deliveryError(error: { code?: string; message?: string } | null) {
  if (!error) return;
  if (error.code === '42501' && error.message === 'Approved deliverer required for work preferences') {
    throw new ApiError(403, 'DELIVERER_APPROVAL_REQUIRED', 'Administrator approval is required before configuring delivery work preferences.');
  }
  if (error.code === '42501' && error.message === 'Self approval is prohibited') {
    throw new ApiError(403, 'SELF_REVIEW_FORBIDDEN', 'You cannot review your own deliverer application. Sign in with a different authorized reviewer account.');
  }
  if (error.code === '42501' && error.message === 'Verification review permission required') {
    throw new ApiError(403, 'VERIFICATION_REVIEW_FORBIDDEN', 'An active Verification Agent, Admin or Super Admin account is required to review deliverer applications.');
  }
  if (error.code === '42501') throw new ApiError(403, 'DELIVERY_FORBIDDEN', 'You are not allowed to perform this delivery action.');
  if (error.code === 'P0001' || error.code === '22023') throw new ApiError(409, 'DELIVERY_CONFLICT', error.message ?? 'Delivery action conflicts with the current state.');
  databaseError(error);
}
export async function deliveryRpc(name: string, args: Record<string, unknown>) {
  const { data, error } = await supabaseAdmin.rpc(name, args);
  deliveryError(error);
  if (data?.error) throw new ApiError(409, data.error, data.message ?? 'Delivery action failed.');
  return data;
}
export async function pricingRule(serviceType: string) {
  const { data, error } = await supabaseAdmin.from('pricing_rules').select('id,configuration').eq('service_type', serviceType).eq('enabled', true).maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(503, 'PRICING_NOT_CONFIGURED', 'Approved pricing is not configured for this service.');
  return data;
}
export async function insertQuote(row: Record<string, unknown>) {
  const { data, error } = await supabaseAdmin.from('delivery_quotes').insert(row).select('*').single();
  databaseError(error); return data;
}
export async function ownedOrders(userId: string, limit: number, offset: number) {
  const { data, error } = await supabaseAdmin.from('orders').select('*').or(`sender_id.eq.${userId},deliverer_id.eq.${userId}`)
    .order('created_at', { ascending: false }).order('id').range(offset, offset + limit - 1);
  databaseError(error); return data ?? [];
}
export async function participantOrder(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.from('orders').select('*').eq('id', id)
    .or(`sender_id.eq.${userId},deliverer_id.eq.${userId}`).maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'ORDER_NOT_FOUND', 'Order was not found.');
  return data;
}
