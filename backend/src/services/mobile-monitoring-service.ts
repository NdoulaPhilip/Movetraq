import { env } from '../config/env.js';
import { ApiError } from '../utils/api-error.js';

// This adapter reads the authoritative mobile store. Never alias legacy IDs to
// Supabase identities or copy wallet balances into a second financial system.
export async function mobileMonitoring(staffId: string, query: {view?:string;page?:number;q?:string}) {
  if (!env.MOBILE_MONITORING_URL || !env.MONITORING_SERVICE_TOKEN) {
    throw new ApiError(503,'MOBILE_MONITORING_UNCONFIGURED','Mobile database monitoring is not configured. Supabase results do not include Android activity.');
  }
  const url=new URL('/internal/monitoring',env.MOBILE_MONITORING_URL);
  if(url.protocol!=='https:' || url.username || url.password)throw new ApiError(503,'MOBILE_MONITORING_UNCONFIGURED','Secure mobile monitoring is required.');
  Object.entries(query).forEach(([key,value])=>{if(value!==undefined)url.searchParams.set(key,String(value));});
  try {
    const response=await fetch(url,{headers:{Authorization:`Bearer ${env.MONITORING_SERVICE_TOKEN}`,'X-Monitoring-Staff':staffId},
      redirect:'error',signal:AbortSignal.timeout(12000)});
    if(!response.ok)throw new Error();
    return await response.json();
  } catch { throw new ApiError(503,'MOBILE_MONITORING_UNAVAILABLE','The mobile activity database could not be reached. No records have been substituted or hidden.'); }
}
