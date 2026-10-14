import { z } from 'zod';
import { paymentSecret, verifyPaystackSignature } from '../integrations/paystack.js';
import { initializeTopup, reconcilePayment } from '../services/payment-service.js';
import { ApiError } from '../utils/api-error.js';
import { asyncHandler } from '../utils/async-handler.js';
import { ok } from '../utils/responses.js';

const topupSchema = z.object({ amountMinor: z.number().int().min(10000).max(100000000) }).strict();
const keySchema = z.string().min(16).max(128).regex(/^[A-Za-z0-9-]+$/);
const referenceSchema = z.string().regex(/^mt-[a-f0-9]{64}$/);
const webhookSchema = z.object({ event: z.string(), data: z.object({ reference: z.string() }).passthrough() });

export const initialize = asyncHandler(async (req, res) => {
  const { amountMinor } = topupSchema.parse(req.body);
  const key = keySchema.parse(req.header('idempotency-key'));
  ok(res, await initializeTopup(req.user!, amountMinor, key));
});
export const verify = asyncHandler(async (req, res) => {
  ok(res, await reconcilePayment(referenceSchema.parse(req.params.reference), req.user!.id));
});
export const paystackWebhook = asyncHandler(async (req, res) => {
  const body = req.body;
  if (!Buffer.isBuffer(body) || !verifyPaystackSignature(body, req.header('x-paystack-signature'), paymentSecret())) {
    throw new ApiError(401, 'INVALID_WEBHOOK_SIGNATURE', 'Webhook signature is invalid.');
  }
  let event: unknown;
  try { event = JSON.parse(body.toString('utf8')); }
  catch { throw new ApiError(400, 'INVALID_JSON', 'Webhook body must be valid JSON.'); }
  const eventName = z.object({ event: z.string() }).parse(event).event;
  if (eventName === 'charge.success') {
    const payload = webhookSchema.parse(event);
    const result = await reconcilePayment(payload.data.reference);
    if ('status' in result && result.status !== 'verified') {
      throw new ApiError(503, 'PAYMENT_NOT_SETTLED', 'Provider has not confirmed this payment yet.');
    }
  }
  ok(res, { received: true });
});
