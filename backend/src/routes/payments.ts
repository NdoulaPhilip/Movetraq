import { Router } from 'express';
import { initialize, verify } from '../controllers/payment-controller.js';
import { requireAuth } from '../middleware/auth.js';
import { authRateLimit } from '../middleware/rate-limit.js';

export const paymentsRouter = Router();
paymentsRouter.post('/payments/topups', requireAuth, authRateLimit, initialize);
paymentsRouter.post('/payments/:reference/verify', requireAuth, authRateLimit, verify);
