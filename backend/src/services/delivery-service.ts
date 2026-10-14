import { mapService } from '../integrations/maps.js';
import * as repository from '../repositories/delivery-repository.js';
import { calculatePrice } from './pricing-service.js';
import { pricingRuleSchema, type QuoteInput } from '../validators/delivery.js';

export async function quoteDelivery(userId: string, input: QuoteInput) {
  const rule = await repository.pricingRule(input.serviceType);
  const configuration = pricingRuleSchema.parse(rule.configuration);
  const route = await mapService.route(input.pickup, input.destination);
  const pricing = calculatePrice(input, route, configuration);
  return repository.insertQuote({ user_id: userId, service_type: input.serviceType, input,
    pricing_rule_id: rule.id, route, total_amount_minor: pricing.totalMinor, platform_fee_minor: pricing.platformFeeMinor,
    deliverer_payout_minor: pricing.delivererPayoutMinor, pricing_breakdown: pricing.breakdown,
    expires_at: new Date(Date.now() + 10 * 60000).toISOString() });
}
