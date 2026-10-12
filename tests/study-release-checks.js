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
    const args = ['exec','-d','-e','STUDIO_LIBRARY_ENABLED=true','-e','STUDIO_EVIDENCE_ENABLED=true','-e','STUDIO_STUDY_ENABLED=true'];
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
  const projects=await get('/studio/api/hub/projects');
  const source=await post('/studio/api/hub/sources',{title:'Study restart acceptance',project_id:projects[0].id});
  const upload=await fetch(`${base}/studio/api/hub/sources/${source.id}/revisions`,{method:'POST',headers:{...headers,'Content-Type':'text/plain','X-Upload-Filename':'study.txt','Idempotency-Key':crypto.randomUUID()},body:'Learning '.repeat(80)+'Practice saves progress.'});assert.equal(upload.status,201);const revision=await upload.json();
  for(let i=0;i<60;i++){if((await get(`/studio/api/hub/sources/${source.id}/revisions`))[0].state==='ready')break;await delay(250);}
  const pass=await post('/studio/api/hub/study',{source_id:source.id,revision_id:revision.id});
  const key=crypto.randomUUID(),data={expected_version:1,step:0,kind:'answer',answer:'Learning'};
  const receipt=await post(`/studio/api/hub/study/${pass.id}/attempts`,data,key);
  await stop();await start();
  const resumed=await get(`/studio/api/hub/study/${pass.id}`);assert.equal(resumed.step,1);assert.equal(resumed.version,2);assert.equal(resumed.revision_id,revision.id);
  assert.deepEqual(await post(`/studio/api/hub/study/${pass.id}/attempts`,data,key),receipt);
  console.log('PASS: Study checkpoint, pinned revision, session and exact attempt replay survive full release restart');
  await stop();await start({STUDIO_STUDY_ENABLED:'false'});
  for(const route of ['/studio/hub/study/','/studio/hub/study.js','/studio/api/hub/study',`/studio/api/hub/study/${pass.id}`,`/studio/api/hub/study/${pass.id}/attempts`])assert.equal((await fetch(base+route,{headers,redirect:'manual'})).status,404);
  assert.equal((await get('/studio/api/session')).study_enabled,false);
  const html=await(await fetch(`${base}/studio/hub/`,{headers})).text();assert.ok(!html.includes("<script defer src='/studio/hub/study.js'"));
  console.log('PASS: disabled Study gates page, script, APIs and navigation without deleting progress');
  await stop();await start({STUDIO_LIBRARY_ENABLED:'false'});
  assert.equal((await fetch(`${base}/studio/api/hub/study/${pass.id}`,{headers})).status,404);
  console.log('PASS: disabled Library also gates its dependent Study workflow');
  await stop();await start();
  assert.equal((await get(`/studio/api/hub/study/${pass.id}`)).step,1);
  const second=await post(`/studio/api/hub/study/${pass.id}/attempts`,{expected_version:2,step:1,kind:'answer',answer:'Practice'});assert.equal(second.pass.state,'summary');
  await post(`/studio/api/hub/study/${pass.id}/attempts`,{expected_version:3,step:2,kind:'summary',answer:'I will practice recalling important passages each day.'});
  await stop();await start();assert.equal((await get(`/studio/api/hub/study/${pass.id}`)).state,'completed');
  const anonymous=await fetch(`${base}/studio/hub/study/?pass=${pass.id}`,{redirect:'manual'});assert.equal(anonymous.status,302);assert.ok(anonymous.headers.get('location').startsWith('/studio/login/?next='));
  assert.equal((await fetch(`${base}/studio/api/hub/study/${pass.id}`)).status,401);
  console.log('PASS: completed reflection survives restart; signed-out Study redirects to login while API remains private');
})().catch(error=>{console.error(error);process.exitCode=1;});
