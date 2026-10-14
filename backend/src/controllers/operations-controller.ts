import { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from '../repositories/account-repository.js';
import { deliveryRpc, participantOrder } from '../repositories/delivery-repository.js';
import { asyncHandler } from '../utils/async-handler.js';
import { created, ok } from '../utils/responses.js';
import { idSchema } from '../validators/account.js';
import { pricingRuleSchema, serviceTypes } from '../validators/delivery.js';

export const pricing = asyncHandler(async (_req, res) => {
  const { data, error } = await supabaseAdmin.from('pricing_rules').select('*').eq('enabled', true).order('service_type');
  databaseError(error); ok(res, { rules: data ?? [] });
});
export const activatePricing = asyncHandler(async (req, res) => {
  const input = z.object({ serviceType: z.enum(serviceTypes), configuration: pricingRuleSchema }).strict().parse(req.body);
  created(res, await deliveryRpc('activate_pricing_rule', { p_admin_id: req.user!.id, p_service_type: input.serviceType, p_configuration: input.configuration }));
});
export const candidates = asyncHandler(async (req, res) => {
  const candidates = await deliveryRpc('quote_deliverer_candidates', {
    p_user_id: req.user!.id, p_quote_id: idSchema.parse(req.params.id),
  });
  ok(res, { candidates });
});
export const summary = asyncHandler(async (req, res) => { ok(res, await deliveryRpc('deliverer_summary', { p_user_id: req.user!.id })); });
export const customers = asyncHandler(async (req, res) => { ok(res, { customers: await deliveryRpc('deliverer_past_customers', { p_user_id: req.user!.id }) }); });
export const receipt = asyncHandler(async (req, res) => {
  const order = await participantOrder(req.user!.id, idSchema.parse(req.params.id));
  ok(res, { orderId: order.id, reference: order.public_ref, serviceType: order.service_type, totalMinor: order.total_amount_minor,
    platformFeeMinor: order.platform_fee_minor, currency: order.currency, paymentStatus: order.payment_status,
    escrowStatus: order.escrow_status, completedAt: order.completed_at, pricingBreakdown: order.pricing_breakdown });
});
