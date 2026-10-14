import { createHmac, timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';

const checkoutSchema = z.object({ status: z.literal(true), data: z.object({
  authorization_url: z.string().url(), reference: z.string(), access_code: z.string(),
}) });
const transactionSchema = z.object({ status: z.literal(true), data: z.object({
  status: z.string(), reference: z.string(), amount: z.number().int().positive().safe(),
  currency: z.string().length(3),
}) });

export function verifyPaystackSignature(body: Buffer, signature: string | undefined, secret: string) {
  if (!signature || !/^[a-f0-9]{128}$/i.test(signature)) return false;
  const expected = createHmac('sha512', secret).update(body).digest();
  return timingSafeEqual(expected, Buffer.from(signature, 'hex'));
}

export function paymentSecret() {
  if (env.PAYMENT_PROVIDER !== 'paystack' || !env.PAYMENT_SECRET_KEY) {
    throw new ApiError(503, 'PAYMENTS_UNAVAILABLE', 'Payments are not configured.');
  }
  return env.PAYMENT_SECRET_KEY;
}

async function providerRequest(path: string, body?: Record<string, unknown>) {
  const secret = paymentSecret();
  try {
    const response = await fetch(`https://api.paystack.co${path}`, {
      method: body ? 'POST' : 'GET',
      headers: { Authorization: `Bearer ${secret}`, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined, signal: AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error('Provider request failed');
    return await response.json();
  } catch {
    throw new ApiError(503, 'PAYMENT_PROVIDER_UNAVAILABLE', 'Could not contact the payment provider. Please retry.');
  }
}

export async function initializePaystack(email: string, amountMinor: number, reference: string) {
  const result = checkoutSchema.safeParse(await providerRequest('/transaction/initialize', {
    email, amount: amountMinor, currency: 'NGN', reference,
    ...(env.PAYMENT_CALLBACK_URL ? { callback_url: env.PAYMENT_CALLBACK_URL } : {}),
  }));
  if (!result.success || result.data.data.reference !== reference) {
    throw new ApiError(503, 'INVALID_PROVIDER_RESPONSE', 'The payment provider returned an invalid checkout.');
  }
  return result.data.data;
}

export async function verifyPaystack(reference: string) {
  const result = transactionSchema.safeParse(await providerRequest(`/transaction/verify/${encodeURIComponent(reference)}`));
  if (!result.success || result.data.data.reference !== reference) {
    throw new ApiError(503, 'INVALID_PROVIDER_RESPONSE', 'The payment provider returned an invalid transaction.');
  }
  return result.data.data;
}
