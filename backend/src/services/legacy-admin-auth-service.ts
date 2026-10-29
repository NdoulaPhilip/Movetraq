import { createHmac, pbkdf2Sync, timingSafeEqual } from 'node:crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';

const staffRoles = new Set(['support', 'operations', 'verification_agent', 'finance', 'admin', 'super_admin']);
type LegacyUser = { uid: string; data: Record<string, unknown> };
type LegacyCredential = { user_id: string; password_hash: string };
type LegacyClaims = { sub: string; email: string; name: string; roles: string[]; typ: 'access' | 'refresh'; iat: number; exp: number; aud: 'movetraq-admin' };

function token(claims: LegacyClaims) {
  const secret = env.LEGACY_JWT_SECRET;
  if (!secret) throw new ApiError(503, 'LEGACY_AUTH_UNAVAILABLE', 'Legacy admin sign-in is not configured.');
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify(claims)).toString('base64url');
  const signature = createHmac('sha256', secret).update(`${header}.${payload}`).digest('base64url');
  return `${header}.${payload}.${signature}`;
}

export function verifyLegacyAdminToken(value: string): LegacyClaims | null {
  const secret = env.LEGACY_JWT_SECRET;
  if (!secret) return null;
  const [header, payload, signature, extra] = value.split('.');
  if (!header || !payload || !signature || extra) return null;
  const expected = createHmac('sha256', secret).update(`${header}.${payload}`).digest();
  let provided: Buffer;
  try { provided = Buffer.from(signature, 'base64url'); } catch { return null; }
  if (provided.length !== expected.length || !timingSafeEqual(provided, expected)) return null;
  try {
    const claims = JSON.parse(Buffer.from(payload, 'base64url').toString('utf8')) as LegacyClaims;
    if (claims.aud !== 'movetraq-admin' || !['access', 'refresh'].includes(claims.typ)
      || typeof claims.sub !== 'string' || !Array.isArray(claims.roles)
      || !Number.isInteger(claims.exp) || claims.exp <= Math.floor(Date.now() / 1000)) return null;
    return claims;
  } catch { return null; }
}

function verifyLegacyPassword(password: string, stored: string | undefined) {
  if (!stored) return false;
  const separator = stored.indexOf(':');
  if (separator <= 0) return false;
  const salt = stored.slice(0, separator);
  const expectedHex = stored.slice(separator + 1);
  if (!/^[0-9a-f]{64}$/i.test(expectedHex)) return false;
  const expected = Buffer.from(expectedHex, 'hex');
  const actual = pbkdf2Sync(password, salt, 100_000, 32, 'sha256');
  return timingSafeEqual(actual, expected);
}

function roleList(data: Record<string, unknown>) {
  const raw = data.roles;
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.filter((role): role is string => typeof role === 'string' && staffRoles.has(role)))];
}

function accountDisabled(data: Record<string, unknown>) {
  return Boolean(data.deletedAt) || Boolean(data.suspendedAt)
    || data.accountStatus === 'suspended' || data.accountStatus === 'deleted' || data.accountStatus === 'disabled';
}

function accountFrom(user: LegacyUser, roles: string[], emailFallback = '') {
  const data = user.data;
  const email = typeof data.email === 'string' ? data.email.toLowerCase() : emailFallback;
  const name = typeof data.name === 'string' ? data.name : email;
  const now = Math.floor(Date.now() / 1000);
  const claims = (typ: 'access' | 'refresh', ttl: number): LegacyClaims => ({
    sub: user.uid, email, name, roles, typ, iat: now, exp: now + ttl, aud: 'movetraq-admin',
  });
  return {
    user: { uid: user.uid, name, email, roles },
    session: {
      accessToken: token(claims('access', env.LEGACY_ACCESS_TOKEN_TTL_SECONDS)),
      refreshToken: token(claims('refresh', 60 * 60 * 24 * 14)),
      expiresAt: now + env.LEGACY_ACCESS_TOKEN_TTL_SECONDS,
      tokenType: 'bearer',
    },
  };
}

export async function signInLegacyAdmin(emailInput: string, password: string) {
  const email = emailInput.trim().toLowerCase();
  const { data: credential, error: credentialError } = await supabaseAdmin
    .from('credentials').select('user_id,password_hash').eq('email', email).maybeSingle();
  if (credentialError) {
    // Missing legacy tables indicate a project mismatch; don't misreport it as a bad password.
    throw new ApiError(503, 'LEGACY_AUTH_UNAVAILABLE', 'Could not reach the legacy account store.');
  }
  if (!credential) return null;
  const legacyCredential = credential as LegacyCredential;
  if (!verifyLegacyPassword(password, legacyCredential.password_hash)) {
    throw new ApiError(401, 'SIGNIN_FAILED', 'The email or password was not accepted.');
  }

  const { data: row, error: userError } = await supabaseAdmin.from('users').select('uid,data')
    .eq('uid', legacyCredential.user_id).maybeSingle();
  if (userError || !row || !row.data || typeof row.data !== 'object' || Array.isArray(row.data)) {
    throw new ApiError(503, 'LEGACY_ACCOUNT_UNAVAILABLE', 'Could not load the legacy account.');
  }
  const user = row as LegacyUser;
  const roles = roleList(user.data);
  if (!roles.length) throw new ApiError(403, 'ADMIN_ROLE_REQUIRED', 'This account does not have staff access.');
  if (accountDisabled(user.data)) {
    throw new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
  }
  return accountFrom(user, roles, email);
}

export async function refreshLegacyAdminSession(refreshToken: string) {
  const claims = verifyLegacyAdminToken(refreshToken);
  if (!claims || claims.typ !== 'refresh') {
    throw new ApiError(401, 'INVALID_SESSION', 'Please sign in again.');
  }
  const { data: row, error } = await supabaseAdmin.from('users').select('uid,data').eq('uid', claims.sub).maybeSingle();
  if (error || !row || !row.data || typeof row.data !== 'object' || Array.isArray(row.data)) {
    throw new ApiError(503, 'LEGACY_ACCOUNT_UNAVAILABLE', 'Could not load the legacy account.');
  }
  const user = row as LegacyUser;
  const roles = roleList(user.data);
  if (accountDisabled(user.data)) throw new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.');
  if (!roles.length || roles.some((role) => !claims.roles.includes(role))) {
    throw new ApiError(403, 'ADMIN_ROLE_REQUIRED', 'Staff access has changed.');
  }
  return accountFrom(user, roles);
}
