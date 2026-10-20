import { expect,test } from '@playwright/test';

for (const identity of ['native','mobile']) {
  test(`${identity} applicants cannot review themselves even with Super Admin access`,async({page})=>{
    let reviews=0;
    await page.route('**/api/v1/**',async route=>{
      const path=new URL(route.request().url()).pathname;let data:unknown={};
      if(path.endsWith('/auth/signin'))data={user:{uid:'same-user',name:'Reviewer',email:'reviewer@example.test',roles:['super_admin']},session:{accessToken:'fixture-token',refreshToken:'fixture-refresh',expiresAt:9999999999}};
      else if(path.endsWith('/admin/verification-applications'))data={applications:[{id:'application-self',user_id:identity==='native'?'same-user':null,legacy_user_id:identity==='mobile'?'user_mobile':null,legacy_account_email:identity==='mobile'?'REVIEWER@example.test':null,status:'pending_approval',identity_info:{fullName:'Own Application'},transport_info:{transportType:'walking'},safety_declarations:{},documents:[],created_at:'2026-10-20',submitted_at:'2026-10-20'}]};
      else if(path.endsWith('/review')){reviews++;data={};}
      await route.fulfill({json:{success:true,data}});
    });
    await page.goto('/');await page.getByLabel('Email',{exact:true}).fill('reviewer@example.test');
    await page.getByLabel('Password',{exact:true}).fill('fixture-password');await page.getByRole('button',{name:'Sign in',exact:true}).click();
    await page.getByRole('button',{name:'Verification',exact:true}).click();
    await page.getByRole('button',{name:'Review application for Own Application',exact:true}).click();
    await expect(page.getByRole('alert')).toContainText('You cannot review your own deliverer application');
    await page.getByLabel('Review notes').fill('Checking identity');
    await expect(page.getByRole('button',{name:'Start review',exact:true})).toBeDisabled();
    await expect(page.getByRole('button',{name:'Reject application',exact:true})).toBeDisabled();
    expect(reviews).toBe(0);
  });
}

test('a new application alerts reviewers and the admin can review documents and approve',async({page})=>{
  let status='pending_approval';let unread=true;const decisions:unknown[]=[];
  await page.route('**/api/v1/**',async route=>{
    const url=new URL(route.request().url());const path=url.pathname;let data:unknown={};
    if(path.endsWith('/auth/signin'))data={user:{uid:'reviewer',name:'Reviewer',email:'reviewer@example.test',roles:['admin']},session:{accessToken:'fixture-token',refreshToken:'fixture-refresh',expiresAt:9999999999}};
    else if(path.endsWith('/admin/verification-notifications'))data={unreadCount:unread?1:0,notifications:unread?[{id:'notice-1',type:'deliverer_application',title:'New deliverer application',read_at:null}]:[]};
    else if(path.endsWith('/notifications/notice-1/read')){unread=false;data={updated:true};}
    else if(path.endsWith('/admin/verification-applications')){
      expect(['pending','all']).toContain(url.searchParams.get('status'));
      data={applications:[{id:'application-1',legacy_user_id:'user_applicant',legacy_account_email:'applicant@example.test',user_id:null,status,identity_info:{fullName:'New Applicant',dateOfBirth:'1990-01-01'},transport_info:{transportType:'walking'},safety_declarations:{safeHandling:true,lawfulTransport:true,termsAccepted:true},created_at:'2026-10-20',submitted_at:'2026-10-20',review_notes:null,documents:[{id:'identity-1',document_type:'identity',mime_type:'image/jpeg',size_bytes:1024,upload_verified_at:'2026-10-20'}]}]};
          if(url.searchParams.get('status')==='pending'&&!['pending_approval','submitted','under_review'].includes(status))data={applications:[]};
    }else if(path.endsWith('/review')){const input=route.request().postDataJSON();decisions.push(input);status=input.status;data={status};}
    else if(path.endsWith('/verification-documents/identity-1/download'))data={signedUrl:'https://private.example.test/identity'};
    await route.fulfill({json:{success:true,data}});
  });
  await page.context().route('https://private.example.test/**',route=>route.fulfill({contentType:'text/html',body:'Private document preview fixture'}));
  await page.goto('/');await page.getByLabel('Email',{exact:true}).fill('reviewer@example.test');
  await page.getByLabel('Password',{exact:true}).fill('fixture-password');await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await expect(page.getByLabel('New deliverer applications')).toContainText('1 new deliverer application');
  await page.getByRole('button',{name:'Review applications',exact:true}).click();
  await expect(page.getByLabel('New deliverer applications')).toHaveCount(0);
  await page.getByRole('button',{name:'Review application for New Applicant',exact:true}).click();
  await expect(page.getByLabel('Application review')).toContainText('Pending Approval');
  await expect(page.getByLabel('Application review')).toContainText('applicant@example.test');
  const popup=page.waitForEvent('popup');await page.getByRole('button',{name:'Open identity'}).click();
  const documentPage=await popup;await expect(documentPage).toHaveURL('https://private.example.test/identity');await documentPage.close();
  await expect(page.getByRole('button',{name:'Start review',exact:true})).toBeDisabled();
  await expect(page.getByRole('button',{name:'Reject application',exact:true})).toBeVisible();
  await page.getByLabel('Review notes').fill('Checking the identity document');
  await page.getByRole('button',{name:'Start review',exact:true}).click();
  await expect(page.getByRole('button',{name:'Approve application',exact:true})).toBeVisible();
  await page.getByLabel('Review notes').fill('Identity and safety information verified');
  await page.getByRole('button',{name:'Approve application',exact:true}).click();
  await expect(page.getByRole('status')).toHaveText('Review saved.');
  await page.getByRole('button',{name:'All',exact:true}).click();
  await page.getByRole('button',{name:'New Applicant',exact:true}).click();
  await expect(page.getByLabel('Application review')).toContainText('Approved');
  expect(decisions).toEqual([{status:'under_review',notes:'Checking the identity document'},{status:'approved',notes:'Identity and safety information verified'}]);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});

test('explicit rejection preserves notes on failure and updates the queue after retry',async({page})=>{
  let status='pending_approval';let fail=true;const decisions:unknown[]=[];
  await page.route('**/api/v1/**',async route=>{
    const url=new URL(route.request().url());const path=url.pathname;let data:unknown={};
    if(path.endsWith('/auth/signin'))data={user:{uid:'reviewer',name:'Reviewer',email:'reviewer@example.test',roles:['admin']},session:{accessToken:'fixture-token',refreshToken:'fixture-refresh',expiresAt:9999999999}};
    else if(path.endsWith('/admin/verification-applications'))data={applications:url.searchParams.get('status')==='pending'&&status==='rejected'?[]:[{id:'application-2',status,identity_info:{fullName:'Rejected Applicant'},transport_info:{transportType:'walking'},safety_declarations:{},created_at:'2026-10-20',submitted_at:'2026-10-20',documents:[],review_notes:status==='rejected'?'Identity document is not readable':null}]};
    else if(path.endsWith('/review')){
      const input=route.request().postDataJSON();decisions.push(input);
      if(fail){fail=false;await route.fulfill({status:503,json:{success:false,error:{message:'Review could not be saved. Please retry.'}}});return;}
      status=input.status;data={status};
    }
    await route.fulfill({json:{success:true,data}});
  });
  await page.goto('/');await page.getByLabel('Email',{exact:true}).fill('reviewer@example.test');
  await page.getByLabel('Password',{exact:true}).fill('fixture-password');await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await page.getByRole('button',{name:'Review application for Rejected Applicant',exact:true}).click();
  await expect(page.getByRole('button',{name:'Reject application',exact:true})).toBeDisabled();
  await page.getByLabel('Review notes').fill('Identity document is not readable');
  await page.getByRole('button',{name:'Reject application',exact:true}).click();
  await expect(page.getByRole('alert')).toContainText('Review could not be saved');
  await expect(page.getByLabel('Review notes')).toHaveValue('Identity document is not readable');
  await expect(page.getByLabel('Application review')).toContainText('Pending Approval');
  await page.getByRole('button',{name:'Reject application',exact:true}).click();
  await expect(page.getByRole('status')).toHaveText('Review saved.');
  await expect(page.getByRole('button',{name:'Review application for Rejected Applicant',exact:true})).toHaveCount(0);
  await page.getByRole('button',{name:'All',exact:true}).click();
  await page.getByRole('button',{name:'Review application for Rejected Applicant',exact:true}).click();
  await expect(page.getByLabel('Application review')).toContainText('Rejected');
  await expect(page.getByLabel('Application review')).toContainText('Identity document is not readable');
  await expect(page.getByRole('button',{name:'Approve application',exact:true})).toHaveCount(0);
  expect(decisions).toEqual([{status:'rejected',notes:'Identity document is not readable'},{status:'rejected',notes:'Identity document is not readable'}]);
});
