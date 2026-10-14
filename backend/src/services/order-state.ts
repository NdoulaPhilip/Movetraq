import { ApiError } from '../utils/api-error.js';

export const orderStatuses = [
  'draft',
  'pending_payment',
  'awaiting_deliverer',
  'offer_received',
  'deliverer_assigned',
  'accepted',
  'heading_to_pickup',
  'arrived_pickup',
  'picked_up',
  'heading_to_dropoff',
  'arrived_dropoff',
  'awaiting_confirmation',
  'completed',
  'cancelled',
  'rejected',
  'failed',
  'returning',
  'returned',
  'disputed',
] as const;

export type OrderStatus = (typeof orderStatuses)[number];

const transitions: Record<OrderStatus, OrderStatus[]> = {
  draft: ['pending_payment', 'cancelled'],
  pending_payment: ['awaiting_deliverer', 'cancelled', 'failed'],
  awaiting_deliverer: ['offer_received', 'deliverer_assigned', 'cancelled'],
  offer_received: ['deliverer_assigned', 'rejected', 'cancelled'],
  deliverer_assigned: ['accepted', 'rejected', 'cancelled'],
  accepted: ['heading_to_pickup', 'cancelled'],
  heading_to_pickup: ['arrived_pickup', 'failed', 'returning'],
  arrived_pickup: ['picked_up', 'failed', 'returning'],
  picked_up: ['heading_to_dropoff', 'failed', 'returning'],
  heading_to_dropoff: ['arrived_dropoff', 'failed', 'returning'],
  arrived_dropoff: ['awaiting_confirmation', 'failed', 'returning'],
  awaiting_confirmation: ['completed', 'disputed'],
  completed: [],
  cancelled: [],
  rejected: ['awaiting_deliverer'],
  failed: ['returning', 'disputed'],
  returning: ['returned', 'disputed'],
  returned: ['disputed'],
  disputed: ['completed', 'cancelled', 'returned'],
};

export function assertOrderTransition(from: OrderStatus, to: OrderStatus) {
  if (!transitions[from]?.includes(to)) {
    throw new ApiError(
      409,
      'INVALID_ORDER_TRANSITION',
      `Order cannot move from ${from} to ${to}.`,
      { from, to, allowed: transitions[from] ?? [] },
    );
  }
}

export function allowedOrderTransitions(from: OrderStatus) {
  return transitions[from] ?? [];
}
