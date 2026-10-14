import { z } from 'zod';
export const managedRoles = ['sender','deliverer','support','verification_agent','finance','operations','admin','super_admin'] as const;
export const directoryQuery = z.object({
  q: z.string().trim().max(120).default(''), role: z.enum(managedRoles).optional(),
  status: z.enum(['active','suspended','deactivated']).optional(),
  from: z.string().datetime().optional(), to: z.string().datetime().optional(),
  staff: z.enum(['true','false']).optional(),
  page: z.coerce.number().int().min(0).max(10000).default(0),
}).strict();
export const userPatch = z.object({
  name: z.string().trim().min(2).max(120).optional(),
  phone: z.string().regex(/^\+[1-9][0-9]{7,14}$/).nullable().optional(),
  roles: z.array(z.enum(managedRoles)).min(1).max(8).refine(v => new Set(v).size === v.length).optional(),
  status: z.enum(['active','suspended']).optional(),
  reason: z.string().trim().min(5).max(500),
}).strict().refine(v => v.name !== undefined || v.phone !== undefined || v.roles !== undefined || v.status !== undefined, 'A change is required');
export const userCreate = z.object({
  email: z.string().email().max(254), name: z.string().trim().min(2).max(120),
  roles: z.array(z.enum(managedRoles)).min(1).max(8).refine(v => new Set(v).size === v.length),
  reason: z.string().trim().min(5).max(500),
}).strict();
export const activityQuery = z.object({
  type: z.string().regex(/^[a-z_]+$/).max(80).optional(),
  userId: z.string().uuid().optional(),
  page: z.coerce.number().int().min(0).max(10000).default(0),
  category:z.enum(['orders','finance','accounts','deliverers','communication','support','security','system']).optional(),
  outcome:z.enum(['successful','failed','pending','rejected']).optional(),
  orderId:z.string().uuid().optional(), reference:z.string().regex(/^[A-Za-z0-9_-]+$/).max(128).optional(),
  status:z.string().regex(/^[a-z_]+$/).max(80).optional(),
  from:z.string().datetime().optional(),to:z.string().datetime().optional(),
  q:z.string().trim().max(120).optional(),
}).strict();
