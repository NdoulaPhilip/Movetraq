export interface StaffUser { uid: string; name: string; email: string; roles: string[]; }
export interface AuthResult { user: StaffUser; session: { accessToken: string; refreshToken: string; expiresAt: number }; }
export interface VerificationDocument { id: string; document_type: string; mime_type: string; size_bytes: number; upload_verified_at: string | null; }
export interface Application { id: string; user_id: string; status: string; identity_info: { fullName?: string; dateOfBirth?: string };
  legacy_user_id?:string|null;
  transport_info: { transportType?: string }; safety_declarations: Record<string, boolean>; created_at: string;
  review_notes: string | null; documents: VerificationDocument[]; }
export interface PricingConfiguration { baseMinor: number; perKmMinor: number; perMinuteMinor: number; helperMinor: number;
  stairsMinor: number; minimumMinor: number; platformFeeBps: number; surgeBps: number;
  vehicleBps: { car: number; van: number; large_van: number }; maxDistanceMeters: number; }
export interface PricingRule { id: string; service_type: string; configuration: PricingConfiguration; created_at: string; }

const apiUrl = (import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1').replace(/\/$/, '');
let session: AuthResult | null = null;
let refreshing: Promise<void> | null = null;
const listeners = new Set<() => void>();
function setSession(value: AuthResult | null) { session = value; for (const listener of listeners) listener(); }
export const authStore = { getSnapshot: () => session, subscribe: (listener: () => void) => {
  listeners.add(listener); return () => listeners.delete(listener);
} };

async function rawRequest<T>(path: string, method: string, body?: unknown, token?: string, headers: Record<string, string> = {}): Promise<T> {
  let response: Response;
  try {
    response = await fetch(`${apiUrl}${path}`, { method, headers: { 'Content-Type': 'application/json',
      ...headers, ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body), signal: AbortSignal.timeout(15000) });
  } catch { throw new Error('Could not reach MoveTraq. Please try again.'); }
  let result;
  try { result = await response.json(); }
  catch { throw new Error('MoveTraq returned an invalid response.'); }
  if (!response.ok || !result.success) {
    const error = new Error(result.error?.message ?? 'The request failed.') as Error & { status?: number };
    error.status = response.status; throw error;
  }
  return result.data as T;
}

async function refreshSession(current:AuthResult) {
  if (!refreshing) {
    refreshing=rawRequest<AuthResult>('/auth/refresh','POST',{refreshToken:current.session.refreshToken})
      .then(result=>{if(session?.session.refreshToken===current.session.refreshToken)setSession(result);})
      .catch(failure=>{if(session?.user.uid===current.user.uid)setSession(null);throw failure;})
      .finally(()=>{refreshing=null;});
  }
  await refreshing;
  if(!session||session.user.uid!==current.user.uid)throw new Error('Please sign in again.');
  return session;
}
export async function request<T>(path: string, method = 'GET', body?: unknown, headers: Record<string, string> = {}): Promise<T> {
  const current = session;
  if (!current) throw new Error('Please sign in.');
  try { return await rawRequest(path, method, body, current.session.accessToken, headers); }
  catch (error) {
    if ((error as { status?: number }).status !== 401) throw error;
    if (!session || session.user.uid !== current.user.uid) throw new Error('Please sign in again.');
    if (session.session.accessToken !== current.session.accessToken) {
      return rawRequest(path, method, body, session.session.accessToken, headers);
    }
    await refreshSession(current);
    if (!session || session.user.uid !== current.user.uid) throw new Error('Please sign in again.');
    return rawRequest(path, method, body, session.session.accessToken, headers);
  }
}
export async function signIn(email: string, password: string) {
  const result = await rawRequest<AuthResult>('/auth/signin', 'POST', { emailOrPhone: email, password });
  if (!result.user.roles.some((role) => ['support', 'operations', 'verification_agent', 'finance', 'admin', 'super_admin'].includes(role))) {
    await rawRequest('/auth/logout', 'POST', undefined, result.session.accessToken).catch(() => undefined);
    throw new Error('This account does not have access to this console.');
  }
  setSession(result);
}
export async function signOut() {
  const token = session?.session.accessToken;
  setSession(null);
  if (token) await rawRequest('/auth/logout', 'POST', undefined, token).catch(() => undefined);
}
export async function setInvitedPassword(accessToken:string,password:string) {
  // Validate the invitation session against the backend, never decoded claims.
  await rawRequest('/users/me','GET',undefined,accessToken);
  await rawRequest('/auth/password','POST',{password},accessToken);
  await rawRequest('/auth/logout','POST',undefined,accessToken).catch(()=>undefined);
}

export async function watchActivity(signal:AbortSignal,onEvent:(event:string)=>void) {
  let current=session;
  if(!current)throw new Error('Please sign in.');
  if(current.session.expiresAt*1000<=Date.now()+30000){
    current=await refreshSession(current);
  }
  const open=()=>fetch(`${apiUrl}/admin/platform/stream`,{headers:{Authorization:`Bearer ${current!.session.accessToken}`,Accept:'text/event-stream'},signal});
  let response=await open();
  if(response.status===401){await response.body?.cancel();current=await refreshSession(current);response=await open();}
  if(!response.ok||!response.body||!response.headers.get('content-type')?.includes('text/event-stream'))throw new Error('Activity stream unavailable.');
  const reader=response.body.getReader();const decoder=new TextDecoder();let pending='';
  try{
    while(!signal.aborted){
      const {done,value}=await reader.read();if(done)break;
      pending+=decoder.decode(value,{stream:true});
      if(pending.length>65536)throw new Error('Invalid activity stream.');
      let end:number;
      while((end=pending.indexOf('\n\n'))>=0){
        const block=pending.slice(0,end);pending=pending.slice(end+2);
        const event=block.split('\n').find(line=>line.startsWith('event: '))?.slice(7);
        if(event)onEvent(event);
      }
    }
  }finally{await reader.cancel().catch(()=>undefined);reader.releaseLock();}
}
