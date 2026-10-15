import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { PGlite } from '@electric-sql/pglite';
import { beforeAll,afterAll,describe,it,expect } from 'vitest';
const {authorized,beginAttempt,finishAttempt,monitoringData,reconcilePending}=createRequire(import.meta.url)('../../server/src/monitoring.js');
let db:PGlite;
beforeAll(async()=>{
  db=new PGlite();
  await db.exec(`create table users(uid text primary key,data jsonb not null,updated_at timestamptz default now());
    create table orders(id text primary key,data jsonb);create table order_messages(order_id text primary key,data jsonb);
    ${['wallet_transactions','notifications','saved_addresses','security_settings','support_tickets'].map(t=>`create table ${t}(user_id text primary key,data jsonb,updated_at timestamptz default now());`).join('')}
    insert into users values('user-one','{"uid":"user-one","name":"Sender","walletBalance":0,"email":"private@example.test"}',now());
    insert into notifications(user_id,data) values('user-one','[{"id":"n1","read":false,"body":"private"}]');`);
  for(const file of ['0001_paystack_wallet.sql','0002_mobile_monitoring.sql'])await db.exec(readFileSync(new URL('../../server/migrations/'+file,import.meta.url),'utf8'));
},60000);
afterAll(async()=>db?.close());
describe('mobile source monitoring',()=>{
  it('requires a strong service credential',()=>{
    expect(authorized(undefined,'a'.repeat(48))).toBe(false);expect(authorized('Bearer short','short')).toBe(false);
    expect(authorized('Bearer '+'a'.repeat(48),'a'.repeat(48))).toBe(true);expect(authorized('Bearer '+'b'.repeat(48),'a'.repeat(48))).toBe(false);
  });
  it('backfills actual records without exposing emails, message content or secrets',async()=>{
    const feed=await monitoringData(db,new URLSearchParams({view:'users'}));expect(feed.total).toBe(1);
    expect(feed.rows[0].record).toEqual({uid:'user-one',name:'Sender'});
    const notifications=await monitoringData(db,new URLSearchParams({view:'notifications'}));expect(notifications.total).toBe(1);expect(JSON.stringify(notifications)).not.toContain('private');
  });
  it('does not duplicate events when whole-store snapshots are unchanged',async()=>{
    const before=(await db.query<{count:number}>('select count(*)::int count from mobile_activity')).rows[0].count;
    await db.exec('update users set data=data,updated_at=now()');
    expect((await db.query<{count:number}>('select count(*)::int count from mobile_activity')).rows[0].count).toBe(before);
  });
  it('captures order/escrow transitions and notification removal atomically',async()=>{
    await db.exec(`insert into orders values('order-one','{"id":"order-one","senderId":"user-one","code":"MT-1","status":"accepted","escrowHeld":true}');
      update orders set data=data||'{"status":"delivered","escrowReleased":true}' where id='order-one';
      update notifications set data='[]' where user_id='user-one';`);
    const events=await monitoringData(db,new URLSearchParams({view:'activity',q:'order-one'}));expect(events.total).toBe(2);
    expect(events.rows[0]).toMatchObject({previous_status:'accepted',new_status:'delivered',order_id:'order-one'});
    const removed=await monitoringData(db,new URLSearchParams({view:'notifications'}));expect(removed.rows[0].record.deleted).toBe(true);
  });
  it('persists pending and failed attempts with no raw credentials or body',async()=>{
    const id=await beginAttempt(db,{method:'POST',url:'/orders/order_123_ab/stage?token=secret'},'user-one');
    let feed=await monitoringData(db,new URLSearchParams({view:'attempts'}));expect(feed.rows[0].outcome).toBe('pending');
    await finishAttempt(db,id,403);feed=await monitoringData(db,new URLSearchParams({view:'attempts'}));
    expect(feed.rows[0]).toMatchObject({outcome:'rejected',error_code:'HTTP_403',route:'/orders/:id/stage'});expect(JSON.stringify(feed)).not.toContain('secret');
  });
  it('rejects SQL/filter injection and leaves audit events immutable',async()=>{
    await expect(monitoringData(db,new URLSearchParams({view:'users;drop table users'}))).rejects.toThrow();
    await expect(monitoringData(db,new URLSearchParams({page:'-1'}))).rejects.toThrow();
    await expect(db.exec('delete from mobile_activity')).rejects.toThrow('immutable');
  });
  it('checks stale pending provider payments without fabricating a success',async()=>{
    await db.exec(`insert into legacy_wallet_topups(reference,user_id,request_key,amount_minor,checkout_url,created_at)
      values('stale-fixture','user-one','stale-key',10000,'https://checkout.paystack.com/fixture',now()-interval '10 minutes')`);
    const checked:string[]=[];
    await reconcilePending(db,{verify:async(reference:string)=>{checked.push(reference);throw new Error('Provider unavailable');}});
    expect(checked).toEqual(['stale-fixture']);
    const attempt=await db.query<{outcome:string}>("select outcome from mobile_request_attempts where reference='stale-fixture'");expect(attempt.rows[0].outcome).toBe('failed');
    expect((await db.query<{status:string}>("select status from legacy_wallet_topups where reference='stale-fixture'")).rows[0].status).toBe('created');
  });
});
