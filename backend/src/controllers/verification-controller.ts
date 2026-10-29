import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from '../repositories/account-repository.js';
import { deliveryRpc } from '../repositories/delivery-repository.js';
import * as service from '../services/verification-service.js';
import { asyncHandler } from '../utils/async-handler.js';
import { ok, created } from '../utils/responses.js';
import { idSchema, paginationSchema } from '../validators/account.js';
import { applicationSchema, documentSchema, reviewSchema } from '../validators/delivery.js';
import { z } from 'zod';
import { verifyLegacyAdminToken } from '../services/legacy-admin-auth-service.js';
import { logger } from '../utils/logger.js';
const queueSchema=paginationSchema.extend({status:z.enum(['pending','all']).default('pending')});

export const start = asyncHandler(async (req, res) => { created(res, await deliveryRpc('start_deliverer_application', { p_user_id: req.user!.id, p_input: applicationSchema.parse(req.body) })); });
export const application = asyncHandler(async (req, res) => { ok(res, await service.ownedApplication(req.user!.id, idSchema.parse(req.params.id))); });
export const upload = asyncHandler(async (req, res) => {
  const input = documentSchema.parse(req.body);
  created(res, await service.documentUpload(req.user!.id, idSchema.parse(req.params.id), input.documentType, input.mimeType));
});
export const confirm = asyncHandler(async (req, res) => { ok(res, await service.confirmDocument(req.user!, idSchema.parse(req.params.id))); });
export const download = asyncHandler(async (req, res) => { ok(res, await service.signedDocument(req.user!, idSchema.parse(req.params.id))); });
export const submit = asyncHandler(async (req, res) => { ok(res, await deliveryRpc('submit_deliverer_application', { p_user_id: req.user!.id, p_application_id: idSchema.parse(req.params.id) })); });
export const review = asyncHandler(async (req, res) => {
  const input = reviewSchema.parse(req.body);
  ok(res, await deliveryRpc('review_deliverer_application', { p_admin_id: req.user!.id, p_application_id: idSchema.parse(req.params.id), p_status: input.status, p_notes: input.notes }));
});
export const queue = asyncHandler(async (req, res) => {
  const { limit, offset, status } = queueSchema.parse(req.query);
  let query = supabaseAdmin.from('verification_applications').select('*,documents:verification_documents(id,document_type,mime_type,size_bytes,upload_verified_at)');
  if(status==='pending')query=query.in('status',['pending_approval','submitted','under_review']);
  const { data, error } = await query.order('submitted_at',{ascending:false,nullsFirst:false}).order('id').range(offset, offset + limit - 1);
  if (error) logger.warn({ databaseErrorCode: error.code || 'UNKNOWN', databaseErrorName: error.name,
    databaseErrorMessage: error.message.slice(0, 240) }, 'Verification queue query failed');
  databaseError(error); ok(res, { applications: data ?? [], limit, offset });
});
export const notifications = asyncHandler(async(req,res)=>{
  const {limit,offset}=paginationSchema.parse(req.query);
  if (verifyLegacyAdminToken(req.accessToken ?? '')?.typ === 'access') {
    ok(res,{notifications:[],unreadCount:0,legacyInboxAvailable:false,limit,offset});
    return;
  }
  const {data,error,count}=await supabaseAdmin.from('notifications').select('id,type,title,body,data,created_at,read_at',{count:'exact'})
    .eq('user_id',req.user!.id).eq('type','deliverer_application').is('read_at',null)
    .order('created_at',{ascending:false}).order('id').range(offset,offset+limit-1);
  databaseError(error);ok(res,{notifications:data??[],unreadCount:count??data?.length??0});
});
