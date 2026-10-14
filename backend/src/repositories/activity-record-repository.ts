import { supabaseAdmin } from '../config/supabase.js';
import { databaseError } from './account-repository.js';
import { ApiError } from '../utils/api-error.js';
const columns:Record<string,string>={
  orders:'id,public_ref,status,sender_id,deliverer_id,service_type,total_amount_minor,currency,payment_status,escrow_status,evidence_status,created_at',
  payments:'id,user_id,order_id,provider,provider_reference,status,amount_minor,currency,verified_at,created_at',
  payouts:'id,deliverer_id,amount_minor,currency,status,provider_reference,approved_by,approved_at,completed_at,created_at',
  escrows:'id,order_id,status,amount_minor,released_amount_minor,funded_at,released_at,refunded_at',
  wallet_ledger_entries:'id,user_id,order_id,type,amount_minor,currency,provider_reference,created_at',
  platform_ledger_entries:'id,order_id,amount_minor,currency,created_at',
  verification_applications:'id,user_id,status,reviewed_by,reviewed_at,created_at',
  verification_documents:'id,application_id,user_id,document_type,mime_type,size_bytes,created_at',
  delivery_evidence:'id,order_id,submitted_by,captured_at,created_at',
  support_tickets:'id,order_id,reporter_id,category,status,priority,assigned_admin_id,created_at',
  disputes:'id,order_id,opened_by,status,priority,assigned_admin_id,created_at',
  messages:'id,conversation_id,sender_id,delivered_at,read_at,created_at',
  notifications:'id,user_id,type,read_at,created_at',
  profiles:'id,full_name,active_role,verification_status,created_at',
};
export async function activityRecord(id:string) {
  const {data:event,error}=await supabaseAdmin.from('platform_activity').select('entity,entity_id,order_id').eq('id',id).maybeSingle();
  databaseError(error);if(!event)throw new ApiError(404,'ACTIVITY_NOT_FOUND','Activity was not found.');
  const table=columns[event.entity]?event.entity:event.order_id?'orders':null;
  const target=columns[event.entity]?event.entity_id:event.order_id;
  if(!table||!target)return {record:null};
  const {data,error:recordError}=await supabaseAdmin.from(table).select(columns[table]).eq('id',target).maybeSingle();
  databaseError(recordError);return {entity:table,record:data};
}
