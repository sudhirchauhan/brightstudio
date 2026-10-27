// Only the disposable local acceptance release; never a hosted/user database.
const {request}=require('@playwright/test'),assert=require('node:assert/strict'),{execFileSync}=require('node:child_process'),fs=require('node:fs');
const container=process.env.BRIGHT_TEST_DOCKER_CONTAINER;assert.equal(container,'bright-sqlite-dev');const release='_build/prod/rel/bright_studio/bin/bright_studio';
const rpc=code=>execFileSync('docker',['exec',container,release,'eval',code],{encoding:'utf8'});
(async()=>{
 const db=fs.readFileSync('erlang/_build/latest-acceptance-database.txt','utf8').trim();assert.match(db,/^sqlite:\/app\/_build\/acceptance-[0-9]+\.sqlite$/);assert.ok(rpc('os:getenv("DATABASE_URL").').includes(db));
 const context=await request.newContext({baseURL:'http://127.0.0.1:10000',storageState:'playwright/.auth/a.json'});
 try{
  assert.equal((await context.get('/studio/hub/pdfjs/pdf.mjs')).status(),200);
  rpc('os:putenv("STUDIO_LIBRARY_ENABLED","false").');
  for(const url of ['/studio/hub/pdfjs/pdf.mjs','/studio/hub/pdfjs/pdf.worker.mjs','/studio/api/hub/sources/00000000-0000-0000-0000-000000000000/revisions/00000000-0000-0000-0000-000000000000/book'])assert.equal((await context.get(url)).status(),404);
  console.log('PASS Library disabled gates formatted EPUB and PDF assets');
 }finally{rpc('os:putenv("STUDIO_LIBRARY_ENABLED","true").');await context.dispose();}
})().catch(e=>{console.error(e.message);process.exitCode=1;});
