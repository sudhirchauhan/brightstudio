const {test,expect}=require('@playwright/test');
const path=require('node:path'),crypto=require('node:crypto');
test.use({storageState:path.resolve('playwright/.auth/a.json')});
const origin=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000';
async function fixture(request){
  const {csrf}=await(await request.get('/studio/api/session')).json(),projects=await(await request.get('/studio/api/hub/projects')).json();
  const headers={Origin:origin,'X-CSRF-Token':csrf},title=`Study ${crypto.randomUUID()}`;
  const source=await(await request.post('/studio/api/hub/sources',{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{project_id:projects[0].id,title}})).json();
  const revision=await(await request.post(`/studio/api/hub/sources/${source.id}/revisions`,{headers:{...headers,'Content-Type':'text/plain','X-Upload-Filename':'lesson.txt','Idempotency-Key':crypto.randomUUID()},data:Buffer.from('Learning '.repeat(80)+'Practice saves progress.')})).json();
  await expect.poll(async()=>(await(await request.get(`/studio/api/hub/sources/${source.id}/revisions`)).json())[0].state,{timeout:15000}).toBe('ready');
  return{source,revision,headers,title,project:projects[0]};
}
test('study gates, duplicate attempts, concurrent tabs, ownership and immutable revision',async({request,playwright})=>{
  const f=await fixture(request),headers={...f.headers,'Idempotency-Key':crypto.randomUUID()},data={source_id:f.source.id,revision_id:f.revision.id};
  expect((await request.post('/studio/api/hub/study',{data})).status()).toBe(403);
  const starts=await Promise.all([request.post('/studio/api/hub/study',{headers,data}),request.post('/studio/api/hub/study',{headers,data})]);for(const r of starts)expect(r.status()).toBe(201);
  const p=await starts[0].json();expect((await starts[1].json()).id).toBe(p.id);expect(p.lesson.answer).toBeUndefined();
  const url=`/studio/api/hub/study/${p.id}/attempts`,answer={expected_version:1,step:0,kind:'answer',answer:'Learning'};
  expect((await request.post(url,{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{...answer,step:1}})).status()).toBe(409);
  expect((await request.post(url,{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{...answer,kind:'summary'}})).status()).toBe(409);
  const writers=[crypto.randomUUID(),crypto.randomUUID()],results=await Promise.all(writers.map(key=>request.post(url,{headers:{...f.headers,'Idempotency-Key':key},data:answer})));
  expect(results.map(r=>r.status()).sort()).toEqual([200,409]);const index=results.findIndex(r=>r.status()===200),receipt=await results[index].json();
  const replay=await request.post(url,{headers:{...f.headers,'Idempotency-Key':writers[index]},data:answer});expect(await replay.json()).toEqual(receipt);
  expect((await request.post(url,{headers:{...f.headers,'Idempotency-Key':writers[index]},data:{...answer,answer:'Changed'}})).status()).toBe(409);
  const other=await playwright.request.newContext({baseURL:origin,storageState:path.resolve('playwright/.auth/b.json')}),{csrf}=await(await other.get('/studio/api/session')).json();
  expect((await other.get(`/studio/api/hub/study/${p.id}`)).status()).toBe(404);
  expect((await other.post(url,{headers:{Origin:origin,'X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()},data:answer})).status()).toBe(404);await other.dispose();
  await request.post(`/studio/api/hub/sources/${f.source.id}/revisions`,{headers:{...f.headers,'Content-Type':'text/plain','X-Upload-Filename':'v2.txt','Idempotency-Key':crypto.randomUUID()},data:Buffer.from('Different revision.')});
  const resumed=await(await request.get(`/studio/api/hub/study/${p.id}`)).json();expect(resumed.revision_id).toBe(f.revision.id);expect(resumed.step).toBe(1);
});
test('reader to lesson, incorrect feedback, reload resume, reflection and completed review',async({request,page})=>{
  const f=await fixture(request);await page.goto(`/studio/hub/sources/${f.source.id}`);await page.getByRole('link',{name:'Study this revision'}).click();
  await expect(page.locator('#study-title')).toHaveText(f.title);await expect(page.locator('#study-progress')).toContainText('0 of 2');
  await page.locator('#study-answer').fill('Wrong');await page.getByRole('button',{name:'Check answer',exact:true}).click();await expect(page.locator('#study-feedback')).toContainText('Try again');await expect(page.locator('#study-progress')).toContainText('0 of 2');
  await page.locator('#study-answer').fill(' learning ');await page.locator('#study-submit').focus();await page.keyboard.press('Enter');await expect(page.locator('#study-progress')).toContainText('1 of 2');
  const lessonUrl=page.url();await page.reload();await expect(page.locator('#study-progress')).toContainText('1 of 2');
  await page.locator('#study-answer').fill('Practice');await page.locator('#study-submit').click();await expect(page.locator('#study-progress')).toContainText('summary');
  await page.locator('#study-answer').fill('short');await page.locator('#study-submit').click();await expect(page.locator('#study-feedback')).toContainText('20 characters');
  await page.locator('#study-answer').fill('I will practice recalling the passage tomorrow.');await page.getByRole('button',{name:'Complete lesson',exact:true}).click();await expect(page.locator('#study-progress')).toContainText('completed');await expect(page.locator('#study-form')).toBeHidden();
  await page.goto(lessonUrl);await expect(page.locator('#study-summary')).toContainText('recalling the passage');await expect(page.locator('#study-origin')).toHaveAttribute('href',`/studio/hub/sources/${f.source.id}?revision=${f.revision.id}`);
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
  await page.getByRole('button',{name:'Back to lessons'}).click();await expect(page.locator('#study-passes')).toContainText(f.title);
});
test('uncertain writes retry once, conflicts preserve drafts and loading errors recover',async({request,page})=>{
  const f=await fixture(request);await page.goto(`/studio/hub/study/?source=${f.source.id}&revision=${f.revision.id}`);await expect(page.locator('#study-progress')).toContainText('0 of 2');
  const id=new URL(page.url()).searchParams.get('pass');let interrupted=false;
  await page.route(`**/studio/api/hub/study/${id}/attempts`,async route=>{if(!interrupted){interrupted=true;await route.fetch();await route.abort();}else await route.continue();});
  await page.locator('#study-answer').fill('Learning');await page.locator('#study-submit').click();await expect(page.locator('#study-feedback')).toContainText('Retry the same answer');await expect(page.locator('#study-answer')).toHaveValue('Learning');
  await page.locator('#study-submit').click();await expect(page.locator('#study-progress')).toContainText('1 of 2');
  const saved=await(await request.get(`/studio/api/hub/study/${id}`)).json();expect(saved.version).toBe(2);
  await request.post(`/studio/api/hub/study/${id}/attempts`,{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{expected_version:2,step:1,kind:'answer',answer:'incorrect'}});
  await page.locator('#study-answer').fill('Practice');await page.locator('#study-submit').click();await expect(page.locator('#study-feedback')).toContainText('another tab');await expect(page.locator('#study-answer')).toHaveValue('Practice');
  await page.getByRole('button',{name:'Refresh study'}).click();await expect(page.locator('#study-status')).toHaveText('Saved progress loaded.');await expect(page.locator('#study-answer')).toHaveValue('Practice');await page.locator('#study-submit').click();await expect(page.locator('#study-progress')).toContainText('summary');
  await page.route('**/studio/api/hub/library-state?*',route=>route.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await page.route('**/studio/api/hub/study?*',route=>route.fulfill({status:200,contentType:'application/json',body:'[]'}));
  await page.goto('/studio/hub/study/');await expect(page.locator('#study-status')).toContainText('No ready sources');
  await page.route('**/studio/api/hub/study?*',route=>route.fulfill({status:503,contentType:'application/json',body:'{}'}));
  await page.getByRole('button',{name:'Refresh study'}).click();await expect(page.locator('#study-status')).toContainText('Could not confirm');
});
test('retrying an older receipt displays the latest committed progress from another tab',async({request,page})=>{
  const f=await fixture(request);await page.goto(`/studio/hub/study/?source=${f.source.id}&revision=${f.revision.id}`);await expect(page.locator('#study-progress')).toContainText('0 of 2');
  const id=new URL(page.url()).searchParams.get('pass');let interrupted=false;
  await page.route(`**/studio/api/hub/study/${id}/attempts`,async route=>{if(!interrupted){interrupted=true;await route.fetch();await route.abort();}else await route.continue();});
  await page.locator('#study-answer').fill('Learning');await page.locator('#study-submit').click();await expect(page.locator('#study-feedback')).toContainText('Retry the same answer');
  const advanced=await request.post(`/studio/api/hub/study/${id}/attempts`,{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{expected_version:2,step:1,kind:'answer',answer:'Practice'}});expect(advanced.status()).toBe(200);
  await page.locator('#study-submit').click();await expect(page.locator('#study-progress')).toContainText('summary');await expect(page.locator('#study-submit')).toHaveText('Complete lesson');
});
