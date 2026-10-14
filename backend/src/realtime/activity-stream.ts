import { randomUUID } from 'node:crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { asyncHandler } from '../utils/async-handler.js';
import { ApiError } from '../utils/api-error.js';

export async function streamAuthorized(id:string,token:string) {
  const [identity,security,roles]=await Promise.all([
    supabaseAdmin.auth.getUser(token),
    supabaseAdmin.from('security_settings').select('deleted_at,suspended_at').eq('user_id',id).maybeSingle(),
    supabaseAdmin.from('user_roles').select('role').eq('user_id',id),
  ]);
  return !identity.error && identity.data.user?.id===id && !security.error && !!security.data
    && !security.data.deleted_at && !security.data.suspended_at && !roles.error
    && roles.data?.some(r=>r.role==='super_admin');
}
const active=new Map<string,number>();
export const activityStream=asyncHandler(async(req,res)=>{
  const id=req.user!.id;
  if((active.get(id)??0)>=3) throw new ApiError(429,'STREAM_LIMIT','Too many activity windows are open.');
  let closed=false;let checking=false;let timer:ReturnType<typeof setInterval>|undefined;
  let deadline:ReturnType<typeof setTimeout>|undefined;
  const channel=supabaseAdmin.channel(`admin-activity-${randomUUID()}`);
  active.set(id,(active.get(id)??0)+1);
  const close=()=>{
    if(closed)return;closed=true;if(timer)clearInterval(timer);if(deadline)clearTimeout(deadline);
    active.set(id,Math.max(0,(active.get(id)??1)-1));if(!active.get(id))active.delete(id);
    void supabaseAdmin.removeChannel(channel).catch(()=>undefined);res.end();
  };
  const send=(event:string)=>{
    if(closed)return;
    if(!res.headersSent){res.status(200).set({'Content-Type':'text/event-stream','Cache-Control':'no-store','X-Accel-Buffering':'no'});res.flushHeaders();}
    // Emit invalidation hints only. Contents are fetched through current RBAC.
    if(!res.write(`event: ${event}\ndata: {}\n\n`))close();
  };
  res.on('close',close);
  deadline=setTimeout(()=>{send('unavailable');close();},10000);
  timer=setInterval(()=>{
    if(checking||closed)return;checking=true;
    void streamAuthorized(id,req.accessToken!).then(allowed=>{
      if(!allowed){send('unauthorized');close();}else send('heartbeat');
    }).catch(()=>{send('unavailable');close();}).finally(()=>{checking=false;});
  },20000);
  try { channel.on('postgres_changes',{event:'INSERT',schema:'public',table:'platform_activity'},()=>send('invalidate'))
    .on('postgres_changes',{event:'INSERT',schema:'public',table:'audit_logs'},()=>send('invalidate'))
    .subscribe(status=>{
      if(status==='SUBSCRIBED'){if(deadline)clearTimeout(deadline);send('ready');}
      else if(status==='CHANNEL_ERROR'||status==='TIMED_OUT'||status==='CLOSED'){send('unavailable');close();}
    }); } catch(error) { close();throw error; }
});
