import { createHash } from 'node:crypto';
import type { AuthUser } from '../middleware/auth.js';
import { initializePaystack, paymentSecret, verifyPaystack } from '../integrations/paystack.js';
import * as repository from '../repositories/payment-repository.js';
import { ApiError } from '../utils/api-error.js';

export async function initializeTopup(user: AuthUser, amountMinor: number, key: string) {
  paymentSecret();
  if (!user.email) throw new ApiError(400, 'EMAIL_REQUIRED', 'Add an email before making a payment.');
  const reference = `mt-${createHash('sha256').update(`${user.id}:${key}`).digest('hex')}`;
  const payment = await repository.reserveTopup(user.id, amountMinor, key, reference);
  if (payment.status === 'verified') return { reference, status: 'verified', checkoutUrl: null };
  if (payment.checkout_url) return { reference, status: payment.status, checkoutUrl: payment.checkout_url };
  const checkout = await initializePaystack(user.email, amountMinor, reference);
  await repository.saveCheckout(reference, checkout.authorization_url);
  return { reference, status: 'initialized', checkoutUrl: checkout.authorization_url };
}

export async function reconcilePayment(reference: string, userId?: string) {
  const payment = await repository.findPayment(reference, userId);
  if (!payment) {
    if (userId) throw new ApiError(404, 'PAYMENT_NOT_FOUND', 'Payment was not found.');
    return { ignored: true };
  }
  if (payment.status === 'verified') return { reference, status: 'verified' };
  if (payment.provider !== 'paystack') throw new ApiError(409, 'PROVIDER_MISMATCH', 'Payment provider does not match.');
  const verified = await verifyPaystack(reference);
  if (verified.amount !== payment.amount_minor || verified.currency !== payment.currency) {
    throw new ApiError(409, 'PAYMENT_AMOUNT_MISMATCH', 'Payment verification does not match the requested amount and currency.');
  }
  if (verified.status !== 'success') return { reference, status: verified.status };
  await repository.creditVerifiedTopup(reference, verified.amount, verified.currency);
  return { reference, status: 'verified' };
}
