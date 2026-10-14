import { z } from 'zod';
export const supportCaseSchema = z.object({ orderId: z.string().uuid(),
  category: z.enum(['recipient_unreachable','incorrect_address','damaged_parcel','failed_delivery','return','payment_issue','deliverer_issue','sender_issue','other']),
  description: z.string().trim().min(3).max(4000) }).strict();
export const reviewCaseSchema = z.object({ status: z.enum(['open','investigating','waiting_user','waiting_deliverer','resolved','closed']),
  priority: z.enum(['low','normal','high','urgent']), internalNotes: z.string().trim().min(3).max(4000), resolution: z.string().trim().min(3).max(4000).optional(),
}).strict().refine((value) => !['resolved','closed'].includes(value.status) || !!value.resolution, 'A resolution is required.');
export const reasonSchema = z.object({ reason: z.string().trim().min(3).max(2000) }).strict();
export const settlementSchema = z.object({ decision: z.enum(['release','refund']), resolution: z.string().trim().min(3).max(4000) }).strict();
export const evidenceSchema = z.object({ mimeType: z.enum(['image/jpeg','image/png','image/webp']) }).strict();
export const ratingSchema = z.object({ rating: z.number().int().min(1).max(5), review: z.string().trim().min(1).max(2000).optional() }).strict();
