import pino from 'pino';
import { env } from '../config/env.js';

export const logger = pino({
  level: env.LOG_LEVEL,
  redact: [
    'req.headers.authorization',
    'SUPABASE_SERVICE_ROLE_KEY',
    'PAYMENT_SECRET_KEY',
    'PAYMENT_WEBHOOK_SECRET',
  ],
});
