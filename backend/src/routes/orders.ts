import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import * as controller from '../controllers/delivery-controller.js';

export const ordersRouter = Router();

ordersRouter.post('/quotes', requireAuth, controller.quote);
ordersRouter.get('/orders', requireAuth, controller.orders);
ordersRouter.post('/orders', requireAuth, controller.createOrder);
ordersRouter.get('/orders/:id', requireAuth, controller.detail);
ordersRouter.post('/orders/:id/commands', requireAuth, controller.command);
ordersRouter.get('/orders/:id/handover-code', requireAuth, controller.handoverCode);
ordersRouter.post('/orders/:id/location', requireAuth, controller.location);
ordersRouter.get('/orders/:id/location', requireAuth, controller.tracking);
ordersRouter.get('/orders/:id/messages', requireAuth, controller.chatHistory);
ordersRouter.post('/orders/:id/messages', requireAuth, controller.sendMessage);
ordersRouter.post('/orders/:id/messages/read', requireAuth, controller.readMessages);
ordersRouter.get('/messages/unread-count', requireAuth, controller.unreadMessages);
ordersRouter.post('/users/me/addresses/:id/select', requireAuth, controller.selectAddress);
ordersRouter.get('/deliverers/me/jobs', requireAuth, controller.jobs);
ordersRouter.put('/deliverers/me/availability', requireAuth, controller.availability);
