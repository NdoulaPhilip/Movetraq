import type { Session, User } from '@supabase/supabase-js';
import { createAuthClient } from '../config/supabase.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';
import { accountProfile } from './account-service.js';
import type { signupSchema, signinSchema, otpSchema } from '../validators/account.js';
import type { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from '../repositories/account-repository.js';

async function authenticatedResult(session: Session, user: User) {
  const profile = await accountProfile({ id: user.id, email: user.email, roles: [] });
  return { user: profile, session: {
    accessToken: session.access_token, refreshToken: session.refresh_token,
    expiresAt: session.expires_at, tokenType: session.token_type,
  } };
}
export async function signUp(input: z.infer<typeof signupSchema>) {
  const { data, error } = await createAuthClient().auth.signUp({
    email: input.email, password: input.password,
    options: { emailRedirectTo: env.AUTH_REDIRECT_URL, data: { full_name: input.name, phone: input.phone ?? null } },
  });
  if (error) throw new ApiError(error.status && error.status >= 500 ? 503 : 400, 'SIGNUP_FAILED', 'Could not create an account with these details.');
  // With confirmation enabled, do not disclose whether an email already exists.
  if (!data.session || !data.user) return { requiresEmailConfirmation: true };
  return { requiresEmailConfirmation: false, ...await authenticatedResult(data.session, data.user) };
}
export async function signIn(input: z.infer<typeof signinSchema>) {
  const credentials = input.emailOrPhone.includes('@')
    ? { email: input.emailOrPhone, password: input.password }
    : { phone: input.emailOrPhone, password: input.password };
  const { data, error } = await createAuthClient().auth.signInWithPassword(credentials);
  if (error || !data.session || !data.user) {
    throw new ApiError(error?.status && error.status >= 500 ? 503 : 401, 'SIGNIN_FAILED', 'Could not sign in. Check your credentials and confirm your account.');
  }
  const result = await authenticatedResult(data.session, data.user);
  const { error: activityError } = await supabaseAdmin.rpc('record_account_login', { p_user_id: data.user.id });
  databaseError(activityError);
  return result;
}
export async function refreshSession(refreshToken: string) {
  const { data, error } = await createAuthClient().auth.refreshSession({ refresh_token: refreshToken });
  if (error || !data.session || !data.user) {
    throw new ApiError(error?.status && error.status >= 500 ? 503 : 401, 'INVALID_SESSION', 'Please sign in again.');
  }
  return authenticatedResult(data.session, data.user);
}
export async function requestRecovery(email: string) {
  const { error } = await createAuthClient().auth.resetPasswordForEmail(email, { redirectTo: env.AUTH_REDIRECT_URL });
  if (error && (error.status ?? 500) >= 500) throw new ApiError(503, 'AUTH_UNAVAILABLE', 'Password recovery is temporarily unavailable.');
  return { message: 'If an account exists, recovery instructions will be sent.' };
}
export async function verifyOtp(input: z.infer<typeof otpSchema>) {
  const { data, error } = await createAuthClient().auth.verifyOtp(input);
  if (error || !data.session || !data.user) throw new ApiError(400, 'INVALID_OTP', 'The code is invalid or expired.');
  return authenticatedResult(data.session, data.user);
}
