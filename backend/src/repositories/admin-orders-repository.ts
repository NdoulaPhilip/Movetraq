import type { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { ApiError } from '../utils/api-error.js';
import type { adminOrderQuery } from '../validators/admin-orders.js';

const summaryColumns = 'id,public_ref,service_type,status,total_amount_minor,currency,payment_status,escrow_status,created_at';
const detailColumns = `${summaryColumns},sender_id,deliverer_id,pickup_address,pickup_latitude,pickup_longitude,destination_address,destination_latitude,destination_longitude,recipient_name,recipient_phone,platform_fee_minor,deliverer_payout_minor,scheduled_at,scheduled_timezone,accepted_at,pickup_at,delivered_at,completed_at,cancelled_at,cancellation_reason,evidence_status,issue_status`;

export async function managedOrders(input: z.infer<typeof adminOrderQuery>) {
  let query = supabaseAdmin.from('orders').select(summaryColumns, { count: 'exact' });
  if (input.reference) query = query.ilike('public_ref', `%${input.reference}%`);
  if (input.status) query = query.eq('status', input.status);
  if (input.serviceType) query = query.eq('service_type', input.serviceType);
  const { data, error, count } = await query.order('created_at', { ascending: false }).order('id')
    .range(input.page * 25, input.page * 25 + 24);
  databaseError(error);
  return { orders: data ?? [], total: count ?? 0, page: input.page };
}

export async function managedOrder(id: string) {
  // Explicit projections keep handover secrets, private storage paths and message bodies out of the console.
  const { data: order, error } = await supabaseAdmin.from('orders').select(detailColumns).eq('id', id).maybeSingle();
  databaseError(error);
  if (!order) throw new ApiError(404, 'ORDER_NOT_FOUND', 'Order was not found.');
  const { data: timeline, error: timelineError } = await supabaseAdmin.from('order_events')
    .select('id,event_type,previous_status,new_status,created_at').eq('order_id', id)
    .order('created_at', { ascending: false }).order('id').limit(100);
  databaseError(timelineError);
  return { order, timeline: timeline ?? [] };
}
