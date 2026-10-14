import { z } from 'zod';
import { pointSchema } from './delivery.js';

export const coverageSchema = pointSchema.extend({
  radiusMeters: z.number().int().min(100).max(100000),
  label: z.string().trim().min(2).max(120),
}).strict();
export const adInputSchema = z.object({
  title: z.string().trim().min(3).max(120),
  pickupCoverage: coverageSchema,
  destinationCoverage: coverageSchema,
  priceMinor: z.number().int().positive().max(100000000),
  availableFrom: z.string().datetime({ offset: true }),
  availableUntil: z.string().datetime({ offset: true }),
  notes: z.string().trim().max(2000).default(''),
}).strict().refine(input => Date.parse(input.availableUntil) > Date.parse(input.availableFrom),
  { message: 'Availability must end after it starts.', path: ['availableUntil'] })
  .refine(input => Date.parse(input.availableUntil) > Date.now(),
    { message: 'Availability must end in the future.', path: ['availableUntil'] });
export type AdInput = z.infer<typeof adInputSchema>;
export const adStatusSchema = z.object({ status: z.enum(['published', 'paused']) }).strict();
const queryNumber = z.string().trim().min(1).pipe(z.coerce.number().finite());
export const adBrowseSchema = z.object({
  pickupLatitude: queryNumber.refine(n => n >= -90 && n <= 90),
  pickupLongitude: queryNumber.refine(n => n >= -180 && n <= 180),
  destinationLatitude: queryNumber.refine(n => n >= -90 && n <= 90),
  destinationLongitude: queryNumber.refine(n => n >= -180 && n <= 180),
  weightKg: z.coerce.number().positive().max(10000),
  limit: z.coerce.number().int().min(1).max(50).default(25),
  offset: z.coerce.number().int().nonnegative().max(10000).default(0),
}).strict();
