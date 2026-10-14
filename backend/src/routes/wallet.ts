import { Router } from 'express';
import { requireAuth } from '../middleware/auth.js';
import { ledger, wallet } from '../controllers/account-controller.js';

export const walletRouter = Router();

walletRouter.get('/wallet', requireAuth, wallet);
walletRouter.get('/wallet/transactions', requireAuth, ledger);
