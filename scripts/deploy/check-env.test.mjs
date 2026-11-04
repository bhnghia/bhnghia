import {test} from 'node:test';
import assert from 'node:assert/strict';
import {checkEnvironment} from './check-env.mjs';
// Structural fixtures only: these are not credentials and never contact a service.
const env={VETT_DEPLOY_ENV:'staging',VETT_APP_ORIGIN:'https://staging.example.test',NEXT_PUBLIC_SUPABASE_URL:'https://stagingref.supabase.co',VETT_EXPECTED_PROJECT_REF:'stagingref',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_fixture',SUPABASE_SERVICE_ROLE_KEY:'sb_secret_fixture'};
test('structural preflight accepts scoped staging and rejects missing configuration',()=>{assert.deepEqual(checkEnvironment(env),[]);assert.ok(checkEnvironment({}).length>0);});
test('preflight rejects wrong project, public secret and production preview',()=>{for(const change of [{VETT_EXPECTED_PROJECT_REF:'productionref'},{NEXT_PUBLIC_BAD_KEY:'sb_secret_fixture'},{VERCEL_ENV:'preview',VETT_DEPLOY_ENV:'production'},{VETT_APP_ORIGIN:'http://staging.example.test'}])assert.ok(checkEnvironment({...env,...change}).length>0);});
