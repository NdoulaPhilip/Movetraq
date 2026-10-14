import { z } from 'zod';

export const idSchema = z.string().uuid();
const phone = z.string().trim().regex(/^\+[1-9]\d{7,14}$/, 'Use an international phone number.');
const email = z.string().trim().email().max(254);
const password = z.string().min(12).max(128);
const settings = z.record(z.union([z.string().max(200), z.boolean(), z.number().finite(), z.null()]));

export const signupSchema = z.object({
  name: z.string().trim().min(2).max(120), email, phone: phone.optional(), password,
}).strict();
export const signinSchema = z.object({
  emailOrPhone: z.union([email, phone]), password: z.string().min(1).max(128),
}).strict();
export const refreshSchema = z.object({ refreshToken: z.string().min(1).max(4096) }).strict();
export const recoverySchema = z.object({ email }).strict();
export const passwordSchema = z.object({ password }).strict();
export const otpSchema = z.object({
  email, token: z.string().regex(/^\d{6,10}$/), type: z.enum(['signup', 'recovery']),
}).strict();
export const profileSchema = z.object({
  name: z.string().trim().min(2).max(120).optional(),
  phone: phone.nullable().optional(),
  activeRole: z.enum(['sender', 'deliverer']).optional(),
}).strict().refine((value) => Object.keys(value).length > 0, 'Provide a profile field.');
export const addressSchema = z.object({
  label: z.string().trim().min(1).max(80), address: z.string().trim().min(3).max(500),
  latitude: z.number().finite().min(-90).max(90), longitude: z.number().finite().min(-180).max(180),
  placeId: z.string().max(200).nullable().optional(),
  city: z.string().max(120).nullable().optional(), state: z.string().max(120).nullable().optional(),
  country: z.string().regex(/^[A-Z]{2}$/).default('NG'), isDefault: z.boolean().default(false),
}).strict();
export const preferencesSchema = z.object({
  delivery_preferences: settings.optional(), accessibility_preferences: settings.optional(),
  display_preferences: settings.optional(), privacy_preferences: settings.optional(),
}).strict().refine((value) => Object.keys(value).length > 0, 'Provide a preference.');
export const notificationPreferencesSchema = z.object({
  push_enabled: z.boolean().optional(), email_enabled: z.boolean().optional(),
  sms_enabled: z.boolean().optional(), event_settings: z.record(z.boolean()).optional(),
}).strict().refine((value) => Object.keys(value).length > 0, 'Provide a preference.');
export const blockSchema = z.object({ blockedId: idSchema, reason: z.string().trim().max(500).optional() }).strict();
export const paginationSchema = z.object({
  limit: z.coerce.number().int().min(1).max(100).default(30),
  offset: z.coerce.number().int().min(0).max(100000).default(0),
}).strict();

export type ProfilePatch = z.infer<typeof profileSchema>;
export type AddressInput = z.infer<typeof addressSchema>;
