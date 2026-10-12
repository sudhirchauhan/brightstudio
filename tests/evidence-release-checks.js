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
  const get=async route=>{const response=await fetch(base+route,{headers});assert.equal(response.status,200);return response.json();};
  const post=async(route,data)=>{const response=await fetch(base+route,{method:'POST',headers:{...headers,'Idempotency-Key':crypto.randomUUID()},body:JSON.stringify(data)});assert.ok([200,201].includes(response.status));return response.json();};
  const projects=await get('/studio/api/hub/projects');
  const source=await post('/studio/api/hub/sources',{title:'Evidence restart acceptance',project_id:projects[0].id});
  const uploaded=await fetch(`${base}/studio/api/hub/sources/${source.id}/revisions`,{method:'POST',headers:{...headers,'Content-Type':'text/plain','X-Upload-Filename':'evidence.txt','Idempotency-Key':crypto.randomUUID()},body:'A durable pinned quote.'});assert.equal(uploaded.status,201);const revision=await uploaded.json();
  for(let i=0;i<60;i++){const list=await get(`/studio/api/hub/sources/${source.id}/revisions`);if(list[0].state==='ready')break;await delay(250);}
  const evidence=await post('/studio/api/hub/evidence',{source_id:source.id,revision_id:revision.id,start_byte:0,end_byte:23,quote:'A durable pinned quote.',note:'Original note'});
  const board=await post('/studio/api/hub/boards',{project_id:projects[0].id,title:'Restart board'});
  await post(`/studio/api/hub/boards/${board.id}/links`,{evidence_id:evidence.id});
  await post(`/studio/api/hub/evidence/${evidence.id}/notes`,{expected_version:1,note:'Note after edit'});
  await stop();await start();
  const reopened=await get(`/studio/api/hub/evidence/${evidence.id}`);assert.equal(reopened.version,2);assert.equal(reopened.note,'Note after edit');assert.equal(reopened.anchor_state,'resolved');assert.equal(reopened.revision_id,revision.id);
  assert.equal((await get(`/studio/api/hub/boards/${board.id}`)).items[0].id,evidence.id);
  assert.equal((await get(`/studio/api/hub/evidence/${evidence.id}/notes`)).length,2);
  console.log('PASS: pinned quote, note history, board links and session survive full web restart');
  await stop();await start({STUDIO_EVIDENCE_ENABLED:'false'});
  for(const route of ['/studio/hub/evidence/','/studio/hub/evidence.js','/studio/api/hub/evidence',`/studio/api/hub/evidence/${evidence.id}`,`/studio/api/hub/evidence/${evidence.id}/notes`,'/studio/api/hub/boards',`/studio/api/hub/boards/${board.id}`,`/studio/api/hub/boards/${board.id}/links`])assert.equal((await fetch(base+route,{headers})).status,404);
  assert.equal((await get('/studio/api/session')).evidence_enabled,false);
  const html=await(await fetch(`${base}/studio/hub/sources/${source.id}`,{headers})).text();assert.ok(!html.includes("<script defer src='/studio/hub/evidence.js'"));
  assert.equal((await get(`/studio/api/hub/sources/${source.id}/revisions/${revision.id}/content`)).text,'A durable pinned quote.');
  console.log('PASS: disabled evidence gates pages, assets and APIs; Library reading remains available');
  await stop();await start();assert.equal((await get(`/studio/api/hub/evidence/${evidence.id}`)).version,2);
  console.log('PASS: re-enabling evidence retains all durable records');
})().catch(error=>{console.error(error);process.exitCode=1;});
