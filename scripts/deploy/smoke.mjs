import assert from 'node:assert/strict';
const base=new URL(process.env.SMOKE_BASE_URL??'http://localhost:3000');
assert.ok(base.protocol==='https:'||['localhost','127.0.0.1'].includes(base.hostname),'HTTPS required for remote smoke');
assert.ok(!base.username&&!base.password&&!base.search&&!base.hash&&base.pathname==='/','Use origin only');
for(const route of ['/','/login','/register','/forgot-password']){
 const r=await fetch(new URL(route,base),{redirect:'manual',signal:AbortSignal.timeout(15000)});
 assert.equal(r.status,200,`${route} status`);assert.match(r.headers.get('content-type')??'',/text\/html/);
 assert.equal(r.headers.get('x-content-type-options'),'nosniff');assert.equal(r.headers.get('x-frame-options'),'DENY');
 assert.match(await r.text(),/V\.E\.T\.T/);console.log(`PASS ${route}`);
}
if(!process.argv.includes('--public-only'))for(const route of ['/candidate','/organization','/notifications','/safety']){
 const r=await fetch(new URL(route,base),{redirect:'manual',signal:AbortSignal.timeout(15000)});
 assert.ok([303,307].includes(r.status),`${route} must redirect anonymous user`);
 assert.equal(new URL(r.headers.get('location'),base).pathname,'/login');console.log(`PASS anonymous ${route}`);
}
console.log('Smoke checks passed; no authenticated session, email delivery or database write was exercised.');
