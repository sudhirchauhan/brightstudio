// Run only against a disposable acceptance release/database.
'use strict';
const {spawn,spawnSync}=require('node:child_process'),{openSync}=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),path=require('node:path');
const {expireActiveSession}=require('./focus-fixture-clock');
const base=process.env.BRIGHT_TEST_BASE||'http://127.0.0.1:10000',container=process.env.BRIGHT_TEST_DOCKER_CONTAINER,db=process.env.BRIGHT_TEST_DATABASE_URL;
const release='_build/prod/rel/bright_studio/bin/bright_studio',root=path.resolve(__dirname,'../erlang'),delay=ms=>new Promise(r=>setTimeout(r,ms));
if(container&&!db)throw Error('Set BRIGHT_TEST_DATABASE_URL to the isolated acceptance database for restart checks.');
function command(args){const r=container?spawnSync('docker',['exec',container,release,...args],{encoding:'utf8'}):spawnSync(release,args,{cwd:root,encoding:'utf8'});assert.equal(r.status,0);return r.stdout;}
async function ready(){for(let i=0;i<40;i++){try{if((await fetch(base+'/readyz')).status===200)return;}catch{}await delay(250);}throw Error('Release not ready');}
async function restart(overrides={}){
 command(['stop']);await delay(500);
 const env={STUDIO_HUB_ENABLED:'true',STUDIO_LIBRARY_ENABLED:'true',STUDIO_EVIDENCE_ENABLED:'true',STUDIO_STUDY_ENABLED:'true',STUDIO_WORKSPACE_ENABLED:'true',STUDIO_FOCUS_ENABLED:'true',...(db?{DATABASE_URL:db}:{}),...overrides};
 if(container){const args=['exec','-d'];for(const [k,v]of Object.entries(env))if(v!==undefined)args.push('-e',`${k}=${v}`);args.push(container);const unset=Object.entries(env).filter(([,v])=>v===undefined).map(([k])=>k);if(unset.length)args.push('env',...unset.flatMap(k=>['-u',k]));args.push(release,'foreground');assert.equal(spawnSync('docker',args).status,0);}
 else{const runtime={...process.env,...env};for(const[k,v]of Object.entries(runtime))if(v===undefined)delete runtime[k];const log=openSync('/tmp/bright-focus-restart.log','a'),child=spawn(release,['foreground'],{cwd:root,env:runtime,detached:true,stdio:['ignore',log,log]});child.unref();}
 await ready();
}
(async()=>{
 await ready();const login=await fetch(base+'/studio/api/session/login',{method:'POST',headers:{Origin:base,'Content-Type':'application/json'},body:JSON.stringify({email:'owner-a@example.test',password:'Milestone-test-password-A'})});assert.equal(login.status,200);
 const cookie=login.headers.getSetCookie()[0].split(';')[0],{csrf}=await login.json(),headers={Cookie:cookie,Origin:base,'X-CSRF-Token':csrf,'Content-Type':'application/json'};
 const get=async route=>{const r=await fetch(base+route,{headers});assert.equal(r.status,200);return r.json();};
 const post=async(route,data,key=crypto.randomUUID())=>{const r=await fetch(base+route,{method:'POST',headers:{...headers,'Idempotency-Key':key},body:JSON.stringify(data)});assert.ok([200,201].includes(r.status));return r.json();};
 const projects=await get('/studio/api/hub/projects'),project=projects[0].id,current=(await get(`/studio/api/hub/focus?project_id=${project}`)).current;if(current)await post(`/studio/api/hub/focus/${current.id}/actions`,{action:'cancel',expected_version:current.version});
 const task=await post('/studio/api/workspace/tasks',{title:'Focus restart fixture',project_id:project}),startKey=crypto.randomUUID(),startData={project_id:project,task_id:task.id,minutes:1},s=await post('/studio/api/hub/focus',startData,startKey);
 const route=`/studio/api/hub/focus/${s.id}`,cpKey=crypto.randomUUID(),cpData={action:'checkpoint',expected_version:1,expected_checkpoint:0,note:'I worked on a restart-safe checkpoint.'},cp=await post(route+'/actions',cpData,cpKey);
 await post(route+'/actions',{action:'pause',expected_version:2});const paused=await get(route);await restart();const recovered=await get(route);assert.equal(recovered.state,'paused');assert.equal(recovered.elapsed_ms,paused.elapsed_ms);assert.equal(recovered.checkpoints.length,1);assert.deepEqual(await post('/studio/api/hub/focus',startData,startKey),s);assert.deepEqual(await post(route+'/actions',cpData,cpKey),cp);
 console.log('PASS: paused timer, task link, checkpoint, session cookie and exact start/checkpoint receipts survive full release restart');
 for(const value of ['false',undefined]){await restart({STUDIO_FOCUS_ENABLED:value});for(const p of ['/studio/hub/focus/','/studio/hub/focus.js','/studio/api/hub/focus','/studio/api/hub/focus/targets',route,route+'/actions'])assert.equal((await fetch(base+p,{headers,redirect:'manual'})).status,404);assert.equal((await get('/studio/api/session')).focus_enabled,false);const html=await(await fetch(base+'/studio/hub/',{headers})).text();assert.ok(!html.includes("<script defer src='/studio/hub/focus.js'"));const bundle=await(await fetch(base+'/studio/hub/hub.js',{headers})).text();assert.ok(!bundle.includes('Choose one piece of learning work.'));}
 console.log('PASS: explicit disabled and default-off Focus gate page, script, APIs and navigation while retaining stored sessions');
 await restart({STUDIO_LIBRARY_ENABLED:'false',STUDIO_STUDY_ENABLED:'false',STUDIO_WORKSPACE_ENABLED:'false'});assert.equal((await get(route)).state,'paused');assert.equal((await get(`/studio/api/hub/focus/targets?project_id=${project}`)).tasks.some(t=>t.task_id===task.id),true);
 await post(route+'/actions',{action:'resume',expected_version:3});await restart();const active=await get(route);assert.equal(active.state,'active');assert.ok(active.elapsed_ms>=paused.elapsed_ms);
 expireActiveSession(s.id);const doneKey=crypto.randomUUID(),doneData={action:'complete',expected_version:4,summary:'I retained the session and its learning checkpoint through restarts.'},done=await post(route+'/actions',doneData,doneKey);await restart();const final=await get(route);assert.equal(final.state,'completed');assert.equal(final.elapsed_ms,60000);assert.equal(final.summary,doneData.summary);assert.deepEqual(await post(route+'/actions',doneData,doneKey),done);
 assert.equal((await fetch(route.startsWith('http')?route:base+route)).status,401);const anonymous=await fetch(base+`/studio/hub/focus/?session=${s.id}`,{redirect:'manual'});assert.equal(anonymous.status,302);assert.ok(anonymous.headers.get('location').includes('%2Fstudio%2Fhub%2Ffocus%2F'));
 console.log('PASS: Focus remains independent of Library/Study/Workspace flags; active time and single completed reflection survive restart with exact completion replay and private login return');
})().catch(e=>{console.error(e);process.exitCode=1;});
