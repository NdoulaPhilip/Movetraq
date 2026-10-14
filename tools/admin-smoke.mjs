// Read-only admin API smoke check using the authorized owner account.
// Generates a login link without sending email; never prints link or tokens.
import fs from 'node:fs';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';
import {createClient} from '../backend/node_modules/@supabase/supabase-js/dist/index.mjs';
const env={...dotenv.parse(fs.readFileSync(new URL('../backend/.env',import.meta.url))),...process.env};
const client=createClient(env.SUPABASE_URL,env.SUPABASE_SERVICE_ROLE_KEY,{auth:{persistSession:false}});
const auth=createClient(env.SUPABASE_URL,env.SUPABASE_ANON_KEY,{auth:{persistSession:false}});
const link=await client.auth.admin.generateLink({type:'magiclink',email:'alebiosuopeyemi18@gmail.com'});
if(link.error)throw new Error('Unable to prepare owner session.');
const session=await auth.auth.verifyOtp({token_hash:link.data.properties.hashed_token,type:'magiclink'});
if(session.error||!session.data.session)throw new Error('Owner session unavailable.');
const base=process.env.ADMIN_SMOKE_API_URL||'https://movetraq-api-ymc2.onrender.com';
try{
 for(const path of ['/admin/me','/admin/analytics','/admin/analytics/orders','/admin/operations/health','/admin/users','/admin/deliverers','/admin/verification','/admin/orders','/admin/payments','/admin/ledger','/admin/payouts','/admin/ads','/admin/events','/admin/deletions','/admin/disputes','/admin/config','/admin/audit',`/admin/users/${session.data.user.id}`]){
  const response=await fetch(`${base}/v1${path}`,{headers:{Authorization:`Bearer ${session.data.session.access_token}`},signal:AbortSignal.timeout(60000)});
  const result=await response.json();if(!response.ok||!result.success)throw new Error(`${path}: ${response.status} ${result.error?.code??'failed'}`);
  console.log(JSON.stringify({path,status:response.status,records:Array.isArray(result.data)?result.data.length:result.data?.items?.length,roles:path==='/admin/me'?result.data.roles:undefined}));
 }
 const forbidden=await fetch(`${base}/v1/admin/staff`,{headers:{Authorization:`Bearer ${session.data.session.access_token}`}});
 if(forbidden.status!==403)throw new Error('Owner admin must not receive super-admin role management.');
 console.log(JSON.stringify({path:'/admin/staff',status:403,permissions_enforced:true}));
}finally{await auth.auth.signOut({scope:'local'});}
