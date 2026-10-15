import { z } from 'zod';
import { asyncHandler } from '../utils/async-handler.js';
import { ok } from '../utils/responses.js';
import { mobileMonitoring } from '../services/mobile-monitoring-service.js';
const filters=z.object({view:z.enum(['activity','attempts','payments','ledger','orders','users','messages','notifications','support_tickets','wallet_transactions','saved_addresses','security_settings']).optional(),
  page:z.coerce.number().int().min(0).max(100000).optional(),q:z.string().trim().max(128).optional()}).strict();
export const mobileActivity=asyncHandler(async(req,res)=>{ok(res,await mobileMonitoring(req.user!.id,filters.parse(req.query)));});
