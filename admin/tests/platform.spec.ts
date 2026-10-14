import { test,expect } from '@playwright/test';

test('Super Admin manages accounts and inspects activity without layout overflow',async({page},info)=>{
  const target={id:'10000000-0000-4000-8000-000000000099',full_name:'Delivery Customer',email:'customer@example.test',phone:null,
    roles:['sender'],account_status:'active',created_at:'2026-10-01T10:00:00Z',recent_activity:'2026-10-12T10:00:00Z',verification_status:'approved'};
  const mutations:{method:string;body:unknown}[]=[];
  await page.route('**/api/v1/**',async route=>{
    const path=new URL(route.request().url()).pathname;
    const method=route.request().method();let data:unknown={};
    if(path.endsWith('/auth/signin'))data={user:{uid:'super-1',name:'Super Admin',email:'owner@example.test',roles:['super_admin']},session:{accessToken:'test-only',refreshToken:'test-only-refresh',expiresAt:9999999999}};
    else if(path.endsWith('/analytics'))data={totalUsers:42,enabledUsers:40,suspendedUsers:2,administrators:3,newRegistrations:4,onlineVerifiedDeliverers:8,activeUsers7d:24};
    else if(path.endsWith('/stream')) {expect(route.request().headers().authorization).toBe('Bearer test-only');await route.fulfill({contentType:'text/event-stream',body:'event: ready\ndata: {}\n\nevent: invalidate\ndata: {}\n\n'});return;}
    else if(path.endsWith('/metrics'))data={totalOrders:10,pendingPayments:2,series:Array.from({length:14},(_,i)=>({day:`2026-10-${String(i+1).padStart(2,'0')}`,orders:i,payments:1,revenue_minor:'10000',users:2}))};
    else if(path.endsWith('/activity')||path.endsWith('/audit'))data={events:[{id:'event-1',user_id:target.id,admin_id:'super-1',event_type:'user_login',action:'user_updated',entity:'profiles',entity_id:target.id,created_at:'2026-10-12T10:00:00Z',previous_state:{roles:['sender']},new_state:{roles:['sender','admin']}}],total:1};
    else if(method!=='GET'){mutations.push({method,body:route.request().postDataJSON()});data={id:target.id};}
    else if(path.endsWith('/users'))data={users:[target],total:1};
    else data={user:target,orders:[],transactions:[],verification:[],reports:[],activity:[]};
    await route.fulfill({json:{success:true,data}});
  });
  await page.goto('/');await page.getByLabel('Email',{exact:true}).fill('owner@example.test');await page.getByLabel('Password',{exact:true}).fill('test-password');await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await expect(page.getByRole('heading',{name:'Platform Activity'})).toBeVisible();
  await expect(page.getByText('42',{exact:true})).toBeVisible();
  await expect(page.getByRole('heading',{name:'Verified payments',exact:true})).toBeVisible();
  await page.getByLabel('Category',{exact:true}).selectOption('finance');
  await page.getByLabel('Outcome',{exact:true}).selectOption('failed');
  await expect(page.getByRole('button',{name:'user_updated',exact:true})).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:info.outputPath('platform-monitoring.png'),fullPage:true});
  await page.getByRole('button',{name:'Users',exact:true}).click();
  await page.getByRole('button',{name:'Delivery Customer',exact:true}).click();
  await page.getByRole('checkbox',{name:'admin',exact:true}).check();
  await page.getByLabel('Reason').fill('Grant operations access');
  await page.getByRole('button',{name:'Save changes',exact:true}).click();
  await expect(page.getByRole('dialog')).toBeVisible();expect(mutations).toHaveLength(0);
  await page.getByRole('button',{name:'Confirm',exact:true}).click();
  await expect.poll(()=>mutations.length).toBe(1);
  expect(mutations[0]).toEqual({method:'PATCH',body:{name:target.full_name,phone:null,roles:['sender','admin'],status:'active',reason:'Grant operations access'}});
  await expect(page.getByRole('heading',{name:target.full_name,exact:true})).toHaveCount(0);
  await page.getByRole('button',{name:target.full_name,exact:true}).click();
  await page.getByLabel('Reason').fill('Account retention request');
  await page.getByRole('button',{name:'Deactivate account',exact:true}).click();
  await expect(page.getByRole('dialog')).toContainText('Financial records');
  await page.getByRole('button',{name:'Confirm',exact:true}).click();
  await expect.poll(()=>mutations.length).toBe(2);
  expect(mutations[1].body).toEqual({reason:'Account retention request',confirmation:'DEACTIVATE'});
  await page.getByRole('button',{name:'Administrators',exact:true}).click();
  await expect(page.getByRole('heading',{name:'Administrators & Staff'})).toBeVisible();
  await page.getByRole('button',{name:'Audit Logs',exact:true}).click();
  await page.getByRole('button',{name:'user_updated',exact:true}).click();
  await expect(page.getByRole('heading',{name:'Previous state'})).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:info.outputPath('platform-audit.png'),fullPage:true});
  expect(await page.evaluate(()=>Object.keys(localStorage))).toEqual([]);
});

test('invitation validates its session and sets a password without exposing URL credentials',async({page})=>{
  const calls:string[]=[];
  await page.route('**/api/v1/**',async route=>{
    const path=new URL(route.request().url()).pathname;calls.push(path);
    expect(route.request().headers().authorization).toBe('Bearer test-only-invitation');
    if(path.endsWith('/auth/password'))expect(route.request().postDataJSON()).toEqual({password:'New-invited-password'});
    await route.fulfill({json:{success:true,data:path.endsWith('/users/me')?{user:{uid:'invited'}}:{updated:true}}});
  });
  await page.goto('/accept-invitation#type=invite&access_token=test-only-invitation&refresh_token=test-only-refresh');
  await expect(page).toHaveURL(/\/accept-invitation$/);
  await page.getByLabel('Password',{exact:true}).fill('New-invited-password');
  await page.getByLabel('Confirm password',{exact:true}).fill('New-invited-password');
  await page.getByRole('button',{name:'Set password',exact:true}).click();
  await expect(page.getByRole('heading',{name:'Account Ready'})).toBeVisible();
  expect(calls).toEqual(['/api/v1/users/me','/api/v1/auth/password','/api/v1/auth/logout']);
  expect(await page.evaluate(()=>Object.keys(localStorage))).toEqual([]);
});

test('invalid invitation session never attempts password changes',async({page})=>{
  let updates=0;
  await page.route('**/api/v1/**',async route=>{
    if(route.request().method()==='POST')updates++;
    await route.fulfill({status:401,json:{success:false,error:{message:'Invalid invitation session.'}}});
  });
  await page.goto('/accept-invitation#type=invite&access_token=invalid-test-only-token');
  await page.getByLabel('Password',{exact:true}).fill('New-invited-password');
  await page.getByLabel('Confirm password',{exact:true}).fill('New-invited-password');
  await page.getByRole('button',{name:'Set password',exact:true}).click();
  await expect(page.getByRole('alert')).toHaveText('Invalid invitation session.');
  expect(updates).toBe(0);
  await expect(page.getByRole('heading',{name:'Account Ready'})).toHaveCount(0);
});
