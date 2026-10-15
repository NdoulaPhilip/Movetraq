import { test,expect } from '@playwright/test';
test('mobile payment source shows verified references, failures and connection errors',async({page},info)=>{
  let unavailable=false;
  const errors:string[]=[];page.on('pageerror',e=>errors.push(e.message));
  await page.route('**/api/v1/**',async route=>{
    const url=new URL(route.request().url());let data:unknown={};
    if(url.pathname.endsWith('/auth/signin'))data={user:{uid:'owner',name:'Owner',email:'owner@example.test',roles:['super_admin']},session:{accessToken:'fixture-only',refreshToken:'fixture-refresh',expiresAt:9999999999}};
    else if(url.pathname.endsWith('/mobile/monitoring')){
      expect(route.request().headers().authorization).toBe('Bearer fixture-only');
      if(unavailable){await route.fulfill({status:503,json:{success:false,error:{message:'The mobile activity database could not be reached.'}}});return;}
      const attempts=url.searchParams.get('view')==='attempts';
      data={source:'mobile_postgres',total:1,checkedAt:'2026-10-15T11:17:12Z',stats:{users:2,orders:6,payments:1,verified_payments:1,failed_operations:1},rows:[attempts?{id:'attempt-1',route:'/wallet/withdraw',method:'POST',outcome:'failed',status:503,error_code:'HTTP_503',created_at:'2026-10-15T11:17:12Z'}:{entity:'payments',entity_id:'mt-fixture-only',user_id:'user-fixture',created_at:'2026-10-15T11:17:12Z',record:{reference:'mt-fixture-only',status:'verified',amount_minor:550000,currency:'NGN',verified_at:'2026-10-15T11:17:12Z'}}]};
    }
    await route.fulfill({json:{success:true,data}});
  });
  await page.goto('/');await page.getByLabel('Email',{exact:true}).fill('owner@example.test');await page.getByLabel('Password',{exact:true}).fill('fixture-password');await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await page.getByRole('button',{name:'Payments & Wallet',exact:true}).click();
  await expect(page.getByText('NGN 5500.00',{exact:true})).toBeVisible();await expect(page.getByText('mt-fixture-only',{exact:true}).first()).toBeVisible();
  await page.getByRole('button',{name:'mt-fixture-only',exact:true}).click();await expect(page.getByRole('heading',{name:'Mobile record'})).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.screenshot({path:info.outputPath('mobile-payments.png'),fullPage:true});
  await page.getByLabel('Mobile section',{exact:true}).selectOption('attempts');await expect(page.getByText('failed',{exact:true})).toBeVisible();
  unavailable=true;await page.getByRole('button',{name:'Refresh mobile records'}).click();await expect(page.getByRole('alert')).toContainText('could not be reached');
  expect(errors).toEqual([]);
});
