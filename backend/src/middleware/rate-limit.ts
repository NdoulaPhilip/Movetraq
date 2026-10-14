import rateLimit from 'express-rate-limit';

export const apiRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
});

export const addressRateLimit = rateLimit({
  windowMs: 60 * 1000, limit: 30,
  standardHeaders: 'draft-7', legacyHeaders: false,
  message: { success: false, error: { code: 'ADDRESS_RATE_LIMIT', message: 'Too many address lookups. Please try again shortly.' } },
});

export const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { success: false, error: { code: 'AUTH_RATE_LIMIT', message: 'Too many attempts. Please try again later.' } },
});
