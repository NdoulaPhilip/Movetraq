import { z } from 'zod';
import { asyncHandler } from '../utils/async-handler.js';
import { ok,created } from '../utils/responses.js';
import { idSchema } from '../validators/account.js';
import { directoryQuery,activityQuery,userCreate,userPatch } from '../validators/admin-users.js';
import * as repository from '../repositories/admin-users-repository.js';
import { inviteManagedUser } from '../services/admin-users-service.js';
import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from '../repositories/account-repository.js';
import { activityRecord } from '../repositories/activity-record-repository.js';

export const users=asyncHandler(async(req,res)=>{ok(res,await repository.listManagedUsers(directoryQuery.parse(req.query)));});
export const detail=asyncHandler(async(req,res)=>{ok(res,await repository.managedUserDetail(idSchema.parse(req.params.id)));});
export const add=asyncHandler(async(req,res)=>{created(res,await inviteManagedUser(req.user!.id,userCreate.parse(req.body)));});
export const edit=asyncHandler(async(req,res)=>{
  const input=userPatch.parse(req.body);
  const id=idSchema.parse(req.params.id);
  await repository.manageUser(req.user!.id,id,input,'user_updated'); ok(res,{id});
});
export const deactivate=asyncHandler(async(req,res)=>{
  const input=z.object({reason:z.string().trim().min(5).max(500),confirmation:z.literal('DEACTIVATE')}).strict().parse(req.body);
  const id=idSchema.parse(req.params.id);
  await repository.manageUser(req.user!.id,id,{reason:input.reason,status:'deactivated'},'user_deactivated'); ok(res,{id});
});
export const activity=asyncHandler(async(req,res)=>{ok(res,await repository.platformActivity(activityQuery.parse(req.query)));});
export const audit=asyncHandler(async(req,res)=>{ok(res,await repository.platformActivity(activityQuery.parse(req.query),true));});
export const analytics=asyncHandler(async(_req,res)=>{ok(res,await repository.platformAnalytics());});
export const monitoring=asyncHandler(async(_req,res)=>{
  const {data,error}=await supabaseAdmin.rpc('activity_metrics');databaseError(error);ok(res,data);
});
export const relatedRecord=asyncHandler(async(req,res)=>{ok(res,await activityRecord(idSchema.parse(req.params.id)));});
