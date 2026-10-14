import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';
import { ApiError } from '../utils/api-error.js';
import { logger } from '../utils/logger.js';

export const errorHandler: ErrorRequestHandler = (error, req, res, _next) => {
  if (error?.type === 'entity.parse.failed' || error?.type === 'entity.too.large') {
    const tooLarge = error.type === 'entity.too.large';
    res.status(tooLarge ? 413 : 400).json({ success: false, error: {
      code: tooLarge ? 'PAYLOAD_TOO_LARGE' : 'INVALID_JSON',
      message: tooLarge ? 'Request payload is too large.' : 'Request body must be valid JSON.',
    } });
    return;
  }
  if (error instanceof ZodError) {
    res.status(400).json({
      success: false,
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Request validation failed.',
        details: error.flatten(),
      },
    });
    return;
  }

  if (error instanceof ApiError) {
    res.status(error.status).json({
      success: false,
      error: {
        code: error.code,
        message: error.message,
        details: error.details,
      },
    });
    return;
  }

  logger.error({ error, requestId: req.requestId }, 'Unhandled request error');
  res.status(500).json({
    success: false,
    error: {
      code: 'INTERNAL_SERVER_ERROR',
      message: 'Something went wrong.',
    },
  });
};
