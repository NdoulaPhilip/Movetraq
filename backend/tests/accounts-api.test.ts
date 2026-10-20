import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';
import type { Server } from 'node:http';
import type { AddressInfo } from 'node:net';

const fixtures = vi.hoisted(() => {
  const userId = '10000000-0000-4000-8000-000000000001';
  const queries: { table: string; method: string; args: unknown[] }[] = [];
  const results: Record<string, { data: any; error: any; count?: number }> = {};
  const getUser = vi.fn();
  const rpc = vi.fn();
  const invite = vi.fn();
  const ban = vi.fn();
  const auth = { signUp: vi.fn(), signInWithPassword: vi.fn(), refreshSession: vi.fn(),
    resetPasswordForEmail: vi.fn(), verifyOtp: vi.fn() };
  const from = vi.fn((table: string) => {
    const builder: Record<string, any> = {};
    for (const method of ['insert','select', 'eq', 'order', 'range', 'update', 'delete', 'upsert', 'is','or','gte','lte','contains','overlaps','limit','ilike','in']) {
      builder[method] = (...args: unknown[]) => { queries.push({ table, method, args }); return builder; };
    }
    builder.maybeSingle = builder.single = () => Promise.resolve(results[table]);
    builder.then = (resolve: (value: unknown) => void) => Promise.resolve(results[table]).then(resolve);
    return builder;
  });
  return { userId, queries, results, getUser, rpc, auth, from, invite, ban };
});

vi.mock('../src/config/env.js', () => ({
  // Exercise the optional provider's unconfigured path without external requests.
  env: { MAPS_PROVIDER: 'google', NODE_ENV: 'test', LOG_LEVEL: 'silent', AUTH_REDIRECT_URL: 'movetraq://auth/callback',ADMIN_INVITE_REDIRECT_URL:'http://localhost:5173/accept-invitation' },
  corsOrigins: ['http://localhost:5173'],
}));
vi.mock('../src/config/supabase.js', () => ({
  supabaseAdmin: { auth: { getUser: fixtures.getUser, admin:{inviteUserByEmail:fixtures.invite,updateUserById:fixtures.ban} }, from: fixtures.from, rpc: fixtures.rpc },
  createAuthClient: () => ({ auth: fixtures.auth }),
}));

import { createApp } from '../src/app.js';

let server: Server;
let baseUrl: string;
async function request(path: string, method = 'GET', body?: unknown, authorization: string | null = 'Bearer valid-token', key?: string) {
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  if (authorization) headers.Authorization = authorization;
  if (key) headers['Idempotency-Key'] = key;
  const response = await fetch(`${baseUrl}/api/v1${path}`, {
    method, headers, body: body === undefined ? undefined : JSON.stringify(body),
  });
  return { status: response.status, body: await response.json() };
}

beforeAll(async () => {
  server = createApp().listen(0, '127.0.0.1');
  await new Promise<void>((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
});
afterAll(async () => {
  server.closeAllConnections();
  await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
});
beforeEach(() => {
  vi.clearAllMocks();
  fixtures.queries.length = 0;
  fixtures.getUser.mockResolvedValue({ data: { user: { id: fixtures.userId, email: 'sender@example.test' } }, error: null });
  fixtures.results.profiles = { data: { id: fixtures.userId, full_name: 'Sender', phone: null, active_role: 'sender', membership_tier: 'standard', verification_status: 'not_started' }, error: null };
  fixtures.results.user_roles = { data: [{ role: 'sender' }], error: null };
  fixtures.results.wallet_accounts = { data: { id: 'wallet-id', currency: 'NGN', status: 'active' }, error: null };
  fixtures.results.wallet_balances = { data: { balance_minor: '12050' }, error: null };
  fixtures.results.deliverer_profiles = { data: null, error: null };
  fixtures.results.security_settings = { data: { deleted_at: null }, error: null };
  fixtures.results.notifications = { data: [], error: null };
  fixtures.results.platform_activity = {data:[],error:null,count:0};
  fixtures.rpc.mockResolvedValue({ data: { id: 'address-id' }, error: null });
});

describe('account API security and persistence contract', () => {
  it('requires authorized review staff and binds the decision to the authenticated admin',async()=>{
    const path=`/admin/verification-applications/${fixtures.userId}/review`;
    const decision={status:'under_review',notes:'Reviewing the uploaded identity document'};
    expect((await request(path,'POST',decision,null)).status).toBe(401);
    for(const role of ['sender','deliverer','finance','support','operations']){
      fixtures.results.user_roles={data:[{role}],error:null};
      expect((await request(path,'POST',decision)).status).toBe(403);
      expect((await request('/admin/verification-applications')).status).toBe(403);
      expect((await request('/admin/verification-notifications')).status).toBe(403);
    }
    expect(fixtures.rpc).not.toHaveBeenCalled();
    fixtures.results.user_roles={data:[{role:'verification_agent'}],error:null};
    expect((await request(path,'POST',{...decision,adminId:'forged-admin'})).status).toBe(400);
    expect((await request(path,'POST',decision)).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenCalledWith('review_deliverer_application',{p_admin_id:fixtures.userId,p_application_id:fixtures.userId,p_status:'under_review',p_notes:decision.notes});
  });
  it('filters the review queue before pagination so drafts cannot hide pending applications',async()=>{
    fixtures.results.user_roles={data:[{role:'admin'}],error:null};
    fixtures.results.verification_applications={data:[],error:null};
    expect((await request('/admin/verification-applications?limit=10&offset=20&status=pending')).status).toBe(200);
    const scope=fixtures.queries.findIndex(query=>query.table==='verification_applications'&&query.method==='in');
    const page=fixtures.queries.findIndex(query=>query.table==='verification_applications'&&query.method==='range');
    expect(fixtures.queries[scope].args).toEqual(['status',['pending_approval','submitted','under_review']]);
    expect(scope).toBeLessThan(page);
    expect(fixtures.queries[page].args).toEqual([20,29]);
    fixtures.queries.length=0;
    expect((await request('/admin/verification-applications?status=all')).status).toBe(200);
    expect(fixtures.queries.some(query=>query.method==='in'&&query.table==='verification_applications')).toBe(false);
  });
  it('rejects application status and ownership fields supplied by an applicant',async()=>{
    const application={identity:{fullName:'Applicant',dateOfBirth:'1990-01-01'},transportType:'walking',safety:{lawfulTransport:true,safeHandling:true,termsAccepted:true}};
    for(const forbidden of [{status:'approved'},{userId:fixtures.userId},{canDeliver:true},{reviewedBy:fixtures.userId}]){
      expect((await request('/deliverers/me/applications','POST',{...application,...forbidden})).status).toBe(400);
    }
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('scopes admin application alerts by owner and unread type before pagination',async()=>{
    fixtures.results.user_roles={data:[{role:'admin'}],error:null};
    expect((await request('/admin/verification-notifications?limit=10')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({table:'notifications',method:'eq',args:['user_id',fixtures.userId]});
    expect(fixtures.queries).toContainEqual({table:'notifications',method:'eq',args:['type','deliverer_application']});
    expect(fixtures.queries).toContainEqual({table:'notifications',method:'is',args:['read_at',null]});
  });
  it('protects address lookup and rejects invalid provider requests before external calls', async () => {
    expect((await request('/addresses/search?query=Ikeja', 'GET', undefined, null)).status).toBe(401);
    expect((await request('/addresses/search?query=x')).status).toBe(400);
    expect((await request('/addresses/search?query=Ikeja&extra=true')).status).toBe(400);
    expect((await request('/addresses/reverse', 'POST', { latitude: 91, longitude: 0 })).status).toBe(400);
    expect((await request('/addresses/search?query=Ikeja')).body.error.code).toBe('ADDRESS_PROVIDER_NOT_CONFIGURED');
  });
  it('validates ad contracts and passes caller identity to transactional mutations', async () => {
    expect((await request('/ads', 'POST', {}, null)).status).toBe(401);
    expect((await request('/ads', 'POST', {})).status).toBe(400);
    expect((await request('/ads')).status).toBe(400);
    expect((await request(`/ads/${fixtures.userId}`, 'PATCH', { status: 'active' })).status).toBe(400);
    expect((await request(`/ads/${fixtures.userId}`, 'PATCH', { status: 'published', deliverer_id: fixtures.userId })).status).toBe(400);
    fixtures.rpc.mockResolvedValue({ data: { id: fixtures.userId, status: 'paused' }, error: null });
    expect((await request(`/ads/${fixtures.userId}`, 'PATCH', { status: 'paused' })).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenCalledWith('change_delivery_ad_status', { p_actor: fixtures.userId, p_id: fixtures.userId, p_status: 'paused' });
    fixtures.rpc.mockResolvedValue({ data: null, error: { code: '42501' } });
    expect((await request(`/ads/${fixtures.userId}`, 'DELETE')).status).toBe(403);
  });
  it('scopes owned ads and strips replay metadata from selected fields', async () => {
    fixtures.results.p2p_ads = { data: [], error: null };
    expect((await request('/deliverers/me/ads?limit=10&offset=20')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({ table: 'p2p_ads', method: 'eq', args: ['deliverer_id', fixtures.userId] });
    expect(fixtures.queries).toContainEqual({ table: 'p2p_ads', method: 'range', args: [20, 29] });
    const fields = fixtures.queries.find(q => q.table === 'p2p_ads' && q.method === 'select')!.args[0];
    expect(fields).not.toMatch(/creation_key|creation_input|\*/);
    fixtures.results.p2p_ads = { data: null, error: null };
    expect((await request(`/ads/${fixtures.userId}`)).status).toBe(404);
  });
  it('requires idempotency for ad creation and never trusts caller-supplied transport', async () => {
    const input = { title: 'Ikeja delivery', pickupCoverage: { latitude: 6.6, longitude: 3.3, radiusMeters: 10000, label: 'Ikeja' },
      destinationCoverage: { latitude: 6.5, longitude: 3.4, radiusMeters: 10000, label: 'Yaba' }, priceMinor: 20000,
      availableFrom: new Date(Date.now() - 3600000).toISOString(), availableUntil: new Date(Date.now() + 86400000).toISOString(), notes: '' };
    expect((await request('/ads', 'POST', input)).status).toBe(400);
    expect((await request('/ads', 'POST', { ...input, transport: 'van' }, 'Bearer valid-token', 'ad-create-test-key-001')).status).toBe(400);
    expect((await request('/ads', 'POST', input, 'Bearer valid-token', 'ad-create-test-key-001')).status).toBe(201);
    expect(fixtures.rpc).toHaveBeenCalledWith('save_delivery_ad', { p_actor: fixtures.userId, p_id: null, p_input: input, p_key: 'ad-create-test-key-001' });
  });
  it('requires complete routes for ad matching instead of accepting client eligibility', async () => {
    fixtures.rpc.mockResolvedValue({ data: [], error: null });
    const query = 'pickupLatitude=6.6&pickupLongitude=3.3&destinationLatitude=6.5&destinationLongitude=3.4&weightKg=2';
    expect((await request(`/ads?${query}`)).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenCalledWith('browse_delivery_ads', { p_actor: fixtures.userId,
      p_input: { pickupLatitude: 6.6, pickupLongitude: 3.3, destinationLatitude: 6.5, destinationLongitude: 3.4, weightKg: 2, limit: 25, offset: 0 } });
    expect((await request(`/ads?${query}&eligible=true`)).status).toBe(400);
    expect((await request('/ads?pickupLatitude=&pickupLongitude=0&destinationLatitude=0&destinationLongitude=0&weightKg=2')).status).toBe(400);
  });
  it('protects archive-adapted order inspection from customers and finance-only staff', async () => {
    expect((await request('/admin/orders', 'GET', undefined, null)).status).toBe(401);
    expect((await request('/admin/orders')).status).toBe(403);
    fixtures.results.user_roles = { data: [{ role: 'finance' }], error: null };
    expect((await request(`/admin/orders/${fixtures.userId}`)).status).toBe(403);
    expect(fixtures.queries.some(query => query.table === 'orders')).toBe(false);
  });
  it('filters and paginates orders without accepting arbitrary PostgREST filters', async () => {
    fixtures.results.user_roles = { data: [{ role: 'operations' }], error: null };
    fixtures.results.orders = { data: [], error: null, count: 0 };
    expect((await request('/admin/orders?reference=MT-123&status=completed&serviceType=p2p&page=1')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({ table: 'orders', method: 'ilike', args: ['public_ref', '%MT-123%'] });
    expect(fixtures.queries).toContainEqual({ table: 'orders', method: 'eq', args: ['status', 'completed'] });
    expect(fixtures.queries).toContainEqual({ table: 'orders', method: 'range', args: [25, 49] });
    expect((await request('/admin/orders?reference=bad%2Cfilter')).status).toBe(400);
    expect((await request('/admin/orders?page=-1')).status).toBe(400);
    expect((await request('/admin/orders?status=made_up')).status).toBe(400);
  });
  it('limits order inspection to explicit fields and timeline metadata', async () => {
    fixtures.results.user_roles = { data: [{ role: 'admin' }], error: null };
    fixtures.results.orders = { data: { id: fixtures.userId, public_ref: 'MT-123' }, error: null };
    fixtures.results.order_events = { data: [], error: null };
    expect((await request(`/admin/orders/${fixtures.userId}`)).status).toBe(200);
    const columns = fixtures.queries.find(query => query.table === 'orders' && query.method === 'select')!.args[0];
    expect(columns).not.toBe('*');
    expect(columns).not.toMatch(/handover|code|photo_path|token/);
    expect(fixtures.queries).toContainEqual({ table: 'order_events', method: 'select', args: ['id,event_type,previous_status,new_status,created_at'] });
    fixtures.results.orders = { data: null, error: null };
    expect((await request(`/admin/orders/${fixtures.userId}`)).status).toBe(404);
    expect((await request('/admin/orders/not-a-uuid')).status).toBe(400);
  });
  it('records rejected access without copying credentials or request content',async()=>{
    expect((await request('/admin/users','POST',{password:'never-log-this',email:'private@example.test'})).status).toBe(403);
    await vi.waitFor(()=>expect(fixtures.queries.some(q=>q.table==='platform_activity'&&q.method==='insert')).toBe(true));
    const events=fixtures.queries.filter(q=>q.table==='platform_activity'&&q.method==='insert').map(q=>q.args[0]);
    expect(events).toContainEqual(expect.objectContaining({outcome:'rejected',category:'security',actor_id:fixtures.userId,source:'http',error_code:expect.any(String)}));
    expect(JSON.stringify(events)).not.toMatch(/never-log-this|private@example|valid-token/);
  });
  it('filters monitoring records on the server and validates references',async()=>{
    fixtures.results.user_roles={data:[{role:'super_admin'}],error:null};
    expect((await request('/admin/platform/activity?category=finance&outcome=failed&reference=MT-123&page=1')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({table:'platform_activity',method:'eq',args:['outcome','failed']});
    expect(fixtures.queries).toContainEqual({table:'platform_activity',method:'eq',args:['reference','MT-123']});
    expect(fixtures.queries).toContainEqual({table:'platform_activity',method:'range',args:[25,49]});
    expect((await request('/admin/platform/activity?reference=bad%2Cfilter')).status).toBe(400);
    expect((await request('/admin/platform/metrics')).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenCalledWith('activity_metrics');
  });
  it('restricts associated chat records to metadata columns',async()=>{
    fixtures.results.user_roles={data:[{role:'super_admin'}],error:null};
    fixtures.results.platform_activity={data:{entity:'messages',entity_id:fixtures.userId,order_id:null},error:null};
    fixtures.results.messages={data:{id:fixtures.userId,read_at:null},error:null};
    expect((await request(`/admin/platform/activity/${fixtures.userId}/record`)).status).toBe(200);
    const selection=fixtures.queries.find(q=>q.table==='messages'&&q.method==='select')!;
    expect(selection.args[0]).toBe('id,conversation_id,sender_id,delivered_at,read_at,created_at');
    expect(String(selection.args[0])).not.toMatch(/body|attachment|token/);
  });
  it('invites users through Auth and commits roles through the audited RPC',async()=>{
    fixtures.results.user_roles={data:[{role:'super_admin'}],error:null};
    const id='10000000-0000-4000-8000-000000000099';
    fixtures.invite.mockResolvedValue({data:{user:{id}},error:null});
    const result=await request('/admin/users','POST',{email:'new@example.test',name:'New Staff',roles:['admin'],reason:'Approved staff hire'});
    expect(result.status).toBe(201);
    expect(fixtures.invite).toHaveBeenCalledWith('new@example.test',expect.objectContaining({data:{full_name:'New Staff'}}));
    expect(fixtures.rpc).toHaveBeenCalledWith('manage_platform_user',expect.objectContaining({p_actor:fixtures.userId,p_target:id,p_action:'user_created'}));
    fixtures.rpc.mockResolvedValue({data:null,error:{code:'42501'}});
    fixtures.ban.mockResolvedValue({data:{user:{id}},error:null});
    const failure=await request('/admin/users','POST',{email:'other@example.test',name:'Other Staff',roles:['admin'],reason:'Approved staff hire'});
    expect(failure.status).toBe(503);
    expect(fixtures.ban).toHaveBeenCalledWith(id,{ban_duration:'876000h'});
  });
  it('paginates directory and applies server-side filters',async()=>{
    fixtures.results.user_roles={data:[{role:'super_admin'}],error:null};
    fixtures.results.admin_user_directory={data:[],error:null,count:0};
    expect((await request('/admin/users?page=2&role=admin&status=suspended&staff=true&q=owner')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({table:'admin_user_directory',method:'range',args:[50,74]});
    expect(fixtures.queries).toContainEqual({table:'admin_user_directory',method:'contains',args:['roles',['admin']]});
    expect((await request('/admin/users?page=-1')).status).toBe(400);
  });
  it.each(['sender','deliverer','admin','finance','support','operations','verification_agent'])('denies platform management to %s', async(role) => {
    fixtures.results.user_roles = {data:[{role}],error:null};
    for (const [path,method,body] of [
      ['/admin/users','GET',undefined], ['/admin/users','POST',{}],
      [`/admin/users/${fixtures.userId}`,'PATCH',{}], [`/admin/users/${fixtures.userId}`,'DELETE',{}],
      ['/admin/platform/activity','GET',undefined], ['/admin/platform/audit','GET',undefined],
      ['/admin/platform/metrics','GET',undefined], ['/admin/platform/stream','GET',undefined],
    ] as const) expect((await request(path,method,body)).status).toBe(403);
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('takes administrative actor from auth and validates changes', async()=>{
    fixtures.results.user_roles={data:[{role:'super_admin'}],error:null};
    const target='10000000-0000-4000-8000-000000000099';
    expect((await request(`/admin/users/${target}`,'PATCH',{roles:['admin'],reason:'Approved by owner'})).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenCalledWith('manage_platform_user',{
      p_actor:fixtures.userId,p_target:target,p_input:{roles:['admin'],reason:'Approved by owner'},p_action:'user_updated',
    });
    expect((await request(`/admin/users/${target}`,'PATCH',{roles:['super_admin'],reason:'Approved by owner',actor:target})).status).toBe(400);
    expect((await request(`/admin/users/${target}`,'DELETE',{reason:'Delete account'})).status).toBe(400);
    expect((await request(`/admin/users/${target}`,'DELETE',{reason:'Deactivate account',confirmation:'DEACTIVATE'})).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenLastCalledWith('manage_platform_user',expect.objectContaining({p_input:{status:'deactivated',reason:'Deactivate account'}}));
  });
  it('rejects suspended bearer tokens before accessing platform data',async()=>{
    fixtures.results.user_roles={data:[{role:'super_admin'}],error:null};
    fixtures.results.security_settings={data:{deleted_at:null,suspended_at:'2026-01-01'},error:null};
    expect((await request('/admin/users')).status).toBe(403);
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('preserves dual-role capabilities and separate verification states', async () => {
    fixtures.results.user_roles = { data: [{ role: 'sender' }, { role: 'deliverer' }], error: null };
    fixtures.results.deliverer_profiles = { data: { verification_status: 'suspended' }, error: null };
    const response = await request('/users/me');
    expect(response.body.data.user.roles).toEqual(['sender', 'deliverer']);
    expect(response.body.data.user.verificationStatus).toBe('not_started');
    expect(response.body.data.user.delivererVerificationStatus).toBe('suspended');
  });
  it('marks default addresses with the authenticated account and no client-owned fields', async () => {
    const id = '10000000-0000-4000-8000-000000000099';
    expect((await request(`/users/me/addresses/${id}/default`, 'POST')).status).toBe(200);
    expect(fixtures.rpc).toHaveBeenCalledWith('set_default_account_address', {
      p_user_id: fixtures.userId, p_address_id: id,
    });
    fixtures.rpc.mockClear();
    expect((await request(`/users/me/addresses/${id}/default`, 'POST', { user_id: 'other' })).status).toBe(400);
    expect(fixtures.rpc).not.toHaveBeenCalled();
    expect((await request(`/users/me/addresses/${id}/default`, 'POST', undefined, null)).status).toBe(401);
  });
  it('returns not found when the default address is missing or belongs to another account', async () => {
    fixtures.rpc.mockResolvedValue({ data: null, error: { code: 'P0002' } });
    expect((await request('/users/me/addresses/10000000-0000-4000-8000-000000000099/default', 'POST')).status).toBe(404);
  });
  it('denies scoped admin endpoints to sender accounts', async () => {
    expect((await request('/admin/pricing-rules')).status).toBe(403);
    expect((await request('/admin/verification-applications')).status).toBe(403);
    expect((await request('/admin/support/cases')).status).toBe(403);
    expect((await request('/admin/orders/10000000-0000-4000-8000-000000000099/dispute-settlement', 'POST', {})).status).toBe(403);
    expect(fixtures.rpc).not.toHaveBeenCalled();
  });
  it('keeps verification and finance staff permissions separate', async () => {
    fixtures.results.user_roles = { data: [{ role: 'finance' }], error: null };
    fixtures.results.pricing_rules = { data: [], error: null };
    expect((await request('/admin/pricing-rules')).status).toBe(200);
    expect((await request('/admin/verification-applications')).status).toBe(403);
    fixtures.results.user_roles = { data: [{ role: 'verification_agent' }], error: null };
    expect((await request('/admin/pricing-rules')).status).toBe(403);
  });
  it('rejects absent and malformed bearer headers before contacting Supabase', async () => {
    expect((await request('/users/me', 'GET', undefined, null)).status).toBe(401);
    expect((await request('/users/me', 'GET', undefined, 'valid-token')).status).toBe(401);
    expect(fixtures.getUser).not.toHaveBeenCalled();
  });
  it('validates tokens with Supabase instead of trusting their contents', async () => {
    fixtures.getUser.mockResolvedValue({ data: { user: null }, error: { status: 401 } });
    expect((await request('/users/me')).status).toBe(401);
    expect(fixtures.getUser).toHaveBeenCalledWith('valid-token');
  });
  it('handles rejected auth promises through the Express error handler', async () => {
    fixtures.getUser.mockRejectedValue(new Error('Network failed'));
    const response = await request('/users/me');
    expect(response.status).toBe(500);
    expect(response.body.error.code).toBe('INTERNAL_SERVER_ERROR');
  });
  it('fails closed when account status cannot be loaded', async () => {
    fixtures.results.security_settings = { data: null, error: null };
    expect((await request('/users/me')).status).toBe(503);
  });
  it('rejects disabled accounts even with a valid access token', async () => {
    fixtures.results.security_settings.data.deleted_at = new Date().toISOString();
    expect((await request('/users/me')).status).toBe(403);
  });
  it('reads only the authenticated account and returns money in minor units', async () => {
    const response = await request('/users/me');
    expect(response.status).toBe(200);
    expect(response.body.data.user.wallet).toEqual({ currency: 'NGN', balanceMinor: 12050 });
    expect(response.body.data.user.verified).toBe(false);
    for (const query of fixtures.queries.filter((query) => query.method === 'eq')) {
      expect(query.args[1]).toBe(fixtures.userId);
    }
  });
  it('does not let profile updates inject verification, roles or balance', async () => {
    const response = await request('/users/me', 'PATCH', { name: 'Sender', verified: true, walletBalance: 1000000 });
    expect(response.status).toBe(400);
    expect(fixtures.queries.some((query) => query.method === 'update')).toBe(false);
  });
  it('requires a granted deliverer role before switching modes', async () => {
    const response = await request('/users/me', 'PATCH', { activeRole: 'deliverer' });
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe('ROLE_NOT_GRANTED');
  });
  it('forces address ownership from the session, never from the request', async () => {
    const address = { label: 'Home', address: 'Ikeja Lagos', latitude: 6.6, longitude: 3.3, isDefault: true };
    expect((await request('/users/me/addresses', 'POST', { ...address, userId: 'other-user' })).status).toBe(400);
    expect((await request('/users/me/addresses', 'POST', address)).status).toBe(201);
    expect(fixtures.rpc).toHaveBeenCalledWith('save_account_address', expect.objectContaining({ p_user_id: fixtures.userId, p_address_id: null }));
  });
  it('does not allow blocking oneself', async () => {
    const response = await request('/users/me/blocked-users', 'POST', { blockedId: fixtures.userId });
    expect(response.status).toBe(400);
    expect(response.body.error.code).toBe('CANNOT_BLOCK_SELF');
  });
  it('bounds pagination before querying notifications', async () => {
    expect((await request('/notifications?limit=101')).status).toBe(400);
    expect((await request('/notifications?limit=10&offset=20')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'range', args: [20, 29] });
  });
  it('counts only unread notifications owned by the session', async () => {
    fixtures.results.notifications = { data: null, error: null, count: 3 };
    const response = await request('/notifications/unread-count');
    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({ unreadCount: 3 });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'select', args: ['id', { count: 'exact', head: true }] });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'eq', args: ['user_id', fixtures.userId] });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'is', args: ['read_at', null] });
  });
  it('marks only owned unread notifications and returns the affected count', async () => {
    fixtures.results.notifications = { data: null, error: null, count: 2 };
    const response = await request('/notifications/read-all', 'POST');
    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({ updatedCount: 2 });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'eq', args: ['user_id', fixtures.userId] });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'is', args: ['read_at', null] });
  });
  it('scopes deletion to both account and notification ID', async () => {
    const id = '10000000-0000-4000-8000-000000000099';
    fixtures.results.notifications = { data: { id }, error: null };
    expect((await request(`/notifications/${id}`, 'DELETE')).status).toBe(200);
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'eq', args: ['user_id', fixtures.userId] });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'eq', args: ['id', id] });
    fixtures.results.notifications.data = null;
    const missing = await request(`/notifications/${id}`, 'DELETE');
    expect(missing.status).toBe(404);
    expect(missing.body.error.code).toBe('NOTIFICATION_NOT_FOUND');
  });
  it('rejects invalid notification IDs before deletion', async () => {
    expect((await request('/notifications/not-a-uuid', 'DELETE')).status).toBe(400);
    expect(fixtures.queries.some((query) => query.method === 'delete')).toBe(false);
  });
  it('clears only the current account inbox and reports database failures', async () => {
    fixtures.results.notifications = { data: null, error: null, count: 4 };
    const response = await request('/notifications', 'DELETE');
    expect(response.status).toBe(200);
    expect(response.body.data).toEqual({ deletedCount: 4 });
    expect(fixtures.queries).toContainEqual({ table: 'notifications', method: 'eq', args: ['user_id', fixtures.userId] });
    fixtures.results.notifications = { data: null, error: { code: '08006' } };
    expect((await request('/notifications', 'DELETE')).status).toBe(503);
    expect((await request('/notifications/unread-count')).status).toBe(503);
    expect((await request('/notifications/read-all', 'POST')).status).toBe(503);
  });
  it('requires authentication for every inbox operation', async () => {
    for (const [path, method] of [['/notifications/unread-count', 'GET'], ['/notifications/read-all', 'POST'], ['/notifications', 'DELETE'], ['/notifications/10000000-0000-4000-8000-000000000099', 'DELETE']]) {
      expect((await request(path, method, undefined, null)).status).toBe(401);
    }
    expect(fixtures.queries.filter(query=>query.table!=='platform_activity')).toHaveLength(0);
  });
  it('does not expose the prototype ledger preview as a production operation', async () => {
    expect((await request('/wallet/preview-ledger-entry', 'POST', {})).status).toBe(404);
  });
  it('returns a consistent error for malformed JSON', async () => {
    const response = await fetch(`${baseUrl}/api/v1/auth/signin`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{',
    });
    expect(response.status).toBe(400);
    expect((await response.json()).error.code).toBe('INVALID_JSON');
  });
});

describe('Supabase auth lifecycle', () => {
  it('keeps signup unauthed until confirmation when no session is issued', async () => {
    fixtures.auth.signUp.mockResolvedValue({ data: { user: null, session: null }, error: null });
    const response = await request('/auth/signup', 'POST', { name: 'Sender', email: 'sender@example.test', password: 'a-long-password' }, null);
    expect(response.status).toBe(201);
    expect(response.body.data).toEqual({ requiresEmailConfirmation: true });
  });
  it('returns rotated refresh credentials from Supabase', async () => {
    fixtures.auth.refreshSession.mockResolvedValue({ data: {
      user: { id: fixtures.userId, email: 'sender@example.test' },
      session: { access_token: 'new-access', refresh_token: 'new-refresh', expires_at: 1234, token_type: 'bearer' },
    }, error: null });
    const response = await request('/auth/refresh', 'POST', { refreshToken: 'old-refresh' }, null);
    expect(response.status).toBe(200);
    expect(response.body.data.session.refreshToken).toBe('new-refresh');
    expect(fixtures.auth.refreshSession).toHaveBeenCalledWith({ refresh_token: 'old-refresh' });
  });
  it('returns identical recovery responses for known and unknown accounts', async () => {
    fixtures.auth.resetPasswordForEmail.mockResolvedValueOnce({ error: null }).mockResolvedValueOnce({ error: { status: 400 } });
    const known = await request('/auth/recover', 'POST', { email: 'sender@example.test' }, null);
    const unknown = await request('/auth/recover', 'POST', { email: 'unknown@example.test' }, null);
    expect(known).toEqual(unknown);
    expect(known.status).toBe(200);
  });
  it('never permits identifier-only password replacement', async () => {
    expect((await request('/auth/password', 'POST', { password: 'a-long-password' }, null)).status).toBe(401);
    expect((await request('/auth/reset-password', 'POST', { emailOrPhone: 'sender@example.test', newPassword: 'a-long-password' }, null)).status).toBe(404);
  });
});
