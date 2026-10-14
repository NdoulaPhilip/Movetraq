import { createHmac } from 'node:crypto';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const mocks = vi.hoisted(() => ({
  reserveTopup: vi.fn(), findPayment: vi.fn(), saveCheckout: vi.fn(), creditVerifiedTopup: vi.fn(),
  initializePaystack: vi.fn(), verifyPaystack: vi.fn(),
}));
vi.mock('../src/config/env.js', () => ({ env: { PAYMENT_PROVIDER: 'paystack', PAYMENT_SECRET_KEY: 'test-secret' } }));
vi.mock('../src/repositories/payment-repository.js', () => ({
  reserveTopup: mocks.reserveTopup, findPayment: mocks.findPayment,
  saveCheckout: mocks.saveCheckout, creditVerifiedTopup: mocks.creditVerifiedTopup,
}));
vi.mock('../src/integrations/paystack.js', async (importOriginal) => ({
  ...await importOriginal<typeof import('../src/integrations/paystack.js')>(),
  initializePaystack: mocks.initializePaystack, verifyPaystack: mocks.verifyPaystack,
}));
import { verifyPaystackSignature } from '../src/integrations/paystack.js';
import { initializeTopup, reconcilePayment } from '../src/services/payment-service.js';

const user = { id: 'user-one', email: 'sender@example.test', roles: ['sender'] };
const payment = { provider: 'paystack', status: 'initialized', amount_minor: 10000, currency: 'NGN' };
beforeEach(() => {
  vi.resetAllMocks();
  mocks.findPayment.mockResolvedValue(payment);
  mocks.verifyPaystack.mockResolvedValue({ reference: 'reference-one', status: 'success', amount: 10000, currency: 'NGN' });
});
describe('Paystack webhook signature', () => {
  it('accepts only the signature of the exact raw bytes', () => {
    const body = Buffer.from('{"event":"charge.success"}');
    const signature = createHmac('sha512', 'secret').update(body).digest('hex');
    expect(verifyPaystackSignature(body, signature, 'secret')).toBe(true);
    expect(verifyPaystackSignature(Buffer.from('{ "event":"charge.success"}'), signature, 'secret')).toBe(false);
    expect(verifyPaystackSignature(body, signature, 'other-secret')).toBe(false);
  });
  it('rejects missing, malformed and wrong-length signatures', () => {
    for (const signature of [undefined, '', 'deadbeef', 'z'.repeat(128)]) {
      expect(verifyPaystackSignature(Buffer.from('{}'), signature, 'secret')).toBe(false);
    }
  });
});
describe('wallet payment reconciliation', () => {
  it('credits only after provider verification matches the stored amount and currency', async () => {
    expect(await reconcilePayment('reference-one', user.id)).toEqual({ reference: 'reference-one', status: 'verified' });
    expect(mocks.findPayment).toHaveBeenCalledWith('reference-one', user.id);
    expect(mocks.creditVerifiedTopup).toHaveBeenCalledWith('reference-one', 10000, 'NGN');
  });
  it.each([{ amount: 20000, currency: 'NGN' }, { amount: 10000, currency: 'USD' }])('rejects mismatched provider money %j', async (money) => {
    mocks.verifyPaystack.mockResolvedValue({ ...money, status: 'success' });
    await expect(reconcilePayment('reference-one', user.id)).rejects.toMatchObject({ code: 'PAYMENT_AMOUNT_MISMATCH' });
    expect(mocks.creditVerifiedTopup).not.toHaveBeenCalled();
  });
  it('never credits pending or failed transactions', async () => {
    mocks.verifyPaystack.mockResolvedValue({ amount: 10000, currency: 'NGN', status: 'pending' });
    expect(await reconcilePayment('reference-one', user.id)).toEqual({ reference: 'reference-one', status: 'pending' });
    expect(mocks.creditVerifiedTopup).not.toHaveBeenCalled();
  });
  it('does not repost an already verified payment', async () => {
    mocks.findPayment.mockResolvedValue({ ...payment, status: 'verified' });
    await reconcilePayment('reference-one', user.id);
    expect(mocks.verifyPaystack).not.toHaveBeenCalled();
    expect(mocks.creditVerifiedTopup).not.toHaveBeenCalled();
  });
  it('hides another account payment and ignores unrelated signed merchant events', async () => {
    mocks.findPayment.mockResolvedValue(null);
    await expect(reconcilePayment('reference-one', user.id)).rejects.toMatchObject({ status: 404 });
    expect(await reconcilePayment('reference-one')).toEqual({ ignored: true });
    expect(mocks.creditVerifiedTopup).not.toHaveBeenCalled();
  });
  it('reuses an existing checkout for the same request instead of initializing again', async () => {
    mocks.reserveTopup.mockResolvedValue({ ...payment, checkout_url: 'https://checkout.paystack.com/checkout' });
    const result = await initializeTopup(user, 10000, 'idempotency-key-one');
    expect(result.checkoutUrl).toBe('https://checkout.paystack.com/checkout');
    expect(mocks.initializePaystack).not.toHaveBeenCalled();
  });
  it('initialization never credits a wallet', async () => {
    mocks.reserveTopup.mockResolvedValue({ status: 'created', checkout_url: null });
    mocks.initializePaystack.mockResolvedValue({ authorization_url: 'https://checkout.paystack.com/checkout' });
    await initializeTopup(user, 10000, 'idempotency-key-one');
    expect(mocks.saveCheckout).toHaveBeenCalled();
    expect(mocks.creditVerifiedTopup).not.toHaveBeenCalled();
  });
});
