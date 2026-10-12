const {test,expect}=require('@playwright/test');
const path=require('node:path'),crypto=require('node:crypto');
const {navigate}=require('../ui-navigation');
test.use({storageState:path.resolve('playwright/.auth/a.json')});
const origin=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000';
const passage='Active recall asks you to retrieve ideas from memory, rather than simply seeing them again. Spaced practice revisits key ideas over time. The most useful notes begin with a small piece of meaningful evidence.';
async function fixture(request) {
  const projects=await(await request.get('/studio/api/hub/projects')).json(),{csrf}=await(await request.get('/studio/api/session')).json();
  const headers={Origin:origin,'X-CSRF-Token':csrf},title='Learning how to learn';
  const created=await request.post('/studio/api/hub/sources',{headers:{...headers,'Idempotency-Key':crypto.randomUUID()},data:{project_id:projects[0].id,title,kind:'book'}});
  expect(created.status()).toBe(201);const source=await created.json();
  const uploaded=await request.post(`/studio/api/hub/sources/${source.id}/revisions`,{headers:{...headers,'Idempotency-Key':crypto.randomUUID(),'Content-Type':'text/plain','X-Upload-Filename':'learning.txt'},data:Buffer.from(passage)});
  expect(uploaded.status()).toBe(201);const revision=await uploaded.json();
  await expect.poll(async()=>(await(await request.get(`/studio/api/hub/sources/${source.id}/revisions`)).json())[0].state,{timeout:15000}).toBe('ready');
  return{source,revision,title};
}
async function fits(page) {expect(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth)).toBe(true);}
async function screenshot(page,testInfo,name,options={}) {
  // Pixel baselines were reviewed on Linux Chromium 151. Other runners still
  // capture screenshots and execute all interaction/layout checks.
  if(process.env.BRIGHT_VISUAL_BASELINES==='true') await expect(page).toHaveScreenshot(name,{fullPage:true,maxDiffPixelRatio:.005,...options});
  else await page.screenshot({path:testInfo.outputPath(name),fullPage:true,...options});
}
test('reading mode, native fullscreen, fallback and on-demand notes keep the pinned text',async({page,request})=>{
  const f=await fixture(request),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.goto(`/studio/hub/sources/${f.source.id}?revision=${f.revision.id}`);
  await expect(page.locator('#reading-text')).toContainText(passage);
  await expect(page.locator('#evidence-panel')).toBeHidden();
  await page.locator('#reading-mode').focus();await page.keyboard.press('Enter');
  await expect(page.locator('header')).toBeHidden();await expect(page.locator('#navigation')).toBeHidden();
  await expect(page.locator('#reading-mode')).toHaveText('Exit reading mode');
  await page.locator('#notes-open').click();await expect(page.locator('#notes-close')).toBeFocused();
  await page.keyboard.press('Escape');await expect(page.locator('#evidence-panel')).toBeHidden();await expect(page.locator('#notes-open')).toBeFocused();
  await page.keyboard.press('Escape');await expect(page.locator('header')).toBeVisible();
  await page.locator('#reader-fullscreen').click();await expect.poll(()=>page.evaluate(()=>Boolean(document.fullscreenElement))).toBe(true);
  await expect(page.locator('#reader-fullscreen')).toHaveText('Exit fullscreen · Esc');
  await expect(page.locator('#reading-text')).toContainText(passage);
  await page.keyboard.press('Escape');await expect.poll(()=>page.evaluate(()=>Boolean(document.fullscreenElement))).toBe(false);
  await expect(page.locator('header')).toBeVisible();
  await page.locator('#reading-mode').click();await page.locator('#reader-fullscreen').click();
  // A browser/OS exit must restore the activity's previous mode.
  await page.evaluate(()=>document.exitFullscreen());await expect(page.locator('body')).toHaveClass(/focused/);
  await page.locator('#reading-mode').click();
  await page.evaluate(()=>{document.documentElement.requestFullscreen=()=>Promise.reject(new Error('Unavailable'));});
  await page.locator('#reader-fullscreen').click();await expect(page.locator('#mode-status')).toContainText('Distraction-free mode is still available');
  await expect(page.locator('#reading-text')).toContainText(passage);await page.keyboard.press('Escape');
  await fits(page);expect(errors).toEqual([]);
});
test('study picker starts a real revision and mode changes preserve saved answers',async({page,request})=>{
  const f=await fixture(request);await page.goto(`/studio/hub/study/?project=${f.source.project_id}`);
  const card=page.locator('#study-picker .card').filter({hasText:f.title}).first();
  await card.getByRole('button',{name:'Study revision 1',exact:true}).click();
  await expect(page.locator('#study-title')).toHaveText(f.title);
  await expect(page.locator('body')).toHaveClass(/focused/);await expect(page.locator('#study-progress')).toContainText('Revision 1');
  await page.locator('#study-answer').fill('Active');await page.locator('#study-submit').click();
  await expect(page.locator('#study-progress')).toContainText('summary');
  await page.locator('#study-answer').fill('A reflection draft retained while changing display modes.');
  const passUrl=page.url(),passId=new URL(passUrl).searchParams.get('pass');
  await page.route(`**/studio/api/hub/study/${passId}`,route=>route.fulfill({status:503,json:{error:'unavailable'}}));
  await page.locator('#study-reload').click();await expect(page.locator('#study-feedback')).toContainText('Retry the same answer');
  await expect(page.locator('#study-answer')).toHaveValue('A reflection draft retained while changing display modes.');
  await expect(page.locator('#study-mode')).toBeVisible();await page.unroute(`**/studio/api/hub/study/${passId}`);
  await page.locator('#study-mode').click();await expect(page.locator('header')).toBeVisible();
  await page.locator('#study-fullscreen').click();await expect.poll(()=>page.evaluate(()=>Boolean(document.fullscreenElement))).toBe(true);
  await expect(page.locator('#study-answer')).toHaveValue('A reflection draft retained while changing display modes.');
  await page.locator('#study-fullscreen').click();await page.locator('#study-submit').click();
  await expect(page.locator('#study-progress')).toContainText('completed');await expect(page.locator('#lesson-progress')).toHaveJSProperty('value',2);
  await page.reload();await expect(page.locator('#study-summary')).toContainText('retained while changing');
  await page.locator('#study-back').click();await expect(page.locator('header')).toBeVisible();await fits(page);
});
test('approved layouts, screenshots and mobile keyboard navigation',async({page,request},testInfo)=>{
  const f=await fixture(request);
  await page.goto('/studio/login/');await expect(page.locator('#login-form')).toBeVisible();
  await screenshot(page,testInfo,'quiet-signin.png');
  // Keep visual fixtures stable while session/ownership and content still use real APIs.
  await page.route('**/studio/api/hub/sources?*',route=>route.fulfill({json:[f.source]}));
  await page.goto(`/studio/hub/library/?project=${f.source.project_id}`);await expect(page.locator('#sources')).toContainText(f.title);
  await screenshot(page,testInfo,'quiet-library.png',{mask:[page.locator('#account'),page.locator('#project'),page.locator('#status')],maskColor:'#fafaf8'});
  await page.goto(`/studio/hub/?project=${f.source.project_id}`);await expect(page.locator('#continue-reading')).toBeVisible();
  await expect(page.locator('#continue-link')).toHaveAttribute('href',`/studio/hub/sources/${f.source.id}?revision=${f.revision.id}`);
  await expect(page.locator('#overview-study-link')).toHaveAttribute('href',`/studio/hub/study/?source=${f.source.id}&revision=${f.revision.id}`);
  await screenshot(page,testInfo,'quiet-overview.png',{mask:[page.locator('#account'),page.locator('#project'),page.locator('#status')],maskColor:'#fafaf8'});
  await page.goto(`/studio/hub/sources/${f.source.id}`);await expect(page.locator('#reading-text')).toContainText(passage);await page.locator('#reading-mode').click();
  await screenshot(page,testInfo,'quiet-reader.png');
  await page.locator('#study-source').click();await expect(page.locator('#study-title')).toHaveText(f.title);
  await screenshot(page,testInfo,'quiet-study.png');
  await page.keyboard.press('Escape');await navigate(page,'Planner');await expect(page.locator('#planner-date')).not.toHaveValue('');await fits(page);
  if(await page.locator('#navigation-open').isVisible()) {
    await page.locator('#navigation-open').click();await expect(page.locator('#navigation-close')).toBeFocused();
    await page.keyboard.press('Shift+Tab');await expect(page.getByRole('link',{name:'Account',exact:true})).toBeFocused();
    await page.keyboard.press('Tab');await expect(page.locator('#navigation-close')).toBeFocused();
    await page.keyboard.press('Escape');await expect(page.locator('#navigation-open')).toBeFocused();
  }
});
