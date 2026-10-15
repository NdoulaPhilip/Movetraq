import { afterEach,describe,it,expect,vi } from 'vitest';
const settings=vi.hoisted(()=>({MOBILE_MONITORING_URL:'https://mobile.example.test',MONITORING_SERVICE_TOKEN:'test-only-service-token-not-for-production'}));
vi.mock('../src/config/env.js',()=>({env:settings}));
vi.mock('../src/config/supabase.js',()=>({supabaseAdmin:{}}));
import { mobileMonitoring } from '../src/services/mobile-monitoring-service.js';
import { requireAdminRole } from '../src/middleware/auth.js';
afterEach(()=>vi.unstubAllGlobals());
describe('admin mobile monitoring bridge',()=>{
  it('uses a fixed server URL and private credential, not browser query destinations',async()=>{
    const fetcher=vi.fn(async()=>new Response(JSON.stringify({source:'mobile_postgres',rows:[],total:0})));
    vi.stubGlobal('fetch',fetcher);
    expect(await mobileMonitoring('staff-id',{view:'payments',q:'mt-ref'})).toMatchObject({source:'mobile_postgres'});
    const [url,options]=fetcher.mock.calls[0] as unknown as [URL,RequestInit];
    expect(url.href).toBe('https://mobile.example.test/internal/monitoring?view=payments&q=mt-ref');
    expect(options.redirect).toBe('error');expect(options.headers).toMatchObject({'X-Monitoring-Staff':'staff-id'});
  });
  it('fails visibly instead of replacing unreachable mobile results with an empty array',async()=>{
    vi.stubGlobal('fetch',vi.fn(async()=>new Response('private credentials',{status:503})));
    await expect(mobileMonitoring('staff-id',{})).rejects.toMatchObject({code:'MOBILE_MONITORING_UNAVAILABLE',status:503});
  });
  it('does not allow ordinary senders or other staff to read platform-wide mobile records',()=>{
    const next=vi.fn();requireAdminRole('super_admin')({user:{roles:['sender']}} as never,{} as never,next);
    expect(next.mock.calls[0][0]).toMatchObject({status:403});
    next.mockClear();requireAdminRole('super_admin')({user:{roles:['super_admin']}} as never,{} as never,next);expect(next).toHaveBeenCalledWith();
  });
});
