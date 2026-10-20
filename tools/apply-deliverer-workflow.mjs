// Readiness check by default. --apply uses only the explicitly configured Supabase database.
import fs from 'node:fs';
import {fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
import dotenv from '../backend/node_modules/dotenv/lib/main.js';
import pg from '../server/node_modules/pg/lib/index.js';
const root=fileURLToPath(new URL('../',import.meta.url));
const local=dotenv.parse(fs.readFileSync(`${root}backend/.env`));
const env={...local,...process.env};
const files=['0017_pending_approval_status.sql','0018_deliverer_application_workflow.sql','0019_deliverer_work_preferences.sql'];
const sources=files.map(name=>fs.readFileSync(`${root}supabase/migrations/${name}`,'utf8'));
console.log(JSON.stringify({migrations:files.map((name,i)=>({name,sha256:createHash('sha256').update(sources[i]).digest('hex')}))}));
if(process.argv.includes('--check-hosted')){
  try{
    if(!env.SUPABASE_URL||!env.SUPABASE_SERVICE_ROLE_KEY)throw new Error();
    const result=await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/mobile_verification_notifications`,{method:'POST',redirect:'error',signal:AbortSignal.timeout(30000),
      headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({p_user:'user_deployment_probe'})});
    await result.body?.cancel();
    const preferences=await fetch(`${env.SUPABASE_URL}/rest/v1/verification_applications?select=work_preferences&limit=0`,{headers:{apikey:env.SUPABASE_SERVICE_ROLE_KEY,Authorization:`Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`},signal:AbortSignal.timeout(30000)});
    await preferences.body?.cancel();
    console.log(JSON.stringify({hostedWorkflowReady:result.ok,workPreferencesReady:preferences.ok,httpStatus:result.status,databaseWrites:'none'}));
    process.exit(result.ok&&preferences.ok?0:1);
  }catch{console.error('Hosted workflow verification is unavailable; credentials and response details withheld.');process.exit(1);}
}
if(!env.SUPABASE_DB_URL){console.log('Set SUPABASE_DB_URL in ignored backend/.env, or apply these files in order using the Supabase SQL Editor. Do not use the mobile Render database.');process.exit(process.argv.includes('--apply')?1:0);}
let project,target;
try{project=new URL(env.SUPABASE_URL).hostname.split('.')[0];target=new URL(env.SUPABASE_DB_URL);}
catch{throw new Error('Valid Supabase project and database URLs are required; nothing changed.');}
if(!['postgres:','postgresql:'].includes(target.protocol)||!(target.hostname===`db.${project}.supabase.co`||decodeURIComponent(target.username)===`postgres.${project}`)){
  throw new Error('Database URL does not identify the configured Supabase project; nothing changed.');
}
let client;
const check=async()=>{
  const result=await client.query(`select
    exists(select 1 from pg_type t join pg_enum e on e.enumtypid=t.oid join pg_namespace n on n.oid=t.typnamespace where n.nspname='public' and t.typname='verification_status' and e.enumlabel='pending_approval') as status_ready,
    to_regprocedure('public.mobile_verification_notifications(text)') is not null as inbox_ready,
    to_regprocedure('public.mobile_deliverer_preferences(text,jsonb)') is not null as preferences_ready`);
  return result.rows[0];
};
try{
  client=new pg.Client({connectionString:env.SUPABASE_DB_URL,connectionTimeoutMillis:15000,
    ssl:{rejectUnauthorized:true,...(env.SUPABASE_DB_CA_CERT_BASE64?{ca:Buffer.from(env.SUPABASE_DB_CA_CERT_BASE64,'base64').toString('utf8')}:{})}});
  await client.connect();
  await client.query("select pg_advisory_lock(hashtext('movetraq:deliverer-workflow:0018'))");
  const state=await check();console.log(JSON.stringify({before:state}));
  if(process.argv.includes('--apply')){
    // Separate queries commit the enum addition before the transactional workflow migration.
    if(!state.status_ready)await client.query(sources[0]);
    if(!state.inbox_ready)await client.query(sources[1]);
    if(!state.preferences_ready)await client.query(sources[2]);
    console.log(JSON.stringify({after:await check(),result:'applied'}));
  }
}catch(error){
  await client?.query('rollback').catch(()=>undefined);
  console.error(JSON.stringify({result:'failed',code:error.code??'CONNECTION_OR_MIGRATION_ERROR',detail:'Migration did not complete. Connection strings and database error details withheld.'}));
  process.exitCode=1;
}finally{await client?.end().catch(()=>undefined);}
