import { ApiError } from '../utils/api-error.js';

export type LedgerEntryType =
  | 'wallet_credit'
  | 'wallet_debit'
  | 'topup'
  | 'refund'
  | 'delivery_payment'
  | 'escrow_hold'
  | 'escrow_release'
  | 'withdrawal'
  | 'adjustment';

export interface LedgerEntry {
  id: string;
  walletId: string;
  type: LedgerEntryType;
  amountMinor: number;
  currency: string;
  idempotencyKey: string;
  createdAt: string;
}

export function assertMoney(amountMinor: number) {
  if (!Number.isSafeInteger(amountMinor) || amountMinor === 0) {
    throw new ApiError(400, 'INVALID_MONEY_AMOUNT', 'Amount must be a non-zero integer minor-unit value.');
  }
}

export function deriveBalance(entries: Pick<LedgerEntry, 'amountMinor'>[]) {
  return entries.reduce((sum, entry) => {
    assertMoney(entry.amountMinor);
    const balance = sum + entry.amountMinor;
    if (!Number.isSafeInteger(balance)) throw new ApiError(400, 'INVALID_MONEY_AMOUNT', 'Balance exceeds safe integer precision.');
    return balance;
  }, 0);
}

export function appendLedgerEntry(entries: LedgerEntry[], next: LedgerEntry) {
  assertMoney(next.amountMinor);
  if (entries.some((entry) => entry.walletId !== next.walletId || entry.currency !== next.currency)) {
    throw new ApiError(409, 'LEDGER_ACCOUNT_MISMATCH', 'Ledger entries must belong to the same wallet and currency.');
  }
  const duplicate = entries.find((entry) => entry.idempotencyKey === next.idempotencyKey);
  if (duplicate) {
    if (duplicate.amountMinor !== next.amountMinor || duplicate.type !== next.type) {
      throw new ApiError(409, 'IDEMPOTENCY_CONFLICT', 'This key was used for a different ledger entry.');
    }
    return { entries, entry: duplicate, duplicate: true };
  }

  const projected = deriveBalance(entries) + next.amountMinor;
  if (!Number.isSafeInteger(projected)) throw new ApiError(400, 'INVALID_MONEY_AMOUNT', 'Balance exceeds safe integer precision.');
  if (projected < 0) {
    throw new ApiError(409, 'INSUFFICIENT_FUNDS', 'Wallet has insufficient available balance.');
  }

  return {
    entries: [...entries, next],
    entry: next,
    duplicate: false,
  };
}
