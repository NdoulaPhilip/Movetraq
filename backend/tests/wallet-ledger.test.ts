import { describe, expect, it } from 'vitest';
import { appendLedgerEntry, deriveBalance, type LedgerEntry } from '../src/services/wallet-ledger.js';

const entry = (amountMinor: number, key: string): LedgerEntry => ({
  id: key,
  walletId: 'wallet_1',
  type: amountMinor > 0 ? 'topup' : 'escrow_hold',
  amountMinor,
  currency: 'NGN',
  idempotencyKey: key,
  createdAt: new Date().toISOString(),
});

describe('wallet ledger', () => {
  it('derives balance from immutable entries', () => {
    expect(deriveBalance([entry(500000, 'a'), entry(-150000, 'b')])).toBe(350000);
  });

  it('returns the original entry for duplicate idempotency keys', () => {
    const existing = [entry(500000, 'topup_1')];
    const result = appendLedgerEntry(existing, entry(500000, 'topup_1'));
    expect(result.duplicate).toBe(true);
    expect(result.entries).toHaveLength(1);
  });

  it('does not allow a negative projected balance', () => {
    expect(() => appendLedgerEntry([], entry(-1000, 'hold_1'))).toThrow('insufficient');
  });

  it('rejects reuse of a financial request key for a different amount', () => {
    expect(() => appendLedgerEntry([entry(1000, 'same-key')], entry(2000, 'same-key'))).toThrow('different ledger entry');
  });

  it('does not combine balances across wallets or currencies', () => {
    expect(() => appendLedgerEntry([entry(1000, 'one')], { ...entry(1000, 'two'), walletId: 'other-wallet' })).toThrow('same wallet');
    expect(() => appendLedgerEntry([entry(1000, 'one')], { ...entry(1000, 'two'), currency: 'USD' })).toThrow('same wallet');
  });

  it('rejects amounts and sums that lose integer precision', () => {
    expect(() => appendLedgerEntry([], entry(Number.MAX_SAFE_INTEGER + 1, 'large'))).toThrow('minor-unit');
    expect(() => deriveBalance([entry(Number.MAX_SAFE_INTEGER, 'one'), entry(1, 'two')])).toThrow('precision');
  });
});
