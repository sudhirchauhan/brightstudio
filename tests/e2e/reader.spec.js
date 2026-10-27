const {test,expect}=require('@playwright/test');
const path=require('node:path'),crypto=require('node:crypto'),fs=require('node:fs'),fixtures=require('../fixtures');
test.use({storageState:path.resolve('playwright/.auth/a.json')});
const origin=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000';
async function source(request,data,mime,name){
 const projects=await(await request.get('/studio/api/hub/projects')).json(),{csrf}=await(await request.get('/studio/api/session')).json();
 const headers={Origin:origin,'X-CSRF-Token':csrf,'Idempotency-Key':crypto.randomUUID()};
 const created=await request.post('/studio/api/hub/sources',{headers,data:{project_id:projects[0].id,title:`Formatted ${name} ${crypto.randomUUID()}`,kind:'book'}});expect(created.status()).toBe(201);const s=await created.json();
 const response=await request.post(`/studio/api/hub/sources/${s.id}/revisions`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID(),'Content-Type':mime,'X-Upload-Filename':name},data});expect(response.status()).toBe(201);const r=await response.json();
 await expect.poll(async()=>{const rows=await(await request.get(`/studio/api/hub/sources/${s.id}/revisions`)).json();return rows.find(i=>i.id===r.id)?.state;},{timeout:130000}).toBe('ready');return {s,r};
}
async function select(page,selector,quote){await page.locator(selector).evaluate((el,q)=>{const walker=document.createTreeWalker(el,NodeFilter.SHOW_TEXT);let node;while((node=walker.nextNode())){const i=node.textContent.indexOf(q);if(i>=0){const r=document.createRange();r.setStart(node,i);r.setEnd(node,i+q.length);getSelection().removeAllRanges();getSelection().addRange(r);return;}}throw Error('Quote missing from rendered text');},quote);}
async function annotate(page,quote,note){await page.locator('#capture-selection').click();await expect(page.locator('#selected-quote')).toHaveText(quote);await page.getByLabel('Evidence note',{exact:true}).fill(note);await page.getByRole('button',{name:'Save evidence',exact:true}).click();await expect(page.locator('#evidence-dialog')).not.toBeVisible();await page.locator('#notes-close').click();}
async function formatted(page){await page.locator('#reader-view').selectOption('formatted');}
test('PDF original page renders, selectable text saves pinned notes and survives reopen',async({page,request,playwright})=>{
 const errors=[];page.on('pageerror',e=>errors.push(e.message));const {s,r}=await source(request,fixtures.pdf(),'application/pdf','book.pdf');
 await page.goto(`/studio/hub/sources/${s.id}`);await expect(page.locator('#capture-selection')).toBeEnabled();await formatted(page);
 await expect(page.locator('#format-status')).toContainText('Page 1 of 1. Select text');await expect(page.locator('.pdf-page canvas')).toBeVisible();
 expect(await page.locator('.pdf-page canvas').evaluate(c=>{const d=c.getContext('2d').getImageData(0,0,c.width,c.height).data;let dark=0;for(let i=0;i<d.length;i+=4)if(d[i]<160&&d[i+1]<160&&d[i+2]<160)dark++;return dark>50;})).toBe(true);
 await select(page,'.textLayer','private PDF reading');await annotate(page,'private PDF reading','PDF margin note');
 await expect.poll(()=>page.evaluate(()=>CSS.highlights.get('reader-evidence')?.size||0)).toBe(1);
 await page.locator('#format-zoom').selectOption('1.5');await expect(page.locator('#format-status')).toContainText('Select text');await expect(page.locator('.textLayer')).toContainText('A private PDF');
 await page.reload();await formatted(page);await expect(page.locator('#format-status')).toContainText('Select text');await expect.poll(()=>page.evaluate(()=>CSS.highlights.get('reader-evidence')?.size||0)).toBe(1);
 await page.locator('#notes-open').click();await expect(page.locator('#evidence-list')).toContainText('PDF margin note');
 const b=await playwright.request.newContext({baseURL:origin,storageState:'playwright/.auth/b.json'});expect((await b.get(`/studio/api/hub/sources/${s.id}/revisions/${r.id}/book`)).status()).toBe(404);await b.dispose();
 const anon=await playwright.request.newContext({baseURL:origin,storageState:{cookies:[],origins:[]}});expect((await anon.get('/studio/hub/pdfjs/pdf.mjs')).status()).toBe(401);await anon.dispose();expect(errors).toEqual([]);
});
test('EPUB reflows safe chapters, preserves emphasis and restores formatted highlights',async({page,request})=>{
 const data=fixtures.archive([
 ['mimetype','application/epub+zip'],['META-INF/container.xml',"<container><rootfile full-path='EPUB/book.opf'/></container>"],
 ['EPUB/book.opf',"<package><manifest><item id='a' href='Text/a.xhtml' media-type='application/xhtml+xml'/><item id='b' href='Text/b.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='a'/><itemref idref='b'/></spine></package>"],
 ['EPUB/Text/a.xhtml',"<html><body onload='window.badBook=1'><h1>A real book chapter</h1><p>Keep <em>useful evidence</em> close.</p><script>window.badBook=1</script><iframe src='https://example.invalid'/><a href='javascript:alert(1)'>Read safely</a></body></html>"],
 ['EPUB/Text/b.xhtml','<html><body><h2>The second chapter</h2><p>Another durable thought.</p><p>Repeated words. Repeated words.</p></body></html>']]);
 const {s}=await source(request,data,'application/epub+zip','book.epub');await page.goto(`/studio/hub/sources/${s.id}`);await expect(page.locator('#capture-selection')).toBeEnabled();await formatted(page);
 await expect(page.locator('.epub-chapter h1')).toHaveText('A real book chapter');await expect(page.locator('.epub-chapter em')).toHaveText('useful evidence');expect(await page.evaluate(()=>window.badBook)).toBeUndefined();await expect(page.locator('.epub-chapter script,.epub-chapter iframe,.epub-chapter a')).toHaveCount(0);
 await select(page,'.epub-chapter','useful evidence');await annotate(page,'useful evidence','An EPUB annotation');await expect.poll(()=>page.evaluate(()=>CSS.highlights.get('reader-evidence')?.size||0)).toBe(1);
 await page.locator('#format-next').click();await expect(page.locator('.epub-chapter h2')).toHaveText('The second chapter');await expect(page.locator('#format-next')).toBeDisabled();await select(page,'.epub-chapter','Repeated words.');await page.locator('#capture-selection').click();await expect(page.locator('#evidence-status')).toContainText('cannot be matched uniquely');await expect(page.locator('#evidence-dialog')).not.toBeVisible();
 await page.locator('#format-prev').click();await expect(page.locator('.epub-chapter h1')).toHaveText('A real book chapter');await expect.poll(()=>page.evaluate(()=>CSS.highlights.get('reader-evidence')?.size||0)).toBe(1);
 await page.reload();await formatted(page);await expect(page.locator('.epub-chapter em')).toHaveText('useful evidence');await page.locator('#notes-open').click();await expect(page.locator('#evidence-list')).toContainText('An EPUB annotation');expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);
});
test('mixed scanned PDF keeps original pages and exposes OCR for pinned annotations',async({page,request})=>{
 test.setTimeout(160000);const data=fs.readFileSync(path.resolve('erlang/apps/bright_studio/test/fixtures/mixed.pdf')),{s}=await source(request,data,'application/pdf','scan.pdf');
 await page.goto(`/studio/hub/sources/${s.id}`);await expect(page.locator('#reading-text')).toContainText('Bright Studio OCR preserves useful ideas');await expect(page.locator('#reading-text')).toContainText('Embedded text stays readable');
 await formatted(page);await expect(page.locator('#format-status')).toContainText('Scanned page');await expect(page.locator('.pdf-page canvas')).toBeVisible();await page.locator('#format-next').click();await expect(page.locator('#format-status')).toContainText('Page 2 of 2. Select text');
 await page.locator('#reader-view').selectOption('text');await select(page,'#reading-text','Bright Studio OCR preserves useful ideas');await annotate(page,'Bright Studio OCR preserves useful ideas','Scanned evidence');await page.reload();await expect(page.locator('#reading-text mark')).toHaveText('Bright Studio OCR preserves useful ideas');
});
