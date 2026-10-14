import { asyncHandler } from '../utils/async-handler.js';
import { created, ok } from '../utils/responses.js';
import { idSchema, paginationSchema } from '../validators/account.js';
import { idempotencyKey } from '../validators/delivery.js';
import { adBrowseSchema, adInputSchema, adStatusSchema } from '../validators/ads.js';
import * as service from '../services/ads.js';

export const own = asyncHandler(async (req, res) => {
  const { limit, offset } = paginationSchema.parse(req.query);
  ok(res, { ads: await service.listOwnAds(req.user!.id, limit, offset) });
});
export const detail = asyncHandler(async (req, res) => {
  ok(res, { ad: await service.getOwnAd(req.user!.id, idSchema.parse(req.params.id)) });
});
export const browse = asyncHandler(async (req, res) => {
  ok(res, { ads: await service.browseAds(req.user!.id, adBrowseSchema.parse(req.query)) });
});
export const create = asyncHandler(async (req, res) => {
  const input = adInputSchema.parse(req.body);
  const key = idempotencyKey.parse(req.header('idempotency-key'));
  created(res, { ad: await service.saveAd(req.user!.id, null, input, key) });
});
export const update = asyncHandler(async (req, res) => {
  const id = idSchema.parse(req.params.id);
  if (req.body && typeof req.body === 'object' && 'status' in req.body) {
    ok(res, { ad: await service.changeAdStatus(req.user!.id, id, adStatusSchema.parse(req.body).status) });
    return;
  }
  ok(res, { ad: await service.saveAd(req.user!.id, id, adInputSchema.parse(req.body), null) });
});
export const remove = asyncHandler(async (req, res) => {
  ok(res, { ad: await service.changeAdStatus(req.user!.id, idSchema.parse(req.params.id), 'deleted') });
});
