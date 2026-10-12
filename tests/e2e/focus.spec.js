const {test,expect}=require('@playwright/test'),path=require('node:path'),crypto=require('node:crypto');
const {expireActiveSession}=require('../focus-fixture-clock');
const {navigate}=require('../ui-navigation');
test.use({storageState:path.resolve('playwright/.auth/a.json')});
const origin=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000';
async function fixture(request){
 const {csrf}=await(await request.get('/studio/api/session')).json(),projects=await(await request.get('/studio/api/hub/projects')).json(),p=projects[0].id;
 const headers={Origin:origin,'X-CSRF-Token':csrf},data=await(await request.get(`/studio/api/hub/focus?project_id=${p}`)).json();
 if(data.current)expect((await request.post(`/studio/api/hub/focus/${data.current.id}/actions`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{action:'cancel',expected_version:data.current.version}})).status()).toBe(200);
 const title=`Focus ${crypto.randomUUID()}`,source=await(await request.post('/studio/api/hub/sources',{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{title,project_id:p}})).json();
 const revision=await(await request.post(`/studio/api/hub/sources/${source.id}/revisions`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID(),'Content-Type':'text/plain','X-Upload-Filename':'focus.txt'},data:Buffer.from('Active recall makes ideas stick.')})).json();
 await expect.poll(async()=>(await(await request.get(`/studio/api/hub/sources/${source.id}/revisions`)).json())[0]?.state,{timeout:15000}).toBe('ready');
 const evidence=await(await request.post('/studio/api/hub/evidence',{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{source_id:source.id,revision_id:revision.id,start_byte:0,end_byte:13,quote:'Active recall',note:'A Focus fixture quote.'}})).json();
 return{source,revision,title,evidence,headers,start:{project_id:p,source_id:source.id,revision_id:revision.id,minutes:1}};
}
async function action(request,f,id,data,key=crypto.randomUUID()){return request.post(`/studio/api/hub/focus/${id}/actions`,{headers:{...f.headers,'Idempotency-Key':key},data});}
test('server time, ownership, version races and exact completion replay',async({request,playwright})=>{
 const f=await fixture(request),key=crypto.randomUUID(),startHeaders={...f.headers,'Idempotency-Key':key};
 expect((await request.post('/studio/api/hub/focus',{data:f.start})).status()).toBe(403);
 expect((await request.post('/studio/api/hub/focus',{headers:startHeaders,data:{...f.start,elapsed_ms:60000}})).status()).toBe(400);
 const started=await request.post('/studio/api/hub/focus',{headers:startHeaders,data:f.start});expect(started.status()).toBe(201);const s=await started.json();
 expect(await(await request.post('/studio/api/hub/focus',{headers:startHeaders,data:f.start})).json()).toEqual(s);
 expect((await request.post('/studio/api/hub/focus',{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:f.start})).status()).toBe(409);
 const finish={action:'complete',expected_version:1,summary:'I will practice recalling this source again tomorrow.'};expect((await action(request,f,s.id,finish)).status()).toBe(409);
 expect((await action(request,f,s.id,{...finish,elapsed_ms:60000})).status()).toBe(400);
 const cp={action:'checkpoint',expected_version:1,expected_checkpoint:0,note:'I practiced a recall passage.',evidence_id:f.evidence.id};expect((await action(request,f,s.id,{...cp,expected_checkpoint:1})).status()).toBe(409);
 const receipt=await(await action(request,f,s.id,cp)).json();expect(receipt.checkpoint_count).toBe(1);expect(receipt.checkpoints[0].revision_id).toBe(f.revision.id);
 const pauses=await Promise.all([action(request,f,s.id,{action:'pause',expected_version:2}),action(request,f,s.id,{action:'pause',expected_version:2})]);expect(pauses.map(r=>r.status()).sort()).toEqual([200,409]);
 const paused=await(await request.get(`/studio/api/hub/focus/${s.id}`)).json();await new Promise(r=>setTimeout(r,50));expect((await(await request.get(`/studio/api/hub/focus/${s.id}`)).json()).elapsed_ms).toBe(paused.elapsed_ms);
 const other=await playwright.request.newContext({baseURL:origin,storageState:path.resolve('playwright/.auth/b.json')});expect((await other.get(`/studio/api/hub/focus/${s.id}`)).status()).toBe(404);const {csrf}=await(await other.get('/studio/api/session')).json();expect((await other.post(`/studio/api/hub/focus/${s.id}/actions`,{headers:{Origin:origin,'X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()},data:finish})).status()).toBe(404);await other.dispose();
 expect((await action(request,f,s.id,{action:'resume',expected_version:3})).status()).toBe(200);expireActiveSession(s.id);
 const keys=[crypto.randomUUID(),crypto.randomUUID()],final={...finish,expected_version:4},ends=await Promise.all(keys.map(k=>action(request,f,s.id,final,k)));expect(ends.map(r=>r.status()).sort()).toEqual([200,409]);
 const winner=ends.findIndex(r=>r.status()===200),done=await ends[winner].json();expect(await(await action(request,f,s.id,final,keys[winner])).json()).toEqual(done);expect(done.state).toBe('completed');expect(done.version).toBe(5);expect(done.elapsed_ms).toBe(60000);
 expect((await action(request,f,s.id,{action:'resume',expected_version:5})).status()).toBe(409);
 expect((await action(request,f,s.id,{...final,summary:'A different reflection with the same replay key.'},keys[winner])).status()).toBe(409);
});
test('reader entry, uncertain checkpoints, conflict drafts, fullscreen and completed review',async({request,page})=>{
 const f=await fixture(request),errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/studio/hub/hub.js',async route=>{await new Promise(r=>setTimeout(r,150));await route.continue();});
 await page.goto(`/studio/hub/sources/${f.source.id}?revision=${f.revision.id}`);await page.locator('#focus-source').click();await expect(page.locator('#focus-target')).toContainText(f.title);
 await page.locator('#focus-minutes').fill('1');await page.locator('#focus-start-button').focus();await page.keyboard.press('Enter');await expect(page.locator('#focus-title')).toHaveText(f.title);await expect(page.locator('body')).toHaveClass(/focused/);
 await page.screenshot({path:test.info().outputPath('focus-active.jpg'),fullPage:true,type:'jpeg'});
 const id=new URL(page.url()).searchParams.get('session');await expect(page.locator('#focus-origin')).toHaveAttribute('href',`/studio/hub/sources/${f.source.id}?revision=${f.revision.id}`);
 await page.locator('#focus-fullscreen').click();await expect.poll(()=>page.evaluate(()=>Boolean(document.fullscreenElement))).toBe(true);await page.keyboard.press('Escape');await expect.poll(()=>page.evaluate(()=>Boolean(document.fullscreenElement))).toBe(false);
 await page.locator('#focus-pause').click();await expect(page.locator('#focus-state')).toContainText('Paused');await page.reload();await expect(page.locator('#focus-state')).toContainText('Paused');await page.locator('#focus-resume').click();
 let lost=false;await page.route(`**/studio/api/hub/focus/${id}/actions`,async route=>{if(!lost&&JSON.parse(route.request().postData()).action==='checkpoint'){lost=true;await route.fetch();await route.abort();}else await route.continue();});
 await page.getByText('Add a checkpoint',{exact:true}).click();await page.locator('#focus-note').fill('A retained checkpoint draft after an uncertain save.');await page.locator('#focus-evidence').selectOption(f.evidence.id);await page.locator('#focus-checkpoint-save').click();await expect(page.locator('#focus-save-status')).toContainText('Retry the same request');await expect(page.locator('#focus-note')).toHaveValue('A retained checkpoint draft after an uncertain save.');await page.locator('#focus-checkpoint-save').click();await expect(page.locator('#focus-checkpoints .card')).toHaveCount(1);await expect(page.locator('#focus-checkpoints')).toContainText('Active recall');
 const latest=await(await request.get(`/studio/api/hub/focus/${id}`)).json();await action(request,f,id,{action:'pause',expected_version:latest.version});
 await page.locator('#focus-note').fill('Keep this second draft during a concurrent update.');await page.locator('#focus-checkpoint-save').click();await expect(page.locator('#focus-save-status')).toContainText('draft is kept');await expect(page.locator('#focus-note')).toHaveValue('Keep this second draft during a concurrent update.');await page.locator('#focus-sync').click();await expect(page.locator('#focus-note')).toHaveValue('Keep this second draft during a concurrent update.');await page.locator('#focus-checkpoint-save').click();await expect(page.locator('#focus-checkpoints .card')).toHaveCount(2);await page.locator('#focus-resume').click();
 expireActiveSession(id);await page.route(`**/studio/api/hub/focus/${id}`,async route=>{await new Promise(r=>setTimeout(r,600));await route.continue();});await page.locator('#focus-sync').click();await expect(page.locator('#focus-finish')).toBeDisabled();await expect(page.locator('#focus-finish')).toBeEnabled();await page.locator('#focus-summary').fill('I will revisit the quote and practice recalling it tomorrow.');await page.locator('#focus-finish').click();await expect(page.locator('#focus-completed-summary')).toContainText('revisit the quote');await page.reload();await expect(page.locator('#focus-state')).toContainText('Completed');await expect(page.locator('#focus-completed-summary')).toContainText('revisit the quote');
 expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);await page.screenshot({path:test.info().outputPath('focus-completed.jpg'),fullPage:true,type:'jpeg'});await page.locator('#focus-back').click();await expect(page.locator('header')).toBeVisible();expect(errors).toEqual([]);
});
test('task entry, cancellation, empty and recoverable dependency states',async({request,page})=>{
 const f=await fixture(request),task=await(await request.post('/studio/api/workspace/tasks',{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{title:`One thing at a time ${crypto.randomUUID()}`,project_id:f.start.project_id}})).json();
 await page.goto(`/studio/hub/tasks/?project=${f.start.project_id}`);await page.locator('#task-list .card').filter({hasText:task.title}).getByRole('link',{name:'Focus on task'}).click();await expect(page.locator('#focus-target')).toHaveValue(/\d+/);await page.locator('#focus-minutes').fill('1');await page.locator('#focus-start-button').click();await expect(page.locator('#focus-title')).toHaveText(task.title);await page.locator('#focus-cancel').click();await expect(page.locator('#focus-state')).toContainText('Cancelled');await page.locator('#focus-back').click();
 await navigate(page,'Focus');await page.route('**/studio/api/hub/focus/targets?*',route=>route.fulfill({json:{tasks:[],sources:[]}}));await page.route('**/studio/api/hub/focus?*',route=>route.fulfill({json:{sessions:[],current:null}}));await page.reload();await expect(page.locator('#focus-status')).toContainText('No tasks or ready sources');await expect(page.locator('#focus-start-button')).toBeDisabled();
 await page.route('**/studio/api/hub/focus/targets?*',route=>route.fulfill({status:503,json:{error:'unavailable'}}));await page.locator('#focus-reload').click();await expect(page.locator('#focus-status')).toContainText('Could not confirm');await page.unroute('**/studio/api/hub/focus/targets?*');await page.locator('#focus-reload').click();await expect(page.locator('#focus-start-button')).toBeEnabled();
});
