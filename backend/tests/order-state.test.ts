import { describe, expect, it } from 'vitest';
import { allowedOrderTransitions, assertOrderTransition } from '../src/services/order-state.js';

describe('order state machine', () => {
  it('allows the funded P2P path toward dispatch', () => {
    expect(() => assertOrderTransition('pending_payment', 'awaiting_deliverer')).not.toThrow();
    expect(() => assertOrderTransition('awaiting_deliverer', 'offer_received')).not.toThrow();
    expect(() => assertOrderTransition('offer_received', 'deliverer_assigned')).not.toThrow();
  });

  it('blocks arbitrary completion', () => {
    expect(() => assertOrderTransition('pending_payment', 'completed')).toThrow('Order cannot move');
  });

  it('keeps completed orders terminal', () => {
    expect(allowedOrderTransitions('completed')).toEqual([]);
  });
});
