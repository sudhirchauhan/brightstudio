// Run separately after restarting the local acceptance release. Uses only disposable fixture accounts.
'use strict';
const {chromium,expect}=require('@playwright/test'),assert=require('node:assert/strict');
const base=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000',old='Password-acceptance-original',changed='Password-acceptance-changed';
(async()=>{
  const browser=await chromium.launch(process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE?{executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE}:{});
  try{for(const [name,viewport] of [['desktop',{width:1280,height:800}],['mobile',{width:390,height:844}]]){
    const email=`password-${name}@example.test`,context=await browser.newContext({viewport}),page=await context.newPage();
    await page.goto(base+'/studio/hub/account/');await expect(page).toHaveURL(/\/studio\/login\//);await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Password',{exact:true}).fill(old);await page.getByRole('button',{name:'Sign in',exact:true}).click();await expect(page.locator('#workspace-status')).toHaveText('Account loaded.');
    const second=await browser.newContext(),login=await second.request.post(base+'/studio/api/session/login',{headers:{Origin:base},data:{email,password:old}});assert.equal(login.status(),200);
    await page.getByLabel('Current password',{exact:true}).fill('wrong password');await page.getByLabel('New password',{exact:true}).fill(changed);await page.getByLabel('Confirm new password',{exact:true}).fill(changed);await page.getByRole('button',{name:'Change password and sign out',exact:true}).click();await expect(page.locator('#password-status')).toHaveText('The current password was not accepted.');
    await page.getByLabel('Current password',{exact:true}).fill(old);await page.getByLabel('Confirm new password',{exact:true}).fill(changed+'mismatch');await page.getByRole('button',{name:'Change password and sign out',exact:true}).click();await expect(page.locator('#password-status')).toHaveText('New passwords do not match.');
    await page.getByLabel('Confirm new password',{exact:true}).fill(changed);await page.getByRole('button',{name:'Change password and sign out',exact:true}).click();await expect(page).toHaveURL(/password_changed=1/);assert.equal((await second.request.get(base+'/studio/api/workspace/account')).status(),401);
    await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Password',{exact:true}).fill(changed);await page.getByRole('button',{name:'Sign in',exact:true}).click();await expect(page.locator('#workspace-status')).toHaveText('Account loaded.');
    // Restore this disposable fixture password before finishing, never the bootstrap account.
    const {csrf}=await(await context.request.get(base+'/studio/api/session')).json();const restored=await context.request.post(base+'/studio/api/workspace/password',{headers:{Origin:base,'X-CSRF-Token':csrf},data:{current_password:changed,new_password:old}});assert.equal(restored.status(),200);await second.close();await context.close();console.log(`PASS ${name}: private account entry, wrong-current-password/confirmation validation, password change, all-session revocation, new-password login and fixture restoration`);
  }}finally{await browser.close();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
