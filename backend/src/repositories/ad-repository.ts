import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { ApiError } from '../utils/api-error.js';

export const adColumns = 'id,deliverer_id,title,pickup_coverage,destination_coverage,price_minor,currency,availability,transport_type,notes,status,created_at,updated_at';
export async function ownAds(userId: string, limit: number, offset: number) {
  const { data, error } = await supabaseAdmin.from('p2p_ads').select(adColumns)
    .eq('deliverer_id', userId).in('status', ['draft', 'published', 'paused'])
    .order('created_at', { ascending: false }).order('id').range(offset, offset + limit - 1);
  databaseError(error);
  return data ?? [];
}
export async function ownAd(userId: string, id: string) {
  const { data, error } = await supabaseAdmin.from('p2p_ads').select(adColumns)
    .eq('deliverer_id', userId).eq('id', id).in('status', ['draft', 'published', 'paused']).maybeSingle();
  databaseError(error);
  if (!data) throw new ApiError(404, 'AD_NOT_FOUND', 'Delivery ad was not found.');
  return data;
}
