// Only for an isolated acceptance release; never run against hosted/user data.
const {execFileSync}=require('node:child_process'),path=require('node:path');
function expireActiveSession(id) {
  if(!/^[0-9a-f-]{36}$/.test(id))throw Error('Expected a fixture session UUID');
  const release='_build/prod/rel/bright_studio/bin/bright_studio',expression=`bright_sql_pool:with_connection(fun(C)->bright_sql:equery(C,"UPDATE bright_focus_sessions SET running_since_ms=$1 WHERE id=$2 AND state='active'",[${Date.now()-7200001},<<"${id}">>]) end).`;
  const args=['eval',expression],container=process.env.BRIGHT_TEST_DOCKER_CONTAINER;
  const result=container?execFileSync('docker',['exec',container,release,...args],{encoding:'utf8'}):execFileSync(release,args,{cwd:path.resolve(__dirname,'../erlang'),encoding:'utf8'});
  if(!/\{ok,\s*1\}/.test(result))throw Error('Fixture clock was not aged');
}
module.exports={expireActiveSession};
