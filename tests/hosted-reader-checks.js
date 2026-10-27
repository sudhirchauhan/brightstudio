'use strict';
const {chromium,expect}=require('@playwright/test'),assert=require('node:assert/strict'),crypto=require('node:crypto'),path=require('node:path'),fs=require('node:fs'),fixtures=require('./fixtures');
const base=process.env.BRIGHT_TEST_BASE,password=process.env.BRIGHT_HOSTED_PASSWORD;assert.equal(base,'https://brightstudio-m1-staging.onrender.com');assert.ok(password,'Secure credential binding required');
(async()=>{const proxy=process.env.HTTPS_PROXY||process.env.https_proxy,browser=await chromium.launch({executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||'/usr/bin/chromium',...(proxy?{proxy:{server:proxy}}:{})});const output=path.resolve('erlang/_build/setup-logs/hosted-reader');fs.mkdirSync(output,{recursive:true});try{
 for(const[name,viewport]of [['desktop',{width:1280,height:800}],['mobile',{width:390,height:844}]]){
  const context=await browser.newContext({baseURL:base,viewport}),page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));page.setDefaultTimeout(45000);
  await page.goto('/studio/hub/library/');await expect(page).toHaveURL(/\/studio\/login\//);await page.getByLabel('Email',{exact:true}).fill('developer@brightstudio.test');await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Sign in',exact:true}).click();await expect(page).toHaveURL(base+'/studio/hub/library/');
  const session=await(await context.request.get('/studio/api/session')).json(),projects=await(await context.request.get('/studio/api/hub/projects')).json();
  for(const[kind,mime,data,quote]of [
   ['PDF','application/pdf',fixtures.pdf(),'A private PDF reading page'],
   ['EPUB','application/epub+zip',fixtures.epub(),'Reading durable book content.'],
   ['Scanned PDF','application/pdf',fs.readFileSync('erlang/apps/bright_studio/test/fixtures/mixed.pdf'),'Bright Studio OCR preserves useful ideas']]){
   const headers={Origin:base,'X-CSRF-Token':session.csrf,'Idempotency-Key':crypto.randomUUID()},title=`Reader demo ${name} ${kind}`;
   const created=await context.request.post('/studio/api/hub/sources',{headers,data:{title,kind:'book',project_id:projects[0].id}});assert.equal(created.status(),201);const source=await created.json();
   const uploaded=await context.request.post(`/studio/api/hub/sources/${source.id}/revisions`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID(),'Content-Type':mime,'X-Upload-Filename':kind==='EPUB'?'book.epub':'book.pdf'},data});assert.equal(uploaded.status(),201);const revision=await uploaded.json();
   await expect.poll(async()=>{const rows=await(await context.request.get(`/studio/api/hub/sources/${source.id}/revisions`)).json();return rows.find(r=>r.id===revision.id)?.state;},{timeout:180000,intervals:[1000,2000]}).toBe('ready');
   await page.goto(`/studio/hub/sources/${source.id}`);await expect(page.locator('#reading-text')).toContainText(quote);await page.locator('#reader-view').selectOption('formatted');
   if(kind==='EPUB'){await expect(page.locator('.epub-chapter h1')).toHaveText('A private EPUB chapter');await expect(page.locator('#format-status')).toContainText('Chapter 1');}
   else {await expect(page.locator('.pdf-page canvas')).toBeVisible();await expect(page.locator('#format-status')).toContainText(kind==='Scanned PDF'?'Scanned page':'Select text');}
   await page.screenshot({path:path.join(output,`${name}-${kind.replaceAll(' ','-')}.jpg`),type:'jpeg',fullPage:true});
   const selector=kind==='PDF'?'.textLayer':kind==='EPUB'?'.epub-chapter':'#reading-text';if(kind==='Scanned PDF')await page.locator('#reader-view').selectOption('text');
   await page.locator(selector).evaluate((el,q)=>{const w=document.createTreeWalker(el,NodeFilter.SHOW_TEXT);let n;while((n=w.nextNode())){const i=n.textContent.indexOf(q);if(i>=0){const r=document.createRange();r.setStart(n,i);r.setEnd(n,i+q.length);getSelection().removeAllRanges();getSelection().addRange(r);return;}}throw Error('No matching rendered quote');},quote);
   await page.locator('#capture-selection').click();await expect(page.locator('#selected-quote')).toHaveText(quote);await page.getByLabel('Evidence note',{exact:true}).fill(`${kind} Reader verification`);await page.getByRole('button',{name:'Save evidence',exact:true}).click();await expect(page.locator('#evidence-dialog')).not.toBeVisible();await expect(page.locator('#evidence-list')).toContainText(`${kind} Reader verification`);
   await page.reload();await expect(page.locator('#reading-text mark')).toHaveText(quote);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
   console.log(`PASS hosted ${name} ${kind}: private upload, extraction/OCR, formatted rendering, annotation and revision reload`);
  }
  await page.locator('#logout').click();await expect(page).toHaveURL(base+'/studio/login/');assert.equal((await context.request.get('/studio/hub/pdfjs/pdf.mjs')).status(),401);assert.deepEqual(errors,[]);await context.close();
 }
}finally{await browser.close();}})().catch(e=>{console.error(String(e.message).split(password).join('[redacted]'));process.exitCode=1;});
