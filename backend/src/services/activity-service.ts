import type { RequestHandler } from 'express';
import { supabaseAdmin } from '../config/supabase.js';
import { logger } from '../utils/logger.js';

export function activityCategory(path:string) {
  if (/payment|wallet|payout|escrow/.test(path)) return 'finance';
  if (/order|quote|delivery/.test(path)) return 'orders';
  if (/verification|deliverer/.test(path)) return 'deliverers';
  if (/message|notification|conversation/.test(path)) return 'communication';
  if (/support|dispute|report/.test(path)) return 'support';
  if (/admin/.test(path)) return 'security';
  return 'accounts';
}
export async function recordRequestActivity(event:Record<string,unknown>) {
  try {
    const {error}=await supabaseAdmin.from('platform_activity').insert(event);
    if(error) throw new Error('ACTIVITY_WRITE_FAILED');
  } catch {
    // Database outages cannot be audited in that database. Emit the same safe
    // envelope into structured operational logs for external log retention.
    logger.error({activity:event},'Activity persistence unavailable');
  }
}
export const observeActivity:RequestHandler=(req,res,next)=>{
  let code:string|undefined; let accountId:string|undefined;
  const json=res.json.bind(res);
  res.json=(body:unknown)=>{
    const response=body as {error?:{code?:string};data?:{user?:{uid?:string}}};
    const candidate=response?.error?.code;
    if(candidate && /^[A-Z0-9_]{1,80}$/.test(candidate)) code=candidate;
    accountId=response?.data?.user?.uid;
    return json(body);
  };
  res.once('finish',()=>{
    const route=typeof req.route?.path==='string'?req.route.path:'unmatched';
    // Read-only monitoring must not recursively create monitoring events.
    if(res.statusCode<400 && !['POST','PUT','PATCH','DELETE'].includes(req.method)) return;
    if(route==='/admin/platform/stream' || req.method==='OPTIONS' || route==='/health') return;
    const actor=req.user?.id ?? accountId;
    const idPattern=/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;
    const orderId=route.includes('/orders/') && idPattern.test(String(req.params.id))?req.params.id:null;
    const reference=String(req.params.reference ?? '');
    const status=res.statusCode;
    void recordRequestActivity({actor_id:actor && idPattern.test(actor)?actor:null,user_id:actor && idPattern.test(actor)?actor:null,
      event_type:status<400?'api_operation_succeeded':status===401||status===403?'access_rejected':'api_operation_failed',
      category:status===401||status===403?'security':activityCategory(route),description:`${req.method} ${route}`,
      entity:'api',entity_id:null,order_id:orderId,reference:/^[a-zA-Z0-9_-]{1,128}$/.test(reference)?reference:null,
      outcome:status<400?'successful':status===401||status===403?'rejected':'failed',error_code:code ?? (status>=400?`HTTP_${status}`:null),
      request_id:req.requestId,source:'http',metadata:{httpStatus:status}});
  });
  next();
};
