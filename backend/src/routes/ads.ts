import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import * as controller from '../controllers/ads-controller.js';

export const adsRouter = Router();
adsRouter.get('/deliverers/me/ads', requireAuth, controller.own);
adsRouter.get('/ads', requireAuth, controller.browse);
adsRouter.post('/ads', requireAuth, controller.create);
adsRouter.get('/ads/:id', requireAuth, controller.detail);
adsRouter.patch('/ads/:id', requireAuth, controller.update);
adsRouter.delete('/ads/:id', requireAuth, controller.remove);
