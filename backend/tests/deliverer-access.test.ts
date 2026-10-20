import { createRequire } from 'node:module';
import { describe,it,expect,vi } from 'vitest';
const {DelivererAccess,mergeVerificationNotifications}=createRequire(import.meta.url)('../../server/src/deliverer-access.js');
const account=()=>({uid:'user_fixture',email:'sender@example.test',verified:true,activeRole:'deliverer',delivererOnline:true});
const authority=(state:unknown)=>new DelivererAccess({origin:'https://authority.example.test',secret:'private-test-service-token',request:vi.fn(async()=>new Response(JSON.stringify({success:true,data:state}))) });
describe('legacy deliverer approval enforcement',()=>{
  it('retries transient approval reads and never retries application mutations',async()=>{
    const request=vi.fn().mockRejectedValueOnce(new Error('Connection reset')).mockResolvedValueOnce(new Response(JSON.stringify({success:true,data:{status:'approved',canDeliver:true}})));
    const access=new DelivererAccess({origin:'https://authority.example.test',secret:'fixture',request});
    await expect(access.requireApproved(account())).resolves.toMatchObject({status:'approved'});
    expect(request).toHaveBeenCalledTimes(2);
    const mutate=vi.fn().mockRejectedValue(new Error('Connection reset'));
    await expect(new DelivererAccess({origin:'https://authority.example.test',secret:'fixture',request:mutate}).command(account(),'submit',{})).rejects.toMatchObject({status:503});
    expect(mutate).toHaveBeenCalledTimes(1);
  });
  it('does not retry permission denials or convert outages into approval',async()=>{
    const request=vi.fn(async()=>new Response(JSON.stringify({success:false,error:{message:'Forbidden'}}),{status:403}));
    await expect(new DelivererAccess({origin:'https://authority.example.test',secret:'fixture',request}).requireApproved(account())).rejects.toMatchObject({status:403});
    expect(request).toHaveBeenCalledTimes(1);
    const offline=vi.fn().mockRejectedValue(new Error('Offline'));
    await expect(new DelivererAccess({origin:'https://authority.example.test',secret:'fixture',request:offline}).requireApproved(account())).rejects.toMatchObject({status:503});
    expect(offline).toHaveBeenCalledTimes(2);
  });
  it('imports review notifications once and preserves read state across polls',()=>{
    const event={id:'18000000-0000-4000-8000-000000000001',type:'verification_update',title:'Application rejected',body:'Please upload a clear identity document',created_at:'2026-10-20T10:00:00Z',read_at:null};
    const first=mergeVerificationNotifications([],{notifications:[event]});
    expect(first).toHaveLength(1);expect(first[0].id).toBe(`verification:${event.id}`);
    first[0].read=true;
    const next=mergeVerificationNotifications(first,{notifications:[event]});
    expect(next).toHaveLength(1);expect(next[0].read).toBe(true);
    expect(mergeVerificationNotifications([],{notifications:[{...event,type:'untrusted'}]})).toEqual([]);
  });
  it.each(['not_started','pending_approval','submitted','under_review','rejected','suspended'])('denies %s even with a local verified flag',async status=>{
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
