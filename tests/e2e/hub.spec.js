const {test,expect} = require('@playwright/test');
const crypto = require('node:crypto');
const email = 'owner-a@example.test', password = 'Milestone-test-password-A';
const origin = process.env.BRIGHT_TEST_BASE || 'http://127.0.0.1:10000';
async function login(request, who = email, secret = password) {
  const response = await request.post('/studio/api/session/login',{headers:{Origin:origin},data:{email:who,password:secret}});
  expect(response.status()).toBe(200); return (await response.json()).csrf;
}
test('anonymous users and unauthenticated assets are denied',async({request})=>{
  for(const path of ['/studio/hub/','/studio/hub/library/','/studio/hub/hub.js','/studio/api/hub/projects','/studio/api/hub/sources']) expect((await request.get(path)).status()).toBe(401);
});
test('owner isolation, CSRF, validation and idempotent metadata writes',async({request,playwright})=>{
  const csrf = await login(request), projects = await (await request.get('/studio/api/hub/projects')).json();
  const headers = {Origin:origin,'X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()};
  const data = {project_id:projects[0].id,title:'HTTP durable source',kind:'article',url:'https://example.com/read'};
  expect((await request.post('/studio/api/hub/sources',{data})).status()).toBe(403);
  expect((await request.post('/studio/api/hub/sources',{headers:{...headers,Origin:'https://evil.example'},data})).status()).toBe(403);
  expect((await request.post('/studio/api/hub/sources',{headers,data:{...data,title:' '}})).status()).toBe(400);
  const results = await Promise.all(Array.from({length:3},()=>request.post('/studio/api/hub/sources',{headers,data})));
  for(const response of results) expect(response.status()).toBe(201);
  const records = await Promise.all(results.map(r=>r.json())); expect(new Set(records.map(x=>x.id)).size).toBe(1);
  expect((await request.post('/studio/api/hub/sources',{headers,data:{...data,title:'Changed'}})).status()).toBe(409);
  const ownerB = await playwright.request.newContext({baseURL:origin}); const csrfB = await login(ownerB,'owner-b@example.test','Milestone-test-password-B');
  expect((await ownerB.get(`/studio/api/hub/sources/${records[0].id}`)).status()).toBe(404);
  expect((await ownerB.get(`/studio/api/hub/sources?project_id=${projects[0].id}`)).status()).toBe(403);
  expect((await ownerB.post('/studio/api/hub/sources',{headers:{Origin:origin,'X-CSRF-Token':csrfB,'Idempotency-Key':crypto.randomUUID()},data})).status()).toBe(403);
  await ownerB.dispose();
  expect((await request.post('/studio/api/session/logout',{headers:{Origin:origin,'X-CSRF-Token':csrf}})).status()).toBe(200);
  expect((await request.get('/studio/api/hub/projects')).status()).toBe(401);
});
test('keyboard dialog, saved source and reader on desktop and mobile',async({page})=>{
  await page.goto('/studio/login/');
  await page.getByLabel('Email').fill(email); await page.getByLabel('Password').fill(password);
  await page.getByRole('button',{name:'Sign in',exact:true}).click();
  await expect(page).toHaveURL(/\/studio\/hub\/$/);
  await expect(page.getByRole('button',{name:'Add Source'})).toBeEnabled();
  await page.getByRole('button',{name:'Add Source'}).focus(); await page.keyboard.press('Enter');
  await expect(page.getByRole('dialog')).toBeVisible(); await expect(page.getByLabel('Title',{exact:true})).toBeFocused();
  await page.keyboard.press('Escape'); await expect(page.getByRole('dialog')).not.toBeVisible();
  await page.getByRole('button',{name:'Add Source'}).click();
  const title = `Browser <img src=x> source ${crypto.randomUUID()}`;
  await page.getByLabel('Title',{exact:true}).fill(title);
  await page.getByRole('button',{name:'Save source'}).click();
  await expect(page.getByRole('dialog')).not.toBeVisible();
  await page.getByRole('link',{name:title,exact:true}).click();
  await expect(page.getByRole('heading',{name:title})).toBeVisible();
  await expect(page.getByText('Reader placeholder.',{exact:false})).toBeVisible();
  await page.reload(); await expect(page.getByRole('heading',{name:title})).toBeVisible();
  expect(await page.evaluate(()=>document.documentElement.scrollWidth <= innerWidth)).toBe(true);
});
test('loading, empty, validation and dependency error states',async({page})=>{
  await login(page.request);
  let releaseLoading; const loading = new Promise(resolve => { releaseLoading = resolve; });
  await page.route('**/studio/api/hub/sources?*',async route=> { await loading; await route.fulfill({status:200,contentType:'application/json',body:'[]'}); });
  await page.goto('/studio/hub/library/');
  await expect(page.getByRole('status').first()).toContainText('Loading sources');
  releaseLoading();
  await expect(page.getByText('No sources yet.',{exact:false})).toBeVisible();
  await page.getByRole('button',{name:'Add Source'}).click();
  await page.getByRole('button',{name:'Save source'}).click();
  expect(await page.getByLabel('Title',{exact:true}).evaluate(e=>e.validity.valueMissing)).toBe(true);
  await page.keyboard.press('Escape');
  await page.route('**/studio/api/hub/sources?*',route=>route.fulfill({status:503,contentType:'application/json',body:'{"error":"unavailable"}'}));
  await page.reload(); await expect(page.getByRole('status').first()).toContainText('database is unavailable');
  await expect(page.getByRole('button',{name:'Add Source'})).toBeDisabled();
});
