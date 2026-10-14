import { z } from 'zod';

export const serviceTypes = ['p2p', 'express', 'errand', 'big_move'] as const;
export const transportTypes = ['motorcycle', 'bicycle', 'walking', 'car', 'van', 'other_motor', 'other_non_motor'] as const;
export const idempotencyKey = z.string().min(16).max(128).regex(/^[A-Za-z0-9-]+$/);
export const pointSchema = z.object({ latitude: z.number().finite().min(-90).max(90), longitude: z.number().finite().min(-180).max(180) }).strict();
const address = pointSchema.extend({ address: z.string().trim().min(3).max(500), placeId: z.string().max(200).optional() });
const recipient = z.object({ name: z.string().trim().min(2).max(120), phone: z.string().regex(/^\+[1-9]\d{7,14}$/) }).strict();
const parcel = z.object({ description: z.string().trim().min(3).max(2000), weightKg: z.number().positive().max(10000), photoPath: z.string().max(500).optional() }).strict();
const schedule = z.string().datetime({ offset: true }).refine((value) => Date.parse(value) > Date.now(), 'Schedule must be in the future.');
const base = z.object({ pickup: address, destination: address, recipient, parcel,
  scheduledAt: schedule.optional(), scheduledTimezone: z.string().max(100).refine((value) => {
    try { new Intl.DateTimeFormat('en', { timeZone: value }); return true; } catch { return false; }
  }).optional() });
export const quoteSchema = z.discriminatedUnion('serviceType', [
  base.extend({ serviceType: z.literal('p2p'), offerMinor: z.number().int().positive().max(100000000),
    serviceDetails: z.object({ notes: z.string().max(2000).optional() }).strict().default({}) }).strict(),
  base.extend({ serviceType: z.literal('express'), serviceDetails: z.object({}).strict().default({}) }).strict(),
  base.extend({ serviceType: z.literal('errand'), serviceDetails: z.object({
    task: z.enum(['shopping', 'pickup_dropoff', 'other']), instructions: z.string().trim().min(3).max(4000),
    shoppingBudgetMinor: z.number().int().nonnegative().max(100000000).default(0),
  }).strict() }).strict(),
  base.extend({ serviceType: z.literal('big_move'), scheduledAt: schedule, serviceDetails: z.object({
    loadType: z.string().trim().min(2).max(120), items: z.string().trim().min(3).max(4000),
    vehicleSize: z.enum(['car', 'van', 'large_van']), helpers: z.number().int().min(0).max(10),
    pickupAccess: z.enum(['ground', 'stairs', 'lift']), destinationAccess: z.enum(['ground', 'stairs', 'lift']),
  }).strict() }).strict(),
]);
export type QuoteInput = z.infer<typeof quoteSchema>;
const money = z.number().int().nonnegative().max(100000000);
export const pricingRuleSchema = z.object({
  baseMinor: money, perKmMinor: money, perMinuteMinor: money, helperMinor: money, stairsMinor: money,
  minimumMinor: z.number().int().positive().max(100000000), platformFeeBps: z.number().int().min(0).max(9999),
  surgeBps: z.number().int().min(10000).max(50000), vehicleBps: z.object({ car: z.number().int().min(10000).max(50000),
    van: z.number().int().min(10000).max(50000), large_van: z.number().int().min(10000).max(50000) }).strict(),
  maxDistanceMeters: z.number().int().positive().max(1000000),
}).strict();
export type PricingRule = z.infer<typeof pricingRuleSchema>;
export const createOrderSchema = z.object({ quoteId: z.string().uuid() }).strict();
export const commandSchema = z.discriminatedUnion('command', [
  z.object({ command: z.enum(['request_payment', 'fund', 'accept', 'heading_to_pickup', 'arrived_pickup', 'picked_up',
    'heading_to_dropoff', 'arrived_dropoff', 'confirm_receipt', 'returning', 'returned']) }).strict(),
  z.object({ command: z.literal('offer') }).strict(),
  z.object({ command: z.literal('assign'), delivererId: z.string().uuid() }).strict(),
  z.object({ command: z.enum(['cancel', 'reject', 'report_issue']), reason: z.string().trim().min(3).max(2000) }).strict(),
  z.object({ command: z.literal('handover'), recipientName: z.string().trim().min(2).max(120),
    code: z.string().regex(/^\d{6}$/), evidenceUploadId: z.string().uuid().optional() }).strict(),
]);
export const availabilitySchema = z.object({ online: z.boolean(), transportType: z.enum(transportTypes),
  deliveryArea: pointSchema.extend({ radiusMeters: z.number().int().min(100).max(100000) }),
  capacity: z.object({ maxWeightKg: z.number().positive().max(10000), maxActiveJobs: z.number().int().min(1).max(10) }).strict(),
  servicePreferences: z.array(z.enum(serviceTypes)).min(1).max(4),
}).strict();
export const locationSchema = pointSchema.extend({ accuracyMeters: z.number().nonnegative().max(500),
  capturedAt: z.string().datetime({ offset: true }).refine((value) => {
    const age = Date.now() - Date.parse(value); return age >= -30000 && age <= 120000;
  }, 'Location timestamp must be recent.') });
export const applicationSchema = z.object({ identity: z.object({ fullName: z.string().trim().min(2).max(120),
  dateOfBirth: z.string().date() }).strict(), transportType: z.enum(transportTypes),
  safety: z.object({ lawfulTransport: z.literal(true), safeHandling: z.literal(true), termsAccepted: z.literal(true) }).strict(),
}).strict();
export const documentSchema = z.object({ documentType: z.enum(['identity', 'driver_licence', 'registration', 'insurance']),
  mimeType: z.enum(['image/jpeg', 'image/png', 'application/pdf']) }).strict();
export const reviewSchema = z.object({ status: z.enum(['under_review', 'approved', 'rejected', 'suspended']),
  notes: z.string().trim().min(3).max(4000) }).strict();
