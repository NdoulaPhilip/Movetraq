import { EventEmitter } from 'node:events';
import { afterEach,describe,expect,it,vi } from 'vitest';
const fixture=vi.hoisted(()=>({identity:vi.fn(),from:vi.fn(),channel:vi.fn(),removeChannel:vi.fn()}));
vi.mock('../src/config/supabase.js',()=>({supabaseAdmin:{auth:{getUser:fixture.identity},from:fixture.from,channel:fixture.channel,removeChannel:fixture.removeChannel}}));
import { activityStream,streamAuthorized } from '../src/realtime/activity-stream.js';
afterEach(()=>{vi.useRealTimers();vi.clearAllMocks();});
describe('authorized activity streaming',()=>{
  it('fails closed on identity, suspension, or missing Super Admin role',async()=>{
    fixture.identity.mockResolvedValue({data:{user:{id:'actor'}},error:null});
    let suspended:string|null=null;let role='super_admin';
    fixture.from.mockImplementation((table:string)=>{
      const result={data:table==='security_settings'?{deleted_at:null,suspended_at:suspended}:[{role}],error:null};
      const builder:any={select:()=>builder,eq:()=>builder,maybeSingle:async()=>result,then:(resolve:any)=>Promise.resolve(result).then(resolve)};return builder;
    });
    expect(await streamAuthorized('actor','token')).toBe(true);
    suspended='2026-01-01';expect(await streamAuthorized('actor','token')).toBe(false);
    suspended=null;role='admin';expect(await streamAuthorized('actor','token')).toBe(false);
    role='super_admin';fixture.identity.mockResolvedValue({data:{user:{id:'other'}},error:null});
    expect(await streamAuthorized('actor','token')).toBe(false);
  });
  it('forwards only refresh hints and removes its subscription on disconnect',async()=>{
    vi.useFakeTimers();const listeners:((payload:unknown)=>void)[]=[];
    const channel:any={on:vi.fn((_event,_options,callback)=>{listeners.push(callback);return channel;}),subscribe:vi.fn(callback=>{callback('SUBSCRIBED');return channel;})};
    fixture.channel.mockReturnValue(channel);fixture.removeChannel.mockResolvedValue('ok');
    const response:any=new EventEmitter();response.headersSent=false;
    response.status=()=>response;response.set=()=>response;response.flushHeaders=()=>{response.headersSent=true;};response.write=vi.fn(()=>true);response.end=vi.fn();
    const next=vi.fn();activityStream({user:{id:'stream-test'},accessToken:'private-token'} as any,response,next);
    await Promise.resolve();expect(next).not.toHaveBeenCalled();
    listeners[0]({new:{body:'private-message',token:'private-token'}});
    expect(response.write).toHaveBeenCalledWith('event: invalidate\ndata: {}\n\n');
    expect(JSON.stringify(response.write.mock.calls)).not.toMatch(/private/);
    response.emit('close');expect(fixture.removeChannel).toHaveBeenCalledWith(channel);
    expect(vi.getTimerCount()).toBe(0);
  });
});
