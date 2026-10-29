import { supabaseAdmin } from '../config/supabase.js';
import * as repository from '../repositories/account-repository.js';
import * as account from '../services/account-service.js';
import * as auth from '../services/auth-service.js';
import { ApiError } from '../utils/api-error.js';
import { asyncHandler } from '../utils/async-handler.js';
import { created, ok } from '../utils/responses.js';
import * as validators from '../validators/account.js';
import { verifyLegacyAdminToken } from '../services/legacy-admin-auth-service.js';

export const signup = asyncHandler(async (req, res) => { created(res, await auth.signUp(validators.signupSchema.parse(req.body))); });
export const signin = asyncHandler(async (req, res) => { ok(res, await auth.signIn(validators.signinSchema.parse(req.body))); });
export const refresh = asyncHandler(async (req, res) => { ok(res, await auth.refreshSession(validators.refreshSchema.parse(req.body).refreshToken)); });
export const recover = asyncHandler(async (req, res) => { ok(res, await auth.requestRecovery(validators.recoverySchema.parse(req.body).email)); });
export const verify = asyncHandler(async (req, res) => { ok(res, await auth.verifyOtp(validators.otpSchema.parse(req.body))); });
export const me = asyncHandler(async (req, res) => { ok(res, { user: await account.accountProfile(req.user!) }); });
export const updateProfile = asyncHandler(async (req, res) => { ok(res, { user: await account.updateAccountProfile(req.user!, validators.profileSchema.parse(req.body)) }); });
export const logout = asyncHandler(async (req, res) => {
  if (verifyLegacyAdminToken(req.accessToken ?? '')?.typ === 'access') {
    ok(res, { signedOut: true });
    return;
  }
  const { error } = await supabaseAdmin.auth.admin.signOut(req.accessToken!, 'local');
  if (error) throw new ApiError(503, 'LOGOUT_FAILED', 'Could not revoke this session.');
  ok(res, { signedOut: true });
});
export const updatePassword = asyncHandler(async (req, res) => {
  const { password } = validators.passwordSchema.parse(req.body);
  const { error } = await supabaseAdmin.auth.admin.updateUserById(req.user!.id, { password });
  if (error) throw new ApiError(400, 'PASSWORD_UPDATE_FAILED', 'Could not update your password.');
  ok(res, { updated: true });
});
export const addresses = asyncHandler(async (req, res) => { ok(res, { addresses: await repository.listAddresses(req.user!.id) }); });
export const saveAddress = asyncHandler(async (req, res) => {
  const id = req.params.id ? validators.idSchema.parse(req.params.id) : null;
  const address = await repository.saveAddress(req.user!.id, id, validators.addressSchema.parse(req.body));
  ok(res, { address }, id ? 200 : 201);
});
export const deleteAddress = asyncHandler(async (req, res) => {
  await repository.deleteAddress(req.user!.id, validators.idSchema.parse(req.params.id));
  ok(res, { deleted: true });
});
export const defaultAddress = asyncHandler(async (req, res) => {
  if (Object.keys(req.body ?? {}).length !== 0) {
    throw new ApiError(400, 'INVALID_REQUEST', 'Default address changes accept no profile or address fields.');
  }
  ok(res, { address: await repository.setDefaultAddress(req.user!.id,
    validators.idSchema.parse(req.params.id)) });
});
export const preferences = asyncHandler(async (req, res) => { ok(res, await repository.readPreferences('user_preferences', req.user!.id)); });
export const updatePreferences = asyncHandler(async (req, res) => { ok(res, await repository.writePreferences('user_preferences', req.user!.id, validators.preferencesSchema.parse(req.body))); });
export const notificationPreferences = asyncHandler(async (req, res) => { ok(res, await repository.readPreferences('notification_preferences', req.user!.id)); });
export const updateNotificationPreferences = asyncHandler(async (req, res) => { ok(res, await repository.writePreferences('notification_preferences', req.user!.id, validators.notificationPreferencesSchema.parse(req.body))); });
export const blocks = asyncHandler(async (req, res) => { ok(res, { blockedUsers: await repository.listBlocks(req.user!.id) }); });
export const block = asyncHandler(async (req, res) => {
  const input = validators.blockSchema.parse(req.body);
  if (input.blockedId === req.user!.id) throw new ApiError(400, 'CANNOT_BLOCK_SELF', 'You cannot block yourself.');
  await repository.blockUser(req.user!.id, input.blockedId, input.reason);
  ok(res, { blocked: true });
});
export const unblock = asyncHandler(async (req, res) => {
  await repository.unblockUser(req.user!.id, validators.idSchema.parse(req.params.id));
  ok(res, { unblocked: true });
});
export const notifications = asyncHandler(async (req, res) => {
  const { limit, offset } = validators.paginationSchema.parse(req.query);
  ok(res, { notifications: await repository.listNotifications(req.user!.id, limit, offset), limit, offset });
});
export const readNotification = asyncHandler(async (req, res) => { ok(res, { notification: await repository.readNotification(req.user!.id, validators.idSchema.parse(req.params.id)) }); });
export const unreadNotifications = asyncHandler(async (req, res) => {
  ok(res, { unreadCount: await repository.countUnreadNotifications(req.user!.id) });
});
export const readAllNotifications = asyncHandler(async (req, res) => {
  ok(res, { updatedCount: await repository.readAllNotifications(req.user!.id) });
});
export const deleteNotification = asyncHandler(async (req, res) => {
  await repository.deleteNotification(req.user!.id, validators.idSchema.parse(req.params.id));
  ok(res, { deleted: true });
});
export const clearNotifications = asyncHandler(async (req, res) => {
  ok(res, { deletedCount: await repository.clearNotifications(req.user!.id) });
});
export const wallet = asyncHandler(async (req, res) => {
  const result = await repository.loadAccount(req.user!.id);
  ok(res, { currency: result.wallet?.currency ?? 'NGN', balanceMinor: result.balanceMinor, status: result.wallet?.status ?? 'unavailable' });
});
export const ledger = asyncHandler(async (req, res) => {
  const { limit, offset } = validators.paginationSchema.parse(req.query);
  ok(res, { transactions: await repository.listLedger(req.user!.id, limit, offset), limit, offset });
});
