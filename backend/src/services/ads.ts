import * as repository from '../repositories/ad-repository.js';
import { deliveryRpc } from '../repositories/delivery-repository.js';
import type { AdInput } from '../validators/ads.js';
import type { z } from 'zod';
import type { adBrowseSchema } from '../validators/ads.js';

export const listOwnAds = repository.ownAds;
export const getOwnAd = repository.ownAd;
export function saveAd(userId: string, id: string | null, input: AdInput, key: string | null) {
  return deliveryRpc('save_delivery_ad', { p_actor: userId, p_id: id, p_input: input, p_key: key });
}
export function changeAdStatus(userId: string, id: string, status: 'published' | 'paused' | 'deleted') {
  return deliveryRpc('change_delivery_ad_status', { p_actor: userId, p_id: id, p_status: status });
}
export function browseAds(userId: string, input: z.infer<typeof adBrowseSchema>) {
  return deliveryRpc('browse_delivery_ads', { p_actor: userId, p_input: input });
}
