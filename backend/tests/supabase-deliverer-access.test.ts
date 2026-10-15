import { beforeEach,describe,it,expect,vi } from 'vitest';
const result=vi.hoisted(()=>({status:'not_started',error:null as unknown}));
vi.mock('../src/config/supabase.js',()=>({supabaseAdmin:{from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:{verification_status:result.status},error:result.error})})})})}}));
import { assertApprovedDeliverer } from '../src/services/deliverer-access.js';
beforeEach(()=>{result.status='not_started';result.error=null;});
describe('Supabase deliverer capability checks',()=>{
  it.each(['not_started','submitted','under_review','rejected','suspended'])('denies a granted role with %s verification',async status=>{
    result.status=status;await expect(assertApprovedDeliverer({id:'fixture',roles:['sender','deliverer']})).rejects.toMatchObject({status:403});
  });
  it('requires both the role and current approval',async()=>{
    result.status='approved';await expect(assertApprovedDeliverer({id:'fixture',roles:['sender']})).rejects.toMatchObject({status:403});
    await expect(assertApprovedDeliverer({id:'fixture',roles:['sender','deliverer']})).resolves.toBeUndefined();
  });
  it('does not accept cached approvals during database outages',async()=>{
    result.status='approved';result.error={code:'OFFLINE'};await expect(assertApprovedDeliverer({id:'fixture',roles:['deliverer']})).rejects.toMatchObject({status:503});
  });
});
