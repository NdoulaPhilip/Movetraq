import type { NextFunction, Request, Response } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { ApiError } from '../utils/api-error.js';
import { asyncHandler } from '../utils/async-handler.js';
import { verifyLegacyAdminToken } from '../services/legacy-admin-auth-service.js';

export interface AuthUser {
  id: string;
  email?: string;
  roles: string[];
}

declare global {
  namespace Express {
    interface Request {
      user?: AuthUser;
      accessToken?: string;
    }
  }
}

export const requireAuth = asyncHandler(async (req: Request, _res: Response, next: NextFunction) => {
  const token = req.header('authorization')?.match(/^Bearer\s+(\S+)$/i)?.[1];
  if (!token) {
    next(new ApiError(401, 'AUTH_REQUIRED', 'Please sign in first.'));
    return;
  }

  const legacyClaims = verifyLegacyAdminToken(token);
  if (legacyClaims?.typ === 'access') {
    req.user = { id: legacyClaims.sub, email: legacyClaims.email, roles: legacyClaims.roles };
    req.accessToken = token;
    next();
    return;
  }

  const { data, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !data.user) {
    next(new ApiError(error?.status && error.status >= 500 ? 503 : 401, 'INVALID_TOKEN', 'Your session is invalid or expired.'));
    return;
  }

  const { data: security, error: securityError } = await supabaseAdmin.from('security_settings')
    .select('deleted_at,suspended_at').eq('user_id', data.user.id).maybeSingle();
  if (securityError || !security) {
    next(new ApiError(503, 'ACCOUNT_UNAVAILABLE', 'Could not verify account status.'));
    return;
  }
  if (security.deleted_at || security.suspended_at) {
    next(new ApiError(403, 'ACCOUNT_DISABLED', 'This account is disabled.'));
    return;
  }

  const { data: roles, error: roleError } = await supabaseAdmin
    .from('user_roles')
    .select('role')
    .eq('user_id', data.user.id);

  if (roleError) {
    next(new ApiError(500, 'ROLE_LOOKUP_FAILED', 'Could not load account roles.'));
    return;
  }

  req.user = {
    id: data.user.id,
    email: data.user.email,
    roles: roles?.map((item) => item.role) ?? ['sender'],
  };
  req.accessToken = token;
  next();
});

export function requireAdminRole(...allowed: string[]) {
  return (req: Request, _res: Response, next: NextFunction) => {
    const roles = req.user?.roles ?? [];
    if (!roles.some((role) => allowed.includes(role))) {
      next(new ApiError(403, 'ADMIN_ROLE_REQUIRED', 'You are not allowed to perform this admin action.'));
      return;
    }
    next();
  };
}
