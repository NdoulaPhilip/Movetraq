import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { addressRateLimit } from '../middleware/rate-limit.js';
import * as controller from '../controllers/address-search-controller.js';

export const addressSearchRouter = Router();
addressSearchRouter.get('/addresses/search', requireAuth, addressRateLimit, controller.search);
addressSearchRouter.post('/addresses/reverse', requireAuth, addressRateLimit, controller.reverse);
