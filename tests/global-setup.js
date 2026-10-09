const {request} = require('@playwright/test');
const {mkdirSync,chmodSync} = require('node:fs');
module.exports = async () => {
  const baseURL = process.env.BRIGHT_TEST_BASE || 'http://127.0.0.1:10000';
  mkdirSync('playwright/.auth',{recursive:true});
  for(const owner of ['a','b']) {
    const context = await request.newContext({baseURL});
    const response = await context.post('/studio/api/session/login',{headers:{Origin:baseURL},data:{email:`owner-${owner}@example.test`,password:`Milestone-test-password-${owner.toUpperCase()}`}});
    if(response.status()!==200) throw new Error(`Acceptance owner ${owner} login returned ${response.status()}; start a fresh local release before repeating the full suite.`);
    const file=`playwright/.auth/${owner}.json`; await context.storageState({path:file}); chmodSync(file,0o600); await context.dispose();
  }
};
