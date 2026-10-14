import { describe, expect, it } from 'vitest';
import { calculatePrice } from '../src/services/pricing-service.js';
import { quoteSchema, commandSchema, type PricingRule, type QuoteInput } from '../src/validators/delivery.js';

const base = { pickup: { address: 'Ikeja Lagos', latitude: 6.6, longitude: 3.3 },
  destination: { address: 'Yaba Lagos', latitude: 6.5, longitude: 3.4 },
  recipient: { name: 'Recipient', phone: '+2348012345678' }, parcel: { description: 'Parcel', weightKg: 1 } };
const rule: PricingRule = { baseMinor: 10000, perKmMinor: 1000, perMinuteMinor: 100, helperMinor: 5000, stairsMinor: 2000,
  minimumMinor: 10000, platformFeeBps: 1000, surgeBps: 10000, vehicleBps: { car: 10000, van: 15000, large_van: 20000 }, maxDistanceMeters: 100000 };
const route = { distanceMeters: 12500, durationSeconds: 1800 };
describe('server delivery pricing', () => {
  it('prices express from the server tariff and provider route', () => {
    const input = quoteSchema.parse({ ...base, serviceType: 'express' });
    const result = calculatePrice(input, route, rule);
    expect(result.totalMinor).toBe(25500);
    expect(result.platformFeeMinor + result.delivererPayoutMinor).toBe(result.totalMinor);
  });
  it('never charges the shopping budget as an errand service fee', () => {
    const small = quoteSchema.parse({ ...base, serviceType: 'errand', serviceDetails: { task: 'shopping', instructions: 'Buy groceries', shoppingBudgetMinor: 10000 } });
    const large = quoteSchema.parse({ ...base, serviceType: 'errand', serviceDetails: { task: 'shopping', instructions: 'Buy groceries', shoppingBudgetMinor: 1000000 } });
    expect(calculatePrice(small, route, rule).totalMinor).toBe(calculatePrice(large, route, rule).totalMinor);
    expect(calculatePrice(large, route, rule).breakdown.shoppingBudgetCharged).toBe(false);
  });
  it('includes moving vehicle, helpers, access and configured surge', () => {
    const input = quoteSchema.parse({ ...base, serviceType: 'big_move', scheduledAt: new Date(Date.now() + 86400000).toISOString(),
      serviceDetails: { loadType: 'Furniture', items: 'Desk and chair', vehicleSize: 'van', helpers: 2, pickupAccess: 'stairs', destinationAccess: 'ground' } });
    expect(calculatePrice(input, route, { ...rule, surgeBps: 12000 }).totalMinor).toBe(67500);
  });
  it('validates a sender P2P offer against server minimum and computes payout', () => {
    const input = quoteSchema.parse({ ...base, serviceType: 'p2p', offerMinor: 50000 });
    expect(calculatePrice(input, route, rule).delivererPayoutMinor).toBe(45000);
    expect(() => calculatePrice({ ...input, offerMinor: 500 } as QuoteInput, route, rule)).toThrow('supported range');
  });
  it('rejects client totals and arbitrary status changes', () => {
    expect(quoteSchema.safeParse({ ...base, serviceType: 'express', totalMinor: 1 }).success).toBe(false);
    expect(commandSchema.safeParse({ command: 'completed', delivererPayoutMinor: 1000000 }).success).toBe(false);
    expect(commandSchema.safeParse({ command: 'fund', amountMinor: 1 }).success).toBe(false);
  });
  it('rejects routes outside configured coverage and past moving schedules', () => {
    expect(() => calculatePrice(quoteSchema.parse({ ...base, serviceType: 'express' }), { ...route, distanceMeters: 100001 }, rule)).toThrow('coverage');
    expect(quoteSchema.safeParse({ ...base, serviceType: 'big_move', scheduledAt: '2020-01-01T00:00:00Z', serviceDetails: {} }).success).toBe(false);
  });
});
