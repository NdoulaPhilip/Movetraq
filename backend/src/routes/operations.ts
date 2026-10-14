import { Router } from 'express';
import { requireAuth, requireAdminRole } from '../middleware/auth.js';
import * as controller from '../controllers/operations-controller.js';

export const operationsRouter = Router();
operationsRouter.get('/admin/pricing-rules', requireAuth, requireAdminRole('finance', 'admin', 'super_admin'), controller.pricing);
operationsRouter.post('/admin/pricing-rules', requireAuth, requireAdminRole('finance', 'admin', 'super_admin'), controller.activatePricing);
operationsRouter.get('/quotes/:id/candidates', requireAuth, controller.candidates);
operationsRouter.get('/deliverers/me/summary', requireAuth, controller.summary);
operationsRouter.get('/deliverers/me/past-customers', requireAuth, controller.customers);
operationsRouter.get('/orders/:id/receipt', requireAuth, controller.receipt);
