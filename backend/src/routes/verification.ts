import { Router } from 'express';
import { requireAuth, requireAdminRole } from '../middleware/auth.js';
import * as controller from '../controllers/verification-controller.js';

export const verificationRouter = Router();
verificationRouter.post('/deliverers/me/applications', requireAuth, controller.start);
verificationRouter.get('/deliverers/me/applications/:id', requireAuth, controller.application);
verificationRouter.post('/deliverers/me/applications/:id/documents', requireAuth, controller.upload);
verificationRouter.post('/deliverers/me/applications/:id/submit', requireAuth, controller.submit);
verificationRouter.post('/verification-documents/:id/confirm', requireAuth, controller.confirm);
verificationRouter.get('/verification-documents/:id/download', requireAuth, controller.download);
verificationRouter.get('/admin/verification-applications', requireAuth, requireAdminRole('verification_agent', 'admin', 'super_admin'), controller.queue);
verificationRouter.post('/admin/verification-applications/:id/review', requireAuth, requireAdminRole('verification_agent', 'admin', 'super_admin'), controller.review);
