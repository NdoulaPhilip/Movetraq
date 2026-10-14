import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import { corsOrigins, env } from './config/env.js';
import { errorHandler } from './middleware/error-handler.js';
import { apiRateLimit } from './middleware/rate-limit.js';
import { requestId } from './middleware/request-id.js';
import { apiRouter } from './routes/index.js';
import { logger } from './utils/logger.js';
import { ApiError } from './utils/api-error.js';
import { paystackWebhook } from './controllers/payment-controller.js';
import { observeActivity } from './services/activity-service.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', env.TRUST_PROXY_HOPS ?? 0);

  app.use(requestId);
  app.use(observeActivity);
  app.use(helmet());
  app.use('/api', (_req, res, next) => {
    res.setHeader('Cache-Control', 'no-store');
    next();
  });
  app.use(cors({ origin: corsOrigins.includes('*') ? true : corsOrigins }));
  app.post('/api/v1/payments/webhooks/paystack', express.raw({ type: 'application/json', limit: '1mb' }), paystackWebhook);
  app.use(express.json({ limit: '1mb' }));
  app.use(pinoHttp({ logger, redact: ['req.headers.authorization', 'req.headers.cookie', 'res.headers.set-cookie'] }));
  app.use(apiRateLimit);
  app.use(apiRouter);
  app.use((_req, _res, next) => next(new ApiError(404, 'NOT_FOUND', 'Endpoint was not found.')));
  app.use(errorHandler);

  return app;
}
