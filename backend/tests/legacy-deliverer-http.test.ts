import { spawn,type ChildProcess } from 'node:child_process';
import { createServer } from 'node:net';
import { fileURLToPath } from 'node:url';
import { beforeAll,afterAll,describe,it,expect } from 'vitest';
let child:ChildProcess;let base:string;let sender:string;let applicant:string;let orderId:string;
async function request(path:string,method='GET',body?:unknown,token?:string){
  const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(10000)});
  return {status:response.status,body:await response.json()};
}
beforeAll(async()=>{
  const socket=createServer();await new Promise<void>(resolve=>socket.listen(0,'127.0.0.1',resolve));
  const port=(socket.address() as {port:number}).port;await new Promise<void>(resolve=>socket.close(()=>resolve()));base=`http://127.0.0.1:${port}`;
  // Isolated in-memory test server; this fixture never contacts hosted services.
  const source=`let status='submitted';process.on('message',message=>{status=message.status;process.send({status});});global.fetch=async(url,options)=>{
    const command=JSON.parse(options.body).command;
    const data=String(url).includes('/internal/mobile-maps')
      ? command==='route'?{distanceMeters:1000,durationSeconds:120,points:[{latitude:6,longitude:3},{latitude:6.1,longitude:3.1}]}:{saved:true}
      : {status,canDeliver:status==='approved'};
    return new Response(JSON.stringify({success:true,data}));
  };require('./server/src/server.js');`;
  child=spawn(process.execPath,['-e',source],{cwd:fileURLToPath(new URL('../../',import.meta.url)),env:{...process.env,NODE_ENV:'test',PORT:String(port),DATABASE_URL:'',POSTGRES_URL:'',JWT_SECRET:'isolated-test-jwt-not-production',MONITORING_SERVICE_TOKEN:'isolated-private-service-test-token',DELIVERER_AUTHORITY_URL:'https://authority.example.test'},stdio:['ignore','pipe','pipe','ipc']});
  await new Promise<void>((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('Isolated server startup timed out')),15000);child.once('exit',()=>{clearTimeout(timeout);reject(new Error('Isolated server stopped'));});child.stdout!.on('data',data=>{if(String(data).includes('API listening')){clearTimeout(timeout);resolve();}});});
  const register=async(email:string)=>request('/auth/signup','POST',{name:'Fixture sender',email,phone:'',password:'fixture-password-only'});
  sender=(await register('sender-one@example.test')).body.token;applicant=(await register('applicant@example.test')).body.token;
  const order=await request('/orders','POST',{pickupAddress:'Fixture pickup',dropoffAddress:'Fixture destination',pickupLocation:{latitude:6,longitude:3},dropoffLocation:{latitude:6.1,longitude:3.1},price:0,isP2P:false},sender);
  expect(order.status).toBe(201);orderId=order.body.order.id;
},30000);
afterAll(()=>child?.kill());
describe('legacy delivery API approval boundary',()=>{
  it('retains sender order access but hides available jobs from pending applicants',async()=>{
    const own=await request('/orders','GET',undefined,sender);expect(own.body.orders).toHaveLength(1);
    const hidden=await request('/orders','GET',undefined,applicant);expect(hidden.body.orders).toEqual([]);
    expect((await request(`/orders/${orderId}`,'GET',undefined,applicant)).status).toBe(403);
  });
  it('rejects direct role escalation and availability changes',async()=>{
    expect((await request('/users/me','PATCH',{activeRole:'deliverer'},applicant)).status).toBe(403);
    expect((await request('/users/me','PATCH',{delivererOnline:true},applicant)).status).toBe(403);
    const profile=await request('/auth/me','GET',undefined,applicant);expect(profile.body.user).toMatchObject({activeRole:'sender',canDeliver:false,delivererVerificationStatus:'submitted'});
  });
  it('rejects job acceptance, pickup progress and location calls without approval',async()=>{
    for(const action of ['accept','stage','location'])expect((await request(`/orders/${orderId}/${action}`,'POST',{stage:1,latitude:6,longitude:3},applicant)).status).toBe(403);
    const unchanged=await request(`/orders/${orderId}`,'GET',undefined,sender);expect(unchanged.body.order.status).toBe('pendingOffer');
  });
  it('prevents client-side preassignment from bypassing acceptance approval',async()=>{
    expect((await request('/orders','POST',{price:0,autoAccept:true,delivererId:'user_not_approved'},sender)).status).toBe(403);
  });
  it('updates the same account immediately after official approval and revokes on suspension',async()=>{
    const authority=async(status:string)=>new Promise<void>(resolve=>{child.once('message',()=>resolve());child.send!({status});});
    await authority('approved');
    const switched=await request('/users/me','PATCH',{activeRole:'deliverer'},applicant);
    expect(switched.status).toBe(200);expect(switched.body.user).toMatchObject({activeRole:'deliverer',canDeliver:true,verified:true,delivererVerificationStatus:'approved'});
    await authority('suspended');
    const revoked=await request('/deliverer-access','GET',undefined,applicant);
    expect(revoked.body.user).toMatchObject({activeRole:'sender',canDeliver:false,delivererOnline:false});
    expect((await request(`/orders/${orderId}/accept`,'POST',{},applicant)).status).toBe(403);
  });
});
