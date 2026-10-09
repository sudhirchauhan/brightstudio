const {test,expect} = require('@playwright/test');
const path=require('node:path'),crypto=require('node:crypto'),fs=require('node:fs');
const fixtures=require('../fixtures');
test.use({storageState:path.resolve('playwright/.auth/a.json')});
const origin=process.env.BRIGHT_TEST_BASE || 'http://127.0.0.1:10000';
async function create(request,title) {
  const projects=await(await request.get('/studio/api/hub/projects')).json();
  const {csrf}=await(await request.get('/studio/api/session')).json();
  const headers={Origin:origin,'X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()};
  const response=await request.post('/studio/api/hub/sources',{headers,data:{title,project_id:projects[0].id,kind:'book'}});
  expect(response.status()).toBe(201);return {source:await response.json(),headers};
}
async function upload(request,source,headers,data,mime='text/plain',name='source.txt') {
  return request.post(`/studio/api/hub/sources/${source.id}/revisions`,{headers:{...headers,'Idempotency-Key':headers['Idempotency-Key'],'Content-Type':mime,'X-Upload-Filename':encodeURIComponent(name)},data});
}
async function ready(request,source,revision) {
  await expect.poll(async()=>{
    const response=await request.get(`/studio/api/hub/sources/${source.id}/revisions`);
    if(response.status()!==200)return 'unavailable';const list=await response.json();return list.find(item=>item.id===revision.id)?.state;
  },{timeout:15000}).toBe('ready');
}
test('private originals, owner isolation, CSRF, idempotency and immutable revisions',async({request,playwright})=>{
  const {source,headers}=await create(request,`Private file ${crypto.randomUUID()}`), original=Buffer.from('First immutable reading text.\n<script>Shown as text.</script>');
  const noCSRF=await upload(request,source,{...headers,'X-CSRF-Token':''},original);expect(noCSRF.status()).toBe(403);
  const wrongOrigin=await upload(request,source,{...headers,Origin:'https://evil.example'},original);expect(wrongOrigin.status()).toBe(403);
  const results=await Promise.all(Array.from({length:3},()=>upload(request,source,headers,original)));
  for(const response of results)expect(response.status()).toBe(201);
  const records=await Promise.all(results.map(response=>response.json()));expect(new Set(records.map(r=>r.id)).size).toBe(1);
  const revision=records[0];await ready(request,source,revision);
  expect(revision.sha256).toBe(crypto.createHash('sha256').update(original).digest('hex'));
  const download=await request.get(`/studio/api/hub/sources/${source.id}/revisions/${revision.id}/original`);expect(download.status()).toBe(200);expect(await download.body()).toEqual(original);expect(download.headers()['cache-control']).toBe('no-store');
  expect((await upload(request,source,headers,Buffer.from('Changed payload'))).status()).toBe(409);
  const second=await upload(request,source,{...headers,'Idempotency-Key':crypto.randomUUID()},Buffer.from('Second reading revision'));expect(second.status()).toBe(201);expect((await second.json()).revision).toBe(2);
  const firstContent=await(await request.get(`/studio/api/hub/sources/${source.id}/revisions/${revision.id}/content`)).json();expect(firstContent.text).toBe(original.toString());
  const other=await playwright.request.newContext({baseURL:origin,storageState:path.resolve('playwright/.auth/b.json')});
  for(const suffix of ['',`/${revision.id}/original`,`/${revision.id}/content`])expect((await other.get(`/studio/api/hub/sources/${source.id}/revisions${suffix}`)).status()).toBe(404);
  const otherCsrf=(await(await other.get('/studio/api/session')).json()).csrf;
  expect((await upload(other,source,{...headers,'X-CSRF-Token':otherCsrf},original)).status()).toBe(404);
  expect((await other.post(`/studio/api/hub/sources/${source.id}/revisions/${revision.id}/retry`,{headers:{Origin:origin,'X-CSRF-Token':otherCsrf}})).status()).toBe(404);await other.dispose();
  expect((await upload(request,source,{...headers,'Idempotency-Key':crypto.randomUUID()},Buffer.from('bad'),'image/png','wrong.png')).status()).toBe(415);
  expect((await upload(request,source,{...headers,'Idempotency-Key':crypto.randomUUID()},Buffer.alloc(4194305,97))).status()).toBe(413);
});
test('keyboard upload, readable text, revision selection and private download',async({page})=>{
  await page.goto('/studio/hub/library/');await page.getByRole('button',{name:'Add Source'}).click();
  const title=`Uploaded text ${crypto.randomUUID()}`, original=Buffer.from('A private reading paragraph.\n<script>Not executable.</script>');
  await page.getByLabel('Title',{exact:true}).fill(title);await page.locator('#file').setInputFiles({name:'reading.txt',mimeType:'text/plain',buffer:original});
  await page.getByRole('button',{name:'Save source'}).click();await expect(page.getByRole('dialog')).not.toBeVisible();await page.getByRole('link',{name:title,exact:true}).click();
  await expect(page.getByRole('article',{name:'Source text'})).toContainText('A private reading paragraph.',{timeout:15000});
  await expect(page.locator('#reading-text script')).toHaveCount(0);
  const downloadEvent=page.waitForEvent('download');await page.getByRole('link',{name:'Download original'}).click();const download=await downloadEvent;expect(fs.readFileSync(await download.path())).toEqual(original);
  await page.getByRole('button',{name:'Upload a revision'}).focus();await page.keyboard.press('Enter');await expect(page.locator('#file')).toBeFocused();
  await page.locator('#file').setInputFiles({name:'revised.txt',mimeType:'text/plain',buffer:Buffer.from('A revised reading paragraph.')});await page.getByRole('button',{name:'Upload file',exact:true}).click();
  await expect(page.getByRole('article',{name:'Source text'})).toContainText('A revised reading paragraph.',{timeout:15000});
  const options=await page.locator('#revision option').evaluateAll(items=>items.map(item=>({value:item.value,text:item.textContent})));expect(options).toHaveLength(2);
  await page.getByLabel('Revision',{exact:true}).selectOption(options.find(item=>item.text.startsWith('Revision 1')).value);
  await expect(page.getByRole('article',{name:'Source text'})).toContainText('A private reading paragraph.');await page.reload();await expect(page.getByRole('article',{name:'Source text'})).toContainText('A private reading paragraph.');
  expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('PDF and EPUB extraction produce readable content',async({request,page})=>{
  for(const [mime,name,buffer,expected] of [['application/pdf','reading.pdf',fixtures.pdf(),'A private PDF reading page'],['application/epub+zip','reading.epub',fixtures.epub(),'A private EPUB chapter']]){
    const {source,headers}=await create(request,`${name} ${crypto.randomUUID()}`);const response=await upload(request,source,headers,buffer,mime,name);expect(response.status()).toBe(201);const revision=await response.json();await ready(request,source,revision);
    await page.goto(`/studio/hub/sources/${source.id}?revision=${revision.id}`);await expect(page.getByRole('article',{name:'Source text'})).toContainText(expected);await expect(page.locator('#reading-text')).not.toContainText('never run this');
  }
});
test('corrupt file failure is truthful and retry retains the same original',async({request,page})=>{
  const {source,headers}=await create(request,`Failed PDF ${crypto.randomUUID()}`),data=Buffer.from('%PDF-not-a-readable-document');
  const uploaded=await upload(request,source,headers,data,'application/pdf','corrupt.pdf');expect(uploaded.status()).toBe(201);const revision=await uploaded.json();
  await page.goto(`/studio/hub/sources/${source.id}`);await expect(page.locator('#reading-status')).toContainText('could not be read',{timeout:15000});await expect(page.getByRole('article',{name:'Source text'})).toBeEmpty();
  await page.getByRole('button',{name:'Retry extraction'}).click();await expect(page.locator('#reading-status')).toContainText('could not be read',{timeout:15000});
  expect(await(await request.get(`/studio/api/hub/sources/${source.id}/revisions/${revision.id}/original`)).body()).toEqual(data);
});
