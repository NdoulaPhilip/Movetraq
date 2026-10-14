import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { participantOrder } from './delivery-repository.js';

export async function supportCases(userId: string | null, limit: number, offset: number) {
  const columns = userId ? 'id,order_id,category,description,status,priority,resolution,created_at,updated_at' : '*';
  let query = supabaseAdmin.from('support_tickets').select(columns).order('created_at', { ascending: false }).order('id');
  if (userId) query = query.eq('reporter_id', userId);
  const { data, error } = await query.range(offset, offset + limit - 1);
  databaseError(error); return data ?? [];
}
export async function returnStatus(userId: string, orderId: string) {
  await participantOrder(userId, orderId);
  const { data, error } = await supabaseAdmin.from('return_requests').select('status,reason,approved_at,created_at,updated_at').eq('order_id', orderId).maybeSingle();
  databaseError(error); return data;
}
