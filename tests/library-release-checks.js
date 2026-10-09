// Run against a disposable acceptance environment with the web and worker releases.
'use strict';
const {spawn,spawnSync}=require('node:child_process');
const {openSync}=require('node:fs');
const path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const base=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000';
const root=path.resolve(__dirname,'../erlang'),release='_build/prod/rel/bright_studio/bin/bright_studio';
const containers={web:process.env.BRIGHT_TEST_DOCKER_CONTAINER,worker:process.env.BRIGHT_TEST_WORKER_CONTAINER};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
function env(role,enabled){return {...process.env,BRIGHT_ROLE:role,STUDIO_LIBRARY_ENABLED:String(enabled),...(role==='worker'?{VMARGS_PATH:path.join(root,'config/worker.vm.args')}:{})};}
function command(role,args){
  const result=containers[role]?spawnSync('docker',['exec',...(role==='worker'?['-e','VMARGS_PATH=/app/config/worker.vm.args']:[]),containers[role],release,...args],{encoding:'utf8'}):spawnSync(release,args,{cwd:root,env:env(role,true),encoding:'utf8'});
  assert.equal(result.status,0,`${role} ${args[0]} failed`);return result.stdout;
}
async function start(role,enabled=true){
  if(containers[role]) assert.equal(spawnSync('docker',['exec','-d','-e',`BRIGHT_ROLE=${role}`,'-e',`STUDIO_LIBRARY_ENABLED=${enabled}`,...(role==='worker'?['-e','VMARGS_PATH=/app/config/worker.vm.args']:[]),containers[role],release,'foreground']).status,0);
  else {const log=openSync(`/tmp/bright-${role}-checks.log`,'a');const child=spawn(release,['foreground'],{cwd:root,env:env(role,enabled),detached:true,stdio:['ignore',log,log]});child.unref();}
  for(let i=0;i<40;i++){
    await delay(250);
    if(role==='web'){try{if((await fetch(`${base}/readyz`)).status===200)return;}catch{}}
    else {try{if(command(role,['ping']).includes('pong'))return;}catch{}}
  }throw Error(`${role} not ready`);
}
async function stop(role){command(role,['stop']);await delay(500);}
(async()=>{
  const login=await fetch(`${base}/studio/api/session/login`,{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({email:'owner-a@example.test',password:'Milestone-test-password-A'})});assert.equal(login.status,200);
  const cookie=login.headers.getSetCookie()[0].split(';')[0],{csrf}=await login.json();
  const headers={Cookie:cookie,Origin:base,'X-CSRF-Token':csrf};
  const projects=await(await fetch(`${base}/studio/api/hub/projects`,{headers})).json();
  const created=await fetch(`${base}/studio/api/hub/sources`,{method:'POST',headers:{...headers,'Content-Type':'application/json','Idempotency-Key':crypto.randomUUID()},body:JSON.stringify({title:'Durable worker acceptance',kind:'book',project_id:projects[0].id})});assert.equal(created.status,201);const source=await created.json();
  const route=`${base}/studio/api/hub/sources/${source.id}/revisions`,original=Buffer.from('Durable private text after both roles restart.');
  await stop('worker');
  const upload=await fetch(route,{method:'POST',headers:{...headers,'Content-Type':'text/plain','X-Upload-Filename':'durable.txt','Idempotency-Key':crypto.randomUUID()},body:original});assert.equal(upload.status,201);const revision=await upload.json();
  const state=async()=>{const list=await(await fetch(route,{headers})).json();return list.find(r=>r.id===revision.id).state;};
  assert.equal(await state(),'queued');
  await stop('web');await start('web');await start('worker',false);await delay(1200);assert.equal(await state(),'queued');
  console.log('PASS: queued revision and session survive restart; disabled worker does not claim');
  await stop('worker');await start('worker');
  for(let i=0;i<60&&await state()!=='ready';i++)await delay(250);assert.equal(await state(),'ready');
  await stop('web');await stop('worker');await start('web');await start('worker');
  const download=await fetch(`${route}/${revision.id}/original`,{headers});assert.equal(download.status,200);assert.deepEqual(Buffer.from(await download.arrayBuffer()),original);
  const content=await fetch(`${route}/${revision.id}/content`,{headers});assert.equal(content.status,200);assert.equal((await content.json()).text,original.toString());
  console.log('PASS: private original and extracted text survive web and worker restart');
  await stop('web');await start('web',false);
  for(const suffix of ['',`/${revision.id}/original`,`/${revision.id}/content`])assert.equal((await fetch(route+suffix,{headers})).status,404);
  assert.equal((await fetch(`${base}/studio/api/hub/sources/${source.id}`,{headers})).status,200);
  assert.equal((await(await fetch(`${base}/studio/api/session`,{headers})).json()).library_enabled,false);
  console.log('PASS: library flag gates file APIs while metadata remains available');
  await stop('web');await start('web');
})().catch(error=>{console.error(error);process.exitCode=1;});
