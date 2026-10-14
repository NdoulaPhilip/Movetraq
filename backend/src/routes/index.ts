import { Router } from 'express';
import { healthRouter } from './health.js';
import { ordersRouter } from './orders.js';
import { walletRouter } from './wallet.js';
import { accountsRouter } from './accounts.js';
import { paymentsRouter } from './payments.js';
import { verificationRouter } from './verification.js';
import { operationsRouter } from './operations.js';
import { supportRouter } from './support.js';
import { adminUsersRouter } from './admin-users.js';
import { adsRouter } from './ads.js';
import { addressSearchRouter } from './address-search.js';

export const apiRouter = Router();

apiRouter.use(healthRouter);
apiRouter.use('/api/v1', accountsRouter);
apiRouter.use('/api/v1', paymentsRouter);
apiRouter.use('/api/v1', verificationRouter);
apiRouter.use('/api/v1', operationsRouter);
apiRouter.use('/api/v1', ordersRouter);
apiRouter.use('/api/v1', walletRouter);
apiRouter.use('/api/v1', supportRouter);
apiRouter.use('/api/v1', adminUsersRouter);
apiRouter.use('/api/v1', adsRouter);
apiRouter.use('/api/v1', addressSearchRouter);
