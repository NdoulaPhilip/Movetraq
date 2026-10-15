const { createHash, createHmac, timingSafeEqual } = require('node:crypto');

class PaymentError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
function minorUnits(value) {
  const amount = Number(value);
  const minor = Math.round(amount * 100);
  if (!Number.isFinite(amount) || !Number.isSafeInteger(minor) || Math.abs(amount * 100 - minor) > 0.000001) {
    throw new PaymentError(400, 'Money must use valid integer minor units.');
  }
  return minor;
}
function validReference(value) { return typeof value === 'string' && /^mt-[a-f0-9]{64}$/.test(value); }
function validSignature(raw, signature, secret) {
  return !!secret && typeof signature === 'string' && /^[a-f0-9]{128}$/i.test(signature)
    && timingSafeEqual(createHmac('sha512', secret).update(raw).digest(), Buffer.from(signature, 'hex'));
}
async function transaction(pool, action) {
  const db = await pool.connect();
  try { await db.query('begin'); const result = await action(db); await db.query('commit'); return result; }
  catch (error) { await db.query('rollback'); throw error; }
  finally { db.release(); }
}
class WalletPayments {
  constructor({ pool, secret, origin, request = fetch }) {
    this.pool = pool; this.secret = secret; this.origin = origin; this.request = request;
  }
  ready() {
    if (!this.pool || !this.secret) throw new PaymentError(503, 'Verified wallet payments are not configured.');
    if (!this.secret.startsWith('sk_test_')) throw new PaymentError(503, 'Only Paystack test payments are enabled in this build.');
    const url = new URL(this.origin || 'http://unconfigured.invalid');
    if (url.protocol !== 'https:' || url.username || url.password) throw new PaymentError(503, 'Secure payment callbacks are not configured.');
    return url.origin;
  }
  async provider(path, body) {
    this.ready();
    try {
      const response = await this.request(`https://api.paystack.co${path}`, { method: body ? 'POST' : 'GET',
        headers: { Authorization: `Bearer ${this.secret}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined, redirect: 'error', signal: AbortSignal.timeout(15000) });
      if (!response.ok) throw new Error();
      const result = await response.json();
      if (result.status !== true || !result.data) throw new Error();
      return result.data;
    } catch { throw new PaymentError(503, 'Paystack is temporarily unavailable. Please retry.'); }
  }
  async initialize(user, amountMinor, key) {
    const origin = this.ready();
    if (!Number.isSafeInteger(amountMinor) || amountMinor < 10000 || amountMinor > 100000000) {
      throw new PaymentError(400, 'Enter an amount between NGN 100 and NGN 1,000,000.');
    }
    if (typeof key !== 'string' || !/^[A-Za-z0-9-]{16,128}$/.test(key)) throw new PaymentError(400, 'A valid payment request key is required.');
    if (!user.email) throw new PaymentError(400, 'An account email is required for payment.');
    const reference = `mt-${createHash('sha256').update(`legacy-wallet\0${user.uid}\0${key}`).digest('hex')}`;
    const payment = await transaction(this.pool, async db => {
      await db.query('select uid from users where uid=$1 for update', [user.uid]);
      await db.query(`insert into legacy_wallet_topups(reference,user_id,request_key,amount_minor)
        values($1,$2,$3,$4) on conflict(user_id,request_key) do nothing`, [reference, user.uid, key, amountMinor]);
      const row = (await db.query('select * from legacy_wallet_topups where user_id=$1 and request_key=$2 for update', [user.uid, key])).rows[0];
      if (!row || row.amount_minor !== amountMinor) throw new PaymentError(409, 'Payment request key was used for a different amount.');
      return row;
    });
    const callbacks = { callbackUrl: `${origin}/payments/paystack/return`, cancelUrl: `${origin}/payments/paystack/cancel` };
    if (payment.status === 'verified') return { reference, status: 'verified', checkoutUrl: null, ...callbacks };
    if (payment.checkout_url) return { reference, checkoutUrl: payment.checkout_url, testMode: this.secret.startsWith('sk_test_'), ...callbacks };
    let initialized;
    try {
      initialized = await this.provider('/transaction/initialize', { email: user.email, amount: amountMinor, currency: 'NGN',
        reference, callback_url: callbacks.callbackUrl, metadata: { cancel_action: callbacks.cancelUrl } });
    } catch (error) {
      await this.pool.query("update legacy_wallet_topups set last_error_code='INITIALIZATION_UNAVAILABLE',last_checked_at=now() where reference=$1 and status<>'verified'",[reference]);
      throw error;
    }
    let checkout;
    try { checkout = new URL(initialized.authorization_url); } catch { throw new PaymentError(503, 'Invalid Paystack checkout response.'); }
    if (initialized.reference !== reference || checkout.origin !== 'https://checkout.paystack.com' || checkout.username || checkout.password || checkout.hash || checkout.pathname.length < 2) {
      throw new PaymentError(503, 'Invalid Paystack checkout response.');
    }
    await this.pool.query(`update legacy_wallet_topups set checkout_url=$2,status='initialized' where reference=$1 and status='created'`, [reference, checkout.href]);
    return { reference, checkoutUrl: checkout.href, testMode: this.secret.startsWith('sk_test_'), ...callbacks };
  }
  async verify(reference, owner) {
    this.ready();
    if (!validReference(reference)) throw new PaymentError(400, 'Invalid payment reference.');
    const payment = (await this.pool.query('select * from legacy_wallet_topups where reference=$1', [reference])).rows[0];
    if (!payment || (owner !== undefined && payment.user_id !== owner)) throw new PaymentError(404, 'Payment was not found.');
    if (payment.status === 'verified') return { reference, status: 'verified', userId: payment.user_id };
    let verified;
    try { verified = await this.provider(`/transaction/verify/${encodeURIComponent(reference)}`); }
    catch (error) {
      await this.pool.query("update legacy_wallet_topups set last_error_code='VERIFICATION_UNAVAILABLE',last_checked_at=now() where reference=$1 and status<>'verified'",[reference]);
      throw error;
    }
    if (verified.reference !== reference || !Number.isSafeInteger(verified.amount)
      || verified.amount !== payment.amount_minor || verified.currency !== 'NGN') {
      await this.pool.query("update legacy_wallet_topups set last_error_code='PROVIDER_MISMATCH',last_checked_at=now() where reference=$1 and status<>'verified'",[reference]);
      throw new PaymentError(409, 'Paystack payment amount, currency or reference does not match.');
    }
    if (verified.status !== 'success') {
      const status = ['failed','abandoned','reversed','pending','ongoing','processing','queued'].includes(verified.status) ? verified.status : 'unknown';
      await this.pool.query("update legacy_wallet_topups set provider_status=$2,last_checked_at=now(),last_error_code=null where reference=$1 and status<>'verified'",[reference,status]);
      return { reference, status: 'pending', providerStatus: status };
    }
    return transaction(this.pool, async db => {
      const user = (await db.query('select data from users where uid=$1 for update', [payment.user_id])).rows[0]?.data;
      const current = (await db.query('select * from legacy_wallet_topups where reference=$1 for update', [reference])).rows[0];
      if (!user || !current) throw new PaymentError(404, 'Payment account was not found.');
      if (current.status !== 'verified') {
        const balanceMinor = minorUnits(user.walletBalance || 0) + payment.amount_minor;
        if (!Number.isSafeInteger(balanceMinor)) throw new PaymentError(409, 'Wallet requires reconciliation.');
        const createdAt = new Date().toISOString();
        const item = { id: `paystack:${reference}`, type: 'topup', title: 'Paystack wallet top-up', sub: reference,
          amount: payment.amount_minor / 100, createdAt };
        await db.query(`insert into legacy_wallet_ledger(id,user_id,kind,amount_minor,balance_after_minor,provider_reference)
          values($1,$2,'topup',$3,$4,$5)`, [item.id, payment.user_id, payment.amount_minor, balanceMinor, reference]);
        user.walletBalance = balanceMinor / 100;
        user.walletRevision = Number(user.walletRevision || 0) + 1;
        await db.query('update users set data=$2::jsonb,updated_at=now() where uid=$1', [payment.user_id, JSON.stringify(user)]);
        await db.query(`insert into wallet_transactions(user_id,data) values($1,jsonb_build_array($2::jsonb))
          on conflict(user_id) do update set data=wallet_transactions.data||excluded.data,updated_at=now()`, [payment.user_id, JSON.stringify(item)]);
        await db.query(`update legacy_wallet_topups set status='verified',provider_status='success',last_checked_at=now(),last_error_code=null,verified_at=now() where reference=$1`, [reference]);
      }
      return { reference, status: 'verified', userId: payment.user_id };
    });
  }
}
module.exports = { WalletPayments, PaymentError, minorUnits, validSignature, validReference };
