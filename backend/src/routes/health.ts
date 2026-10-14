import { Router } from 'express';
import { ok } from '../utils/responses.js';

export const healthRouter = Router();

healthRouter.get('/health', (_req, res) => {
  ok(res, {
    service: 'movetraq-backend',
    status: 'healthy',
    time: new Date().toISOString(),
  });
});
