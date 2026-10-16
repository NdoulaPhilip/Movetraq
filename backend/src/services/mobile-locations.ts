import { z } from 'zod';
import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from '../repositories/account-repository.js';
import { pointSchema } from '../validators/delivery.js';
import { ApiError } from '../utils/api-error.js';

const identifier=z.string().regex(/^[A-Za-z0-9_-]{1,140}$/);
export async function mobileLocationCommand(userId:string,command:string,input:Record<string,unknown>) {
  let args:Record<string,unknown>={};
  if(command==='save-address')args=z.object({id:identifier.optional(),label:z.string().trim().min(1).max(80),
    address:z.string().trim().min(3).max(1000),latitude:pointSchema.shape.latitude,longitude:pointSchema.shape.longitude,
    placeId:z.string().max(200).nullable().optional(),isDefault:z.boolean().default(false)}).strict().parse(input);
  if(command==='delete-address'||command==='default-address')args=z.object({id:identifier}).strict().parse(input);
  if(command==='read-location')args=z.object({orderId:identifier}).strict().parse(input);
  if(command==='register-order'){
    const address=pointSchema.extend({address:z.string().min(3).max(1000),placeId:z.string().max(200).nullable().optional()});
    args=z.object({orderId:identifier,pickup:address,destination:address,
      route:z.object({distanceMeters:z.number().int().positive(),durationSeconds:z.number().int().positive(),points:z.array(pointSchema).min(2).max(50000)})}).strict().parse(input);
  }
  if(command==='location'){
    args=z.object({orderId:identifier,senderId:identifier,latitude:pointSchema.shape.latitude,longitude:pointSchema.shape.longitude,
      accuracy:z.number().finite().min(0).max(500),capturedAt:z.string().datetime()}).strict().parse(input);
    const age=Date.now()-Date.parse(args.capturedAt as string);
    if(age>120000||age < -30000)throw new ApiError(422,'STALE_LOCATION','A fresh GPS sample is required.');
  }
  const {data,error}=await supabaseAdmin.rpc('mobile_location_command',{p_user:userId,p_command:command,p_input:args});
  databaseError(error);
  return data;
}
