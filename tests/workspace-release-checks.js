// Exercise the built release. Run only against a disposable acceptance environment.
'use strict';
const {spawn,spawnSync} = require('node:child_process');
const {openSync} = require('node:fs');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const path = require('node:path');
const base = process.env.BRIGHT_TEST_BASE || 'http://127.0.0.1:10000';
const container = process.env.BRIGHT_TEST_DOCKER_CONTAINER;
const root = path.resolve(__dirname,'../erlang');
const release = '_build/prod/rel/bright_studio/bin/bright_studio';
const delay = ms => new Promise(resolve=>setTimeout(resolve,ms));
function command(args) {
  const result = container ? spawnSync('docker',['exec',container,release,...args],{encoding:'utf8'}) : spawnSync(release,args,{cwd:root,encoding:'utf8'});
  assert.equal(result.status,0,`Release ${args[0]} failed`); return result.stdout;
}
async function waitReady(expected = 200) {
  for(let i=0;i<40;i++) {
    try { if((await fetch(`${base}/healthz`)).status===200 && (await fetch(`${base}/readyz`)).status===expected) return; } catch {}
    await delay(250);
  }
  throw new Error(`Release did not become ready (expected ${expected})`);
}
async function stop() { command(['stop']); await delay(500); }
async function start(overrides = {},ready = 200) {
  if(container) {
    const args = ['exec','-d','-e','STUDIO_LIBRARY_ENABLED=true','-e','STUDIO_EVIDENCE_ENABLED=true','-e','STUDIO_STUDY_ENABLED=true','-e','STUDIO_WORKSPACE_ENABLED=true'];
    for(const [key,value] of Object.entries(overrides)) if(value!==undefined) args.push('-e',`${key}=${value}`);
    args.push(container);
    const unset = Object.entries(overrides).filter(([,v])=>v===undefined).map(([k])=>k);
    if(unset.length) args.push('env',...unset.flatMap(k=>['-u',k]));
    args.push(release,'foreground');
    assert.equal(spawnSync('docker',args).status,0,'Release start failed');
  } else {
    const env = {...process.env,...overrides}; for(const [key,value] of Object.entries(env)) if(value===undefined) delete env[key];
    const log = openSync('/tmp/bright-release-checks.log','a');
    const child = spawn(release,['foreground'],{cwd:root,env,detached:true,stdio:['ignore',log,log]}); child.unref();
  }
  if(ready!==null) await waitReady(ready); else await delay(1500);
}
(async()=>{
  await waitReady();
  const login=await fetch(`${base}/studio/api/session/login`,{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({email:'owner-a@example.test',password:'Milestone-test-password-A'})});assert.equal(login.status,200);
  const cookie=login.headers.getSetCookie()[0].split(';')[0],{csrf}=await login.json(),headers={Cookie:cookie,Origin:base,'X-CSRF-Token':csrf,'Content-Type':'application/json'};
  const get=async route=>{const r=await fetch(base+route,{headers});assert.equal(r.status,200);return r.json();};
  const post=async(route,data,key=crypto.randomUUID())=>{const r=await fetch(base+route,{method:'POST',headers:{...headers,'Idempotency-Key':key},body:JSON.stringify(data)});assert.ok([200,201].includes(r.status));return r.json();};
  const p=await post('/studio/api/workspace/projects',{title:'Workspace restart acceptance'}),data={project_id:p.id,title:'A restart-safe task',scheduled_date:'2026-03-29',due_date:'2026-03-30',priority:1,estimate_minutes:45},key=crypto.randomUUID();
  const t=await post('/studio/api/workspace/tasks',data,key);
  const profile=await get('/studio/api/workspace/account');await post('/studio/api/workspace/account',{expected_version:profile.version,display_name:'Restart reader',timezone:'Europe/Zurich'});
  await stop();await start();
  assert.deepEqual(await post('/studio/api/workspace/tasks',data,key),t);assert.equal((await get(`/studio/api/workspace/tasks/${t.id}`)).scheduled_date,'2026-03-29');assert.equal((await get('/studio/api/workspace/account')).timezone,'Europe/Zurich');
  console.log('PASS: project, task civil dates, profile timezone, session and exact creation receipt survive full release restart');
  await post(`/studio/api/workspace/tasks/${t.id}`,{...data,state:'done',expected_version:1});await stop();await start();assert.equal((await get(`/studio/api/workspace/tasks/${t.id}`)).state,'done');
  console.log('PASS: completed task survives restart');
  await stop();await start({STUDIO_WORKSPACE_ENABLED:'false'});
  for(const route of ['/studio/hub/projects/','/studio/hub/tasks/','/studio/hub/planner/','/studio/hub/account/','/studio/hub/workspace.js','/studio/api/workspace/projects',`/studio/api/workspace/projects/${p.id}`,'/studio/api/workspace/tasks',`/studio/api/workspace/tasks/${t.id}`,'/studio/api/workspace/account','/studio/api/workspace/password'])assert.equal((await fetch(base+route,{headers,redirect:'manual'})).status,404);
  assert.equal((await get('/studio/api/session')).workspace_enabled,false);
  const html=await(await fetch(`${base}/studio/hub/`,{headers})).text();assert.ok(!html.includes("<script defer src='/studio/hub/workspace.js'"));
  console.log('PASS: disabled workspace gates all pages, script and APIs without changing existing Hub project access');
  await stop();await start();assert.equal((await get(`/studio/api/workspace/tasks/${t.id}`)).state,'done');
  for(const route of ['projects','tasks','planner','account'])assert.equal((await fetch(`${base}/studio/hub/${route}/`,{redirect:'manual'})).status,302);
  assert.equal((await fetch(`${base}/studio/api/workspace/tasks/${t.id}`)).status,401);
  const latest=await get('/studio/api/workspace/account');await post('/studio/api/workspace/account',{expected_version:latest.version,display_name:profile.display_name,timezone:profile.timezone});
  console.log('PASS: re-enablement preserves data; anonymous pages redirect to login while APIs remain private');
})().catch(e=>{console.error(e.message);process.exitCode=1;});
