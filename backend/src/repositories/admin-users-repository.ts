import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { ApiError } from '../utils/api-error.js';
import type { z } from 'zod';
import type { directoryQuery, activityQuery } from '../validators/admin-users.js';

export async function listManagedUsers(input: z.infer<typeof directoryQuery>) {
  let query = supabaseAdmin.from('admin_user_directory').select('*', { count: 'exact' });
  if (input.q) {
    // PostgREST filter grammar must not receive user-supplied delimiters.
    const escaped = input.q.replace(/[^\p{L}\p{N}@ ._+-]/gu, ' ').replace(/[%_]/g,' ');
    query = query.or(`full_name.ilike.%${escaped}%,email.ilike.%${escaped}%`);
  }
  if (input.role) query = query.contains('roles',[input.role]);
  if (input.status) query = query.eq('account_status',input.status);
  if (input.from) query = query.gte('created_at',input.from);
  if (input.to) query = query.lte('created_at',input.to);
  if (input.staff === 'true') query = query.overlaps('roles',['support','verification_agent','finance','operations','admin','super_admin']);
  const { data,error,count } = await query.order('created_at',{ascending:false}).order('id').range(input.page*25,input.page*25+24);
  databaseError(error); return { users:data ?? [],total:count ?? 0,page:input.page };
}
export async function manageUser(actor: string,target: string,input: Record<string,unknown>,action: string) {
  const { data,error } = await supabaseAdmin.rpc('manage_platform_user',{p_actor:actor,p_target:target,p_input:input,p_action:action});
  if (error?.code === '42501') throw new ApiError(403,'SUPER_ADMIN_REQUIRED','Super Admin access is required.');
  if (error?.code === '22023') throw new ApiError(409,'PROTECTED_ACCOUNT','This account change is not permitted.');
  databaseError(error); return data;
}
export async function platformActivity(input: z.infer<typeof activityQuery>,audit=false) {
  let query = supabaseAdmin.from(audit ? 'audit_logs':'platform_activity')
    .select(audit ? 'id,admin_id,action,entity,entity_id,previous_state,new_state,metadata,created_at':'*',{count:'exact'});
  if (input.type) query=query.eq(audit ? 'action':'event_type',input.type);
  if (input.userId) query=audit?query.eq('admin_id',input.userId):query.or(`actor_id.eq.${input.userId},user_id.eq.${input.userId}`);
  if(input.from)query=query.gte('created_at',input.from);
  if(input.to)query=query.lte('created_at',input.to);
  if(!audit){
    if(input.category)query=query.eq('category',input.category);
    if(input.outcome)query=query.eq('outcome',input.outcome);
    if(input.orderId)query=query.eq('order_id',input.orderId);
    if(input.reference)query=query.eq('reference',input.reference);
    if(input.status)query=query.eq('new_status',input.status);
    if(input.q){const safe=input.q.replace(/[^\p{L}\p{N} _-]/gu,' ').replace(/_/g,' ');query=query.or(`description.ilike.%${safe}%,event_type.ilike.%${safe}%`);}
  }
  const {data,error,count}=await query.order('created_at',{ascending:false}).order('id').range(input.page*25,input.page*25+24);
  databaseError(error); return {events:data ?? [],total:count ?? 0,page:input.page};
}
export async function managedUserDetail(id:string) {
  const {data:user,error}=await supabaseAdmin.from('admin_user_directory').select('*').eq('id',id).maybeSingle();
  databaseError(error); if (!user) throw new ApiError(404,'USER_NOT_FOUND','User was not found.');
  const queries = [
    supabaseAdmin.from('orders').select('id,public_ref,status,service_type,total_amount_minor,currency,created_at').or(`sender_id.eq.${id},deliverer_id.eq.${id}`),
    supabaseAdmin.from('wallet_ledger_entries').select('id,type,amount_minor,currency,order_id,created_at').eq('user_id',id),
    supabaseAdmin.from('verification_applications').select('id,status,created_at,reviewed_at').eq('user_id',id),
    supabaseAdmin.from('support_tickets').select('id,category,status,created_at').eq('reporter_id',id),
  ];
  const results=await Promise.all(queries.map(q=>q.order('created_at',{ascending:false}).limit(25)));
  results.forEach(r=>databaseError(r.error));
  return {user,orders:results[0].data,transactions:results[1].data,verification:results[2].data,reports:results[3].data,
    activity:(await platformActivity({userId:id,page:0})).events};
}
export async function platformAnalytics() {
  const base=()=>supabaseAdmin.from('admin_user_directory').select('id',{count:'exact',head:true});
  const since=new Date(Date.now()-7*86400000).toISOString();
  const results=await Promise.all([base(),base().eq('account_status','active'),base().eq('account_status','suspended'),
    base().overlaps('roles',['admin','super_admin']),base().gte('created_at',since),
    supabaseAdmin.from('admin_online_deliverers').select('user_id',{count:'exact',head:true}),
    base().eq('account_status','active').gte('recent_activity',since)]);
  results.forEach(r=>databaseError(r.error));
  return Object.fromEntries(['totalUsers','enabledUsers','suspendedUsers','administrators','newRegistrations','onlineVerifiedDeliverers','activeUsers7d'].map((k,i)=>[k,results[i].count ?? 0]));
}
