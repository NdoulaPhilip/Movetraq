import { randomUUID,timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { env } from '../config/env.js';
import { supabaseAdmin } from '../config/supabase.js';
import { deliveryRpc } from '../repositories/delivery-repository.js';
import { databaseError } from '../repositories/account-repository.js';
import { ApiError } from '../utils/api-error.js';
import { asyncHandler } from '../utils/async-handler.js';
import { ok } from '../utils/responses.js';
import { applicationSchema,documentSchema } from '../validators/delivery.js';
const envelope=z.object({userId:z.string().regex(/^user_[A-Za-z0-9_-]{1,120}$/),command:z.enum(['status','start','reserve','confirm','submit','read_notification']),input:z.record(z.string(),z.unknown()).default({})}).strict();
export const mobileDeliverer=asyncHandler(async(req,res)=>{
  const supplied=Buffer.from(req.header('authorization')??'');const expected=Buffer.from(`Bearer ${env.MONITORING_SERVICE_TOKEN??''}`);
  if(!env.MONITORING_SERVICE_TOKEN||supplied.length!==expected.length||!timingSafeEqual(supplied,expected))throw new ApiError(401,'SERVICE_AUTH_REQUIRED','Service authentication required.');
  const {userId,command,input}=envelope.parse(req.body);let args:Record<string,unknown>=input;
  if(command==='start'){
    const {accountEmail,...application}=input;
    args={...applicationSchema.parse(application),accountEmail:z.string().email().parse(accountEmail)};
  }
  if(command==='reserve'){
    const applicationId=z.string().uuid().parse(input.applicationId);const document=documentSchema.parse({documentType:input.documentType,mimeType:input.mimeType});
    const extension=document.mimeType==='application/pdf'?'pdf':document.mimeType==='image/png'?'png':'jpg';
    const path=`mobile/${userId}/${applicationId}/${randomUUID()}.${extension}`;
    const record=await deliveryRpc('mobile_deliverer_command',{p_user:userId,p_command:command,p_input:{...document,applicationId,path}});
    const upload=await supabaseAdmin.storage.from('verification-documents').createSignedUploadUrl(path,{upsert:false});
    if(upload.error||!upload.data)throw new ApiError(503,'UPLOAD_UNAVAILABLE','Private upload is unavailable.');
    ok(res,{documentId:record.id,signedUrl:upload.data.signedUrl,storageOrigin:env.SUPABASE_URL});return;
  }
  if(command==='confirm'){
    const id=z.string().uuid().parse(input.documentId);
    const {data:document,error}=await supabaseAdmin.from('verification_documents').select('*,application:verification_applications!inner(legacy_user_id)').eq('id',id).maybeSingle();databaseError(error);
    if(!document||document.application.legacy_user_id!==userId)throw new ApiError(404,'DOCUMENT_NOT_FOUND','Document was not found.');
    const uploaded=await supabaseAdmin.storage.from('verification-documents').info(document.storage_path);
    if(uploaded.error||!uploaded.data||uploaded.data.contentType!==document.mime_type||!uploaded.data.size||uploaded.data.size>10485760)throw new ApiError(409,'INVALID_DOCUMENT','Upload the required document before confirming.');
    args={documentId:id,path:document.storage_path,size:uploaded.data.size};
  }
  if(command==='submit')args={applicationId:z.string().uuid().parse(input.applicationId)};
  if(command==='read_notification')args=z.object({notificationId:z.string().uuid()}).strict().parse(input);
  if(command==='status')args={};
  const result=await deliveryRpc('mobile_deliverer_command',{p_user:userId,p_command:command,p_input:args});
  ok(res,{...result,...(command==='status'?{storageOrigin:env.SUPABASE_URL}:{})});
});
