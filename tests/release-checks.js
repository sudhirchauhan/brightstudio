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
    const args = ['exec','-d'];
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
  const login = await fetch(`${base}/studio/api/session/login`,{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({email:'owner-a@example.test',password:'Milestone-test-password-A'})});
  assert.equal(login.status,200);
  const cookie = login.headers.getSetCookie()[0].split(';')[0]; const {csrf} = await login.json();
  const projects = await (await fetch(`${base}/studio/api/hub/projects`,{headers:{Cookie:cookie}})).json();
  const creation = await fetch(`${base}/studio/api/hub/sources`,{method:'POST',headers:{Origin:base,Cookie:cookie,'X-CSRF-Token':csrf,'Content-Type':'application/json','Idempotency-Key':crypto.randomUUID()},body:JSON.stringify({project_id:projects[0].id,title:'Survives full release restart',kind:'note'})});
  assert.equal(creation.status,201); const source = await creation.json();
  await stop(); await start();
  const reopened = await fetch(`${base}/studio/api/hub/sources/${source.id}`,{headers:{Cookie:cookie}});
  assert.equal(reopened.status,200); assert.deepEqual(await reopened.json(),source);
  console.log('PASS: source and session survive full release restart');
  await stop(); await start({STUDIO_HUB_ENABLED:'false'});
  for(const route of ['/studio/login/','/studio/login.js','/studio/hub.css','/studio/hub/','/studio/hub/hub.js','/studio/api/session','/studio/api/hub/sources']) {
    assert.equal((await fetch(`${base}${route}`,{headers:{Cookie:cookie}})).status,404);
  }
  console.log('PASS: disabled flag gates UI, assets and APIs');
  await stop(); await start({DATABASE_URL:undefined},503);
  assert.equal((await fetch(`${base}/studio/api/hub/sources`,{method:'POST',headers:{Cookie:cookie,Origin:base,'X-CSRF-Token':csrf,'Content-Type':'application/json'},body:'{}'})).status,503);
  console.log('PASS: missing database preserves liveness, readiness fails, write never reports success');
  await stop(); await start({BRIGHT_ROLE:'worker'},null);
  assert.match(command(['ping']),/pong/);
  let listener = false; try { await fetch(`${base}/healthz`); listener=true; } catch {}
  assert.equal(listener,false);
  console.log('PASS: worker release runs without HTTP listener');
  await stop(); await start();
  assert.equal((await fetch(`${base}/studio/api/hub/sources/${source.id}`,{headers:{Cookie:cookie}})).status,200);
  console.log('PASS: enabled web release restored and durable source retained');
})().catch(error=>{console.error(error.message);process.exitCode=1;});
