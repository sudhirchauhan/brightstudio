const {test,expect}=require('@playwright/test');
const path=require('node:path'),crypto=require('node:crypto');
test.use({storageState:path.resolve('playwright/.auth/a.json')});
const origin=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000';
async function source(request,text='😀 café. A pinned quote. Another paragraph.'){
  const projects=await(await request.get('/studio/api/hub/projects')).json(),{csrf}=await(await request.get('/studio/api/session')).json(),headers={Origin:origin,'X-CSRF-Token':csrf};
  const created=await request.post('/studio/api/hub/sources',{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{project_id:projects[0].id,title:`Evidence ${crypto.randomUUID()}`}});expect(created.status()).toBe(201);const source=await created.json();
  const uploaded=await request.post(`/studio/api/hub/sources/${source.id}/revisions`,{headers:{...headers,'Content-Type':'text/plain','X-Upload-Filename':'evidence.txt','Idempotency-Key':crypto.randomUUID()},data:Buffer.from(text)});expect(uploaded.status()).toBe(201);const revision=await uploaded.json();
  await expect.poll(async()=>{const records=await(await request.get(`/studio/api/hub/sources/${source.id}/revisions`)).json();return records.find(r=>r.id===revision.id).state;},{timeout:15000}).toBe('ready');return{source,revision,text,headers,project:projects[0]};
}
function anchor(fixture,quote='A pinned quote.'){const offset=fixture.text.indexOf(quote);return {source_id:fixture.source.id,revision_id:fixture.revision.id,start_byte:Buffer.byteLength(fixture.text.slice(0,offset)),end_byte:Buffer.byteLength(fixture.text.slice(0,offset+quote.length)),quote,note:'Initial note'};}
test('server anchor provenance, owner isolation, concurrent notes and idempotent links',async({request,playwright})=>{
  const f=await source(request),data=anchor(f),headers={...f.headers,'Idempotency-Key':crypto.randomUUID()};
  expect((await request.post('/studio/api/hub/evidence',{headers:{'Idempotency-Key':crypto.randomUUID()},data})).status()).toBe(403);
  expect((await request.post('/studio/api/hub/evidence',{headers:{...headers,Origin:'https://evil.example'},data})).status()).toBe(403);
  expect((await request.post('/studio/api/hub/evidence',{headers,data:{...data,quote:'Forged quote'}})).status()).toBe(400);
  const results=await Promise.all(Array.from({length:3},()=>request.post('/studio/api/hub/evidence',{headers,data})));for(const r of results)expect(r.status()).toBe(201);const items=await Promise.all(results.map(r=>r.json()));expect(new Set(items.map(i=>i.id)).size).toBe(1);const item=items[0];expect(item.anchor_state).toBe('resolved');
  expect((await request.post('/studio/api/hub/evidence',{headers,data:{...data,note:'Changed'}})).status()).toBe(409);
  const writes=['First writer','Second writer'].map(note=>({note,expected_version:1,key:crypto.randomUUID()}));
  const edits=await Promise.all(writes.map(({key,...edit})=>request.post(`/studio/api/hub/evidence/${item.id}/notes`,{headers:{...f.headers,'Idempotency-Key':key},data:edit})));expect(edits.map(r=>r.status()).sort()).toEqual([200,409]);const winner=writes[edits.findIndex(r=>r.status()===200)];
  expect((await request.post(`/studio/api/hub/evidence/${item.id}/notes`,{headers:{...f.headers,'Idempotency-Key':winner.key},data:{note:winner.note,expected_version:1}})).status()).toBe(200);
  const history=await(await request.get(`/studio/api/hub/evidence/${item.id}/notes`)).json();expect(history.map(n=>n.version)).toEqual([2,1]);
  const boardCreated=await request.post('/studio/api/hub/boards',{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{project_id:f.project.id,title:'Private research'}});expect(boardCreated.status()).toBe(201);const board=await boardCreated.json();
  for(let i=0;i<2;i++)expect((await request.post(`/studio/api/hub/boards/${board.id}/links`,{headers:f.headers,data:{evidence_id:item.id}})).status()).toBe(200);expect((await(await request.get(`/studio/api/hub/boards/${board.id}`)).json()).items).toHaveLength(1);
  const other=await playwright.request.newContext({baseURL:origin,storageState:path.resolve('playwright/.auth/b.json')}),{csrf}=await(await other.get('/studio/api/session')).json(),otherHeaders={Origin:origin,'X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()};
  for(const route of [`/studio/api/hub/evidence/${item.id}`,`/studio/api/hub/evidence/${item.id}/notes`,`/studio/api/hub/boards/${board.id}`,`/studio/api/hub/evidence?source_id=${f.source.id}`])expect((await other.get(route)).status()).toBe(404);
  expect((await other.post('/studio/api/hub/evidence',{headers:otherHeaders,data})).status()).toBe(404);
  expect((await other.post(`/studio/api/hub/evidence/${item.id}/notes`,{headers:otherHeaders,data:{expected_version:2,note:'Intrusion'}})).status()).toBe(404);
  expect((await other.post(`/studio/api/hub/boards/${board.id}/links`,{headers:otherHeaders,data:{evidence_id:item.id}})).status()).toBe(404);
  expect((await other.post('/studio/api/hub/boards',{headers:otherHeaders,data:{project_id:f.project.id,title:'Denied'}})).status()).toBe(403);await other.dispose();
});
test('keyboard annotation, conflict recovery and project board journey',async({request,page})=>{
  const f=await source(request);await page.goto(`/studio/hub/sources/${f.source.id}`);await expect(page.locator('#find-selection')).toBeEnabled();
  await page.getByLabel('Find a quote',{exact:true}).fill('A pinned quote.');await page.getByRole('button',{name:'Find quote',exact:true}).focus();await page.keyboard.press('Enter');await expect(page.getByLabel('Evidence note',{exact:true})).toBeFocused();
  const note='My <script>private annotation</script>';await page.getByLabel('Evidence note',{exact:true}).fill(note);await page.getByRole('button',{name:'Save evidence',exact:true}).click();await expect(page.locator('#evidence-dialog')).not.toBeVisible();await expect(page.locator('#reading-text mark')).toHaveText('A pinned quote.');await expect(page.locator('#evidence-list')).toContainText(note);await expect(page.locator('#evidence-list script')).toHaveCount(0);
  const item=(await(await request.get(`/studio/api/hub/evidence?source_id=${f.source.id}`)).json())[0];
  await page.getByRole('button',{name:'Edit note',exact:true}).click();await page.getByLabel('Evidence note',{exact:true}).fill('My retained draft');
  const changed=await request.post(`/studio/api/hub/evidence/${item.id}/notes`,{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID()},data:{note:'A concurrent update',expected_version:1}});expect(changed.status()).toBe(200);
  await page.getByRole('button',{name:'Save note',exact:true}).click();await expect(page.locator('#evidence-form-status')).toContainText('newer note');await expect(page.getByLabel('Evidence note',{exact:true})).toHaveValue('My retained draft');await page.getByRole('button',{name:'Reload latest note'}).click();await expect(page.locator('#evidence-form-status')).toContainText('A concurrent update');await page.getByRole('button',{name:'Save note',exact:true}).click();await expect(page.locator('#evidence-dialog')).not.toBeVisible();
  await page.getByRole('link',{name:'Evidence',exact:true}).click();await expect(page.locator('#board-status')).not.toContainText('Loading');const title=`Research ${crypto.randomUUID()}`;await page.getByLabel('Board title',{exact:true}).fill(title);await page.getByRole('button',{name:'Create board',exact:true}).click();await expect(page.locator('#board-heading')).toHaveText(title);const boardId=new URL(page.url()).searchParams.get('board');
  await page.goto(`/studio/hub/sources/${f.source.id}`);await page.getByRole('button',{name:'Link to board',exact:true}).click();await page.getByLabel('Destination board',{exact:true}).selectOption(boardId);await page.getByRole('button',{name:'Save board link',exact:true}).click();await expect(page.locator('.board-picker')).toContainText('Linked.');
  await page.goto(`/studio/hub/evidence/?board=${boardId}`);await expect(page.locator('#board-items')).toContainText('My retained draft');await page.getByRole('button',{name:'Note history',exact:true}).click();await expect(page.locator('#board-items')).toContainText(`Version 1: ${note}`);
  await page.getByRole('link',{name:'Open pinned revision',exact:true}).click();await expect(page.locator('#reading-text mark')).toHaveText('A pinned quote.');expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('actual Unicode selection stays on its immutable revision and unresolved anchors are visible',async({request,page})=>{
  const f=await source(request,'😀 café. café. Ending.');await page.goto(`/studio/hub/sources/${f.source.id}`);await expect(page.locator('#capture-selection')).toBeEnabled();
  await page.evaluate(()=>{const node=document.querySelector('#reading-text pre').firstChild,range=document.createRange();range.setStart(node,9);range.setEnd(node,13);getSelection().removeAllRanges();getSelection().addRange(range);});
  await page.getByRole('button',{name:'Capture selected text'}).click();await expect(page.locator('#selected-quote')).toHaveText('café');await page.getByLabel('Evidence note',{exact:true}).fill('Second occurrence');await page.getByRole('button',{name:'Save evidence',exact:true}).click();await expect(page.locator('#reading-text mark')).toHaveText('café');
  const item=(await(await request.get(`/studio/api/hub/evidence?source_id=${f.source.id}`)).json())[0];expect(item.start_byte).toBe(Buffer.byteLength('😀 café. '));
  const upload=await request.post(`/studio/api/hub/sources/${f.source.id}/revisions`,{headers:{...f.headers,'Idempotency-Key':crypto.randomUUID(),'Content-Type':'text/plain','X-Upload-Filename':'new.txt'},data:Buffer.from('A new revision with different text.')});expect(upload.status()).toBe(201);const revision=await upload.json();
  await page.goto(`/studio/hub/sources/${f.source.id}?revision=${revision.id}`);await expect(page.getByRole('article',{name:'Source text'})).toContainText('A new revision',{timeout:15000});await expect(page.locator('#evidence-list')).toContainText('Earlier revision');await expect(page.locator('#reading-text mark')).toHaveCount(0);
  await page.route('**/studio/api/hub/evidence?*',route=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify([{...item,anchor_state:'unresolved'}])}));await page.reload();await expect(page.locator('#evidence-list')).toContainText('Unresolved anchor');await expect(page.locator('#reading-text mark')).toHaveCount(0);
});
