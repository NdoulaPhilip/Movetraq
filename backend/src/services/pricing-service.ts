import type { RouteMetrics } from '../integrations/maps.js';
import type { PricingRule, QuoteInput } from '../validators/delivery.js';
import { ApiError } from '../utils/api-error.js';

export function calculatePrice(input: QuoteInput, route: RouteMetrics, rule: PricingRule) {
  if (route.distanceMeters > rule.maxDistanceMeters) throw new ApiError(422, 'OUTSIDE_COVERAGE', 'This route is outside the configured service coverage.');
  const distanceMinor = Math.ceil(route.distanceMeters * rule.perKmMinor / 1000);
  const timeMinor = Math.ceil(route.durationSeconds * rule.perMinuteMinor / 60);
  const helpersMinor = input.serviceType === 'big_move' ? input.serviceDetails.helpers * rule.helperMinor : 0;
  const accessMinor = input.serviceType === 'big_move' ?
    ([input.serviceDetails.pickupAccess, input.serviceDetails.destinationAccess].filter((value) => value === 'stairs').length * rule.stairsMinor) : 0;
  const vehicleBps = input.serviceType === 'big_move' ? rule.vehicleBps[input.serviceDetails.vehicleSize] : 10000;
  const subtotal = rule.baseMinor + distanceMinor + timeMinor + helpersMinor + accessMinor;
  const calculated = Math.ceil(Math.ceil(subtotal * vehicleBps / 10000) * rule.surgeBps / 10000);
  const totalMinor = input.serviceType === 'p2p' ? input.offerMinor : Math.max(rule.minimumMinor, calculated);
  if (!Number.isSafeInteger(totalMinor) || totalMinor < rule.minimumMinor || totalMinor > 100000000) {
    throw new ApiError(422, 'INVALID_QUOTE_AMOUNT', 'The delivery price is outside the supported range.');
  }
  const platformFeeMinor = Math.floor(totalMinor * rule.platformFeeBps / 10000);
  return { totalMinor, platformFeeMinor, delivererPayoutMinor: totalMinor - platformFeeMinor,
    breakdown: { baseMinor: rule.baseMinor, platformFeeBps: rule.platformFeeBps, distanceMinor, timeMinor, helpersMinor, accessMinor, vehicleBps,
      surgeBps: rule.surgeBps, shoppingBudgetMinor: input.serviceType === 'errand' ? input.serviceDetails.shoppingBudgetMinor : 0,
      shoppingBudgetCharged: false, source: input.serviceType === 'p2p' ? 'validated_sender_offer' : 'configured_tariff' } };
}
