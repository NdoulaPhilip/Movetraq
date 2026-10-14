import { supabaseAdmin } from '../config/supabase.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';
import { manageUser } from '../repositories/admin-users-repository.js';
import type { z } from 'zod';
import type { userCreate } from '../validators/admin-users.js';
import { logger } from '../utils/logger.js';

export async function inviteManagedUser(actor:string,input:z.infer<typeof userCreate>) {
  if (!env.ADMIN_INVITE_REDIRECT_URL) throw new ApiError(503,'INVITATIONS_UNAVAILABLE','Account invitations require an admin invitation redirect configuration.');
  const {data,error}=await supabaseAdmin.auth.admin.inviteUserByEmail(input.email,{
    redirectTo:env.ADMIN_INVITE_REDIRECT_URL,data:{full_name:input.name},
  });
  if (error || !data.user) throw new ApiError(400,'INVITATION_FAILED','Could not invite this account. Check whether it already exists.');
  try {
    await manageUser(actor,data.user.id,{name:input.name,roles:input.roles,reason:input.reason},'user_created');
  } catch {
    // Never leave an unreviewed invitation with elevated privileges.
    const {error:banError}=await supabaseAdmin.auth.admin.updateUserById(data.user.id,{ban_duration:'876000h'});
    logger.error({actorId:actor,targetId:data.user.id,restrictionFailed:!!banError},'User invitation provisioning failed');
    throw new ApiError(503,'PROVISIONING_INCOMPLETE','The invitation was created but provisioning failed. Inspect this account before retrying.');
  }
  return {id:data.user.id,invited:true};
}
