import type { AuthUser } from '../middleware/auth.js';
import { loadAccount, patchProfile } from '../repositories/account-repository.js';
import { ApiError } from '../utils/api-error.js';
import type { ProfilePatch } from '../validators/account.js';
import { assertApprovedDeliverer } from './deliverer-access.js';

export async function accountProfile(user: AuthUser) {
  const account = await loadAccount(user.id);
  const profile = account.profile;
  const canDeliver=account.deliverer?.verification_status==='approved'&&account.roles.some(row=>row.role==='deliverer');
  return {
    uid: profile.id, name: profile.full_name, email: user.email ?? '', phone: profile.phone ?? '',
    activeRole: profile.active_role==='deliverer'&&!canDeliver?'sender':profile.active_role, memberTier: profile.membership_tier,
    canDeliver,
    verified: profile.verification_status === 'approved', createdAt: profile.created_at,
    verificationStatus: profile.verification_status,
    delivererVerificationStatus: account.deliverer?.verification_status ?? 'not_started',
    delivererOnline: account.deliverer?.availability_status === 'online',
    vehicleType: account.deliverer?.transport_type ?? null,
    roles: account.roles.map((row) => row.role),
    wallet: { currency: account.wallet?.currency ?? 'NGN', balanceMinor: account.balanceMinor },
  };
}
export async function updateAccountProfile(user: AuthUser, input: ProfilePatch) {
  if (input.activeRole && !user.roles.includes(input.activeRole)) {
    throw new ApiError(403, 'ROLE_NOT_GRANTED', 'Complete deliverer verification before switching roles.');
  }
  if(input.activeRole==='deliverer')await assertApprovedDeliverer(user);
  const patch: Record<string, unknown> = {};
  if (input.name !== undefined) patch.full_name = input.name;
  if (input.phone !== undefined) patch.phone = input.phone;
  if (input.activeRole !== undefined) patch.active_role = input.activeRole;
  await patchProfile(user.id, patch);
  return accountProfile(user);
}
