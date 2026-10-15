import { asyncHandler } from '../utils/async-handler.js';
import { created, ok } from '../utils/responses.js';
import { deliveryRpc } from '../repositories/delivery-repository.js';
import { returnStatus, supportCases } from '../repositories/support-repository.js';
import { idSchema, paginationSchema } from '../validators/account.js';
import { idempotencyKey } from '../validators/delivery.js';
import * as schemas from '../validators/support.js';
import * as evidence from '../services/evidence-service.js';
import { assertApprovedDeliverer } from '../services/deliverer-access.js';

export const open = asyncHandler(async (req, res) => {
  const input = schemas.supportCaseSchema.parse(req.body);
  created(res, await deliveryRpc('open_support_case', { p_actor_id: req.user!.id, p_order_id: input.orderId,
    p_category: input.category, p_description: input.description, p_key: idempotencyKey.parse(req.header('idempotency-key')) }));
});
export const list = asyncHandler(async (req, res) => { const { limit, offset } = paginationSchema.parse(req.query);
  ok(res, { cases: await supportCases(req.user!.id, limit, offset), limit, offset }); });
export const queue = asyncHandler(async (req, res) => { const { limit, offset } = paginationSchema.parse(req.query);
  ok(res, { cases: await supportCases(null, limit, offset), limit, offset }); });
export const review = asyncHandler(async (req, res) => { ok(res, await deliveryRpc('review_support_case', {
  p_admin_id: req.user!.id, p_case_id: idSchema.parse(req.params.id), p_input: schemas.reviewCaseSchema.parse(req.body),
})); });
export const requestReturn = asyncHandler(async (req, res) => { ok(res, await deliveryRpc('request_delivery_return', {
  p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_reason: schemas.reasonSchema.parse(req.body).reason,
})); });
export const getReturn = asyncHandler(async (req, res) => { ok(res, { returnRequest: await returnStatus(req.user!.id, idSchema.parse(req.params.id)) }); });
export const approveReturn = asyncHandler(async (req, res) => { ok(res, await deliveryRpc('approve_delivery_return', {
  p_admin_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_notes: schemas.reasonSchema.parse(req.body).reason,
})); });
export const settle = asyncHandler(async (req, res) => { const input = schemas.settlementSchema.parse(req.body);
  ok(res, await deliveryRpc('settle_delivery_dispute', { p_admin_id: req.user!.id, p_order_id: idSchema.parse(req.params.id),
    p_decision: input.decision, p_resolution: input.resolution, p_key: idempotencyKey.parse(req.header('idempotency-key')) })); });
export const reserveEvidence = asyncHandler(async (req, res) => { await assertApprovedDeliverer(req.user!);created(res, await evidence.reservePhoto(req.user!.id, idSchema.parse(req.params.id), schemas.evidenceSchema.parse(req.body).mimeType)); });
export const confirmEvidence = asyncHandler(async (req, res) => { await assertApprovedDeliverer(req.user!);ok(res, await evidence.confirmPhoto(req.user!.id, idSchema.parse(req.params.id))); });
export const evidenceHistory = asyncHandler(async (req, res) => { ok(res, { evidence: await evidence.evidenceList(req.user!, idSchema.parse(req.params.id)) }); });
export const downloadEvidence = asyncHandler(async (req, res) => { ok(res, await evidence.evidenceDownload(req.user!, idSchema.parse(req.params.id))); });
export const rate = asyncHandler(async (req, res) => { const input = schemas.ratingSchema.parse(req.body);
  created(res, await deliveryRpc('rate_completed_delivery', { p_actor_id: req.user!.id, p_order_id: idSchema.parse(req.params.id), p_rating: input.rating, p_review: input.review ?? null })); });
