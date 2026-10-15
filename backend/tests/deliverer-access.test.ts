import { createRequire } from 'node:module';
import { describe,it,expect,vi } from 'vitest';
const {DelivererAccess}=createRequire(import.meta.url)('../../server/src/deliverer-access.js');
const account=()=>({uid:'user_fixture',email:'sender@example.test',verified:true,activeRole:'deliverer',delivererOnline:true});
const authority=(state:unknown)=>new DelivererAccess({origin:'https://authority.example.test',secret:'private-test-service-token',request:vi.fn(async()=>new Response(JSON.stringify({success:true,data:state}))) });
describe('legacy deliverer approval enforcement',()=>{
  it.each(['not_started','submitted','under_review','rejected','suspended'])('denies %s even with a local verified flag',async status=>{
    const access=authority({status,canDeliver:false});await expect(access.requireApproved(account())).rejects.toMatchObject({status:403});
    expect(await access.profile(account())).toMatchObject({canDeliver:false,activeRole:'sender',delivererOnline:false});
  });
  it('permits only explicit current approval and rechecks suspension',async()=>{
    const access=authority({status:'approved',canDeliver:true});await expect(access.requireApproved(account())).resolves.toMatchObject({status:'approved'});
    const suspended=authority({status:'suspended',canDeliver:false});await expect(suspended.requireApproved(account())).rejects.toMatchObject({status:403});
    await expect(authority({status:'approved',canDeliver:false}).requireApproved(account())).rejects.toMatchObject({status:403});
  });
  it('fails closed during authority outages while preserving sender access',async()=>{
    const access=new DelivererAccess({origin:'https://authority.example.test',secret:'fixture',request:async()=>{throw new Error('Offline');}});
    await expect(access.requireApproved(account())).rejects.toMatchObject({status:503});
    expect(await access.profile(account())).toMatchObject({activeRole:'sender',canDeliver:false,delivererVerificationStatus:'unavailable'});
  });
  it('binds application ownership and email to the authenticated legacy account',async()=>{
    const request=vi.fn(async(_url:URL,_options:RequestInit)=>new Response(JSON.stringify({success:true,data:{status:'not_started'}})));
    const access=new DelivererAccess({origin:'https://authority.example.test',secret:'fixture',request});
    await access.command(account(),'start',{userId:'victim',accountEmail:'attacker@example.test'});
    const options=request.mock.calls[0][1] as RequestInit;const body=JSON.parse(options.body as string);
    expect(body.userId).toBe('user_fixture');expect(body.input.accountEmail).toBe('sender@example.test');
  });
});
