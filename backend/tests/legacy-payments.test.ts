import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { createHmac } from 'node:crypto';
import { PGlite } from '@electric-sql/pglite';
import { beforeEach, afterEach, describe, expect, it, vi } from 'vitest';

const { WalletPayments, minorUnits, validSignature } = createRequire(import.meta.url)('../../server/src/payments.js');
let database: PGlite;
let payments: any;
let request: ReturnType<typeof vi.fn>;
const user = { uid: 'legacy-sender', email: 'sender@example.test' };
const key = 'topup-request-test-001';
const result = (data: unknown) => new Response(JSON.stringify({ status: true, data }));

beforeEach(async () => {
  database = new PGlite();
  await database.exec(`create table users(uid text primary key,data jsonb not null,updated_at timestamptz default now());
    create table wallet_transactions(user_id text primary key,data jsonb not null,updated_at timestamptz default now());
    insert into users(uid,data) values('legacy-sender','{"uid":"legacy-sender","walletBalance":500}');`);
  await database.exec(readFileSync(new URL('../../server/migrations/0001_paystack_wallet.sql', import.meta.url), 'utf8'));
  let queue = Promise.resolve();
  const pool = {
    query: (sql: string, values?: unknown[]) => database.query(sql, values),
    connect: async () => {
      let release!: () => void;
      const previous = queue;
      queue = new Promise<void>(resolve => { release = resolve; });
      await previous;
      return { query: (sql: string, values?: unknown[]) => database.query(sql, values), release };
    },
  };
  request = vi.fn(async (_url: string, options: RequestInit) => {
    const body = JSON.parse(options.body as string);
    return result({ reference: body.reference, authorization_url: 'https://checkout.paystack.com/test-checkout' });
  });
  payments = new WalletPayments({ pool, secret: 'sk_test_fixture', origin: 'https://api.example.test', request });
}, 60000);
afterEach(async () => database?.close());

describe('Android wallet Paystack transactions', () => {
  it('initializes the existing user without crediting; retries reuse one checkout', async () => {
    const payment = await payments.initialize(user, 125050, key);
    expect(payment.reference).toMatch(/^mt-[a-f0-9]{64}$/);
    expect(payment.callbackUrl).toBe('https://api.example.test/payments/paystack/return');
    expect(payment.testMode).toBe(true);
    await payments.initialize(user, 125050, key);
    expect(request).toHaveBeenCalledTimes(1);
    expect((await database.query<{ data: unknown }>('select data from users')).rows[0].data).toMatchObject({ walletBalance: 500 });
    await expect(payments.initialize(user, 20000, key)).rejects.toMatchObject({ status: 409 });
    await expect(payments.initialize(user, 1.5, key)).rejects.toMatchObject({ status: 400 });
  });
  it('verifies amount/currency/reference and credits only once under concurrent retries', async () => {
    const payment = await payments.initialize(user, 125050, key);
    request.mockImplementation(async () => result({ reference: payment.reference, amount: 125050, currency: 'NGN', status: 'success' }));
    await Promise.all([payments.verify(payment.reference, user.uid), payments.verify(payment.reference), payments.verify(payment.reference, user.uid)]);
    expect((await database.query<{ data: unknown }>('select data from users')).rows[0].data).toMatchObject({ walletBalance: 1750.5, walletRevision: 1 });
    expect((await database.query("select * from legacy_wallet_ledger where kind='topup'")).rows).toHaveLength(1);
    expect((await database.query<{ data: unknown }>('select data from wallet_transactions')).rows[0].data).toHaveLength(1);
    expect((await database.query<{ total: string }>("select sum(amount_minor)::text as total from legacy_wallet_ledger")).rows[0].total).toBe('175050');
  });
  it('rejects foreign ownership before contacting Paystack', async () => {
    const payment = await payments.initialize(user, 10000, key);
    request.mockClear();
    await expect(payments.verify(payment.reference, 'other-user')).rejects.toMatchObject({ status: 404 });
    expect(request).not.toHaveBeenCalled();
  });
  it('does not credit failed or pending payments and rejects mismatched provider totals', async () => {
    const payment = await payments.initialize(user, 10000, key);
    for (const status of ['failed', 'abandoned', 'pending']) {
      request.mockImplementation(async () => result({ reference: payment.reference, amount: 10000, currency: 'NGN', status }));
      expect((await payments.verify(payment.reference, user.uid)).status).toBe('pending');
    }
    for (const mismatch of [{ amount: 10001 }, { currency: 'USD' }, { reference: 'wrong' }]) {
      request.mockImplementation(async () => result({ reference: payment.reference, amount: 10000, currency: 'NGN', status: 'success', ...mismatch }));
      await expect(payments.verify(payment.reference, user.uid)).rejects.toMatchObject({ status: 409 });
    }
    expect((await database.query("select * from legacy_wallet_ledger where kind='topup'")).rows).toHaveLength(0);
  });
  it('protects immutable ledger and payment identities and rejects stale wallet snapshots', async () => {
    const payment = await payments.initialize(user, 10000, key);
    request.mockImplementation(async () => result({ reference: payment.reference, amount: 10000, currency: 'NGN', status: 'success' }));
    await payments.verify(payment.reference, user.uid);
    await expect(database.exec("update users set data='{\"walletBalance\":500}'")).rejects.toThrow('Stale wallet');
    await expect(database.exec("update users set data=data||'{\"walletBalance\":9000}'")).rejects.toThrow('Stale wallet');
    await expect(database.exec('delete from legacy_wallet_ledger')).rejects.toThrow('immutable');
    await expect(database.exec('truncate legacy_wallet_ledger')).rejects.toThrow('immutable');
    await expect(database.exec('update legacy_wallet_topups set amount_minor=30000')).rejects.toThrow('immutable');
  });
  it('rejects insecure checkout URLs and fails without a persistent database or secure callback', async () => {
    request.mockImplementation(async (_url: string, options: RequestInit) => result({ reference: JSON.parse(options.body as string).reference, authorization_url: 'https://attacker.example/checkout' }));
    await expect(payments.initialize(user, 10000, key)).rejects.toMatchObject({ status: 503 });
    expect(() => new WalletPayments({ secret: 'sk_test_fixture', origin: 'https://api.example.test' }).ready()).toThrow('not configured');
    expect(() => new WalletPayments({ pool: {}, secret: 'sk_test_fixture', origin: 'http://api.example.test' }).ready()).toThrow('Secure payment');
    expect(() => new WalletPayments({ pool: {}, secret: 'sk_live_fixture', origin: 'https://api.example.test' }).ready()).toThrow('Only Paystack test');
  });
  it('checks raw webhook signatures and exact minor-unit conversion', () => {
    const raw = Buffer.from('{"event":"charge.success"}');
    const signature = createHmac('sha512', 'secret').update(raw).digest('hex');
    expect(validSignature(raw, signature, 'secret')).toBe(true);
    expect(validSignature(Buffer.from('{}'), signature, 'secret')).toBe(false);
    expect(validSignature(raw, 'invalid', 'secret')).toBe(false);
    expect(minorUnits(1234.56)).toBe(123456);
    expect(() => minorUnits(1.001)).toThrow();
  });
});
