import { timingSafeEqual } from 'node:crypto';
import { z } from 'zod';
import { env } from '../config/env.js';
import { addressProvider } from '../services/address-search.js';
import { mapService } from '../integrations/maps.js';
import { pointSchema } from '../validators/delivery.js';
import { mobileLocationCommand } from '../services/mobile-locations.js';
import { ApiError } from '../utils/api-error.js';
import { asyncHandler } from '../utils/async-handler.js';
import { ok } from '../utils/responses.js';

const envelope=z.object({userId:z.string().regex(/^user_[A-Za-z0-9_-]{1,120}$/),
  command:z.enum(['search','geocode','reverse','route','addresses','save-address','delete-address','default-address','location','read-location','register-order']),
  input:z.record(z.string(),z.unknown()).default({})}).strict();
export const mobileMaps=asyncHandler(async(req,res)=>{
  const supplied=Buffer.from(req.header('authorization')??'');
  const expected=Buffer.from(`Bearer ${env.MONITORING_SERVICE_TOKEN??''}`);
  if(!env.MONITORING_SERVICE_TOKEN||supplied.length!==expected.length||!timingSafeEqual(supplied,expected))throw new ApiError(401,'SERVICE_AUTH_REQUIRED','Service authentication required.');
  const {userId,command,input}=envelope.parse(req.body);
  res.setHeader('Cache-Control','no-store');
  if(command==='search'||command==='geocode'){
    const query=z.string().trim().min(3).max(200).parse(input.query);
    const results=await addressProvider.search(query);
    if(command==='search'){ok(res,{suggestions:results});return;}
    if(!results.length)throw new ApiError(422,'ADDRESS_NOT_FOUND','No matching address was found. Select another address.');
    ok(res,{location:results[0]});return;
  }
  if(command==='reverse'){ok(res,{location:await addressProvider.reverse(pointSchema.parse(input))});return;}
  if(command==='route'){
    const args=z.object({pickup:pointSchema,destination:pointSchema}).strict().parse(input);
    ok(res,await mapService.route(args.pickup,args.destination));return;
  }
  ok(res,await mobileLocationCommand(userId,command,input));
});
