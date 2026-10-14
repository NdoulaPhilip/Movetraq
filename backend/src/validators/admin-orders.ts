import { z } from 'zod';
import { serviceTypes } from './delivery.js';

export const adminOrderStatuses = ['draft', 'pending_payment', 'awaiting_deliverer', 'offer_received',
  'deliverer_assigned', 'accepted', 'heading_to_pickup', 'arrived_pickup', 'picked_up',
  'heading_to_dropoff', 'arrived_dropoff', 'awaiting_confirmation', 'completed', 'cancelled',
  'rejected', 'failed', 'returning', 'returned', 'disputed'] as const;
export const adminOrderQuery = z.object({
  reference: z.string().trim().regex(/^[A-Za-z0-9-]+$/).max(128).optional(),
  status: z.enum(adminOrderStatuses).optional(),
  serviceType: z.enum(serviceTypes).optional(),
  page: z.coerce.number().int().min(0).max(10000).default(0),
}).strict();
