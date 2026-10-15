import type { AuthUser } from '../middleware/auth.js';
import { supabaseAdmin } from '../config/supabase.js';
import { ApiError } from '../utils/api-error.js';
export async function assertApprovedDeliverer(user:AuthUser) {
  const {data,error}=await supabaseAdmin.from('deliverer_profiles').select('verification_status').eq('user_id',user.id).maybeSingle();
  if(error)throw new ApiError(503,'DELIVERER_STATUS_UNAVAILABLE','Could not verify delivery approval.');
  if(!user.roles.includes('deliverer')||data?.verification_status!=='approved')throw new ApiError(403,'DELIVERER_APPROVAL_REQUIRED','Administrator approval is required for delivery work.');
}
