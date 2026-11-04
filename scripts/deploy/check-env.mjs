import {pathToFileURL} from 'node:url';
export function checkEnvironment(env){
 const errors=[];const required=['VETT_DEPLOY_ENV','VETT_APP_ORIGIN','NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY','SUPABASE_SERVICE_ROLE_KEY'];
 for(const name of required)if(!env[name]?.trim())errors.push(`${name}: missing`);
 const stage=env.VETT_DEPLOY_ENV;
 if(!['local','staging','production'].includes(stage))errors.push('VETT_DEPLOY_ENV: invalid');
 if(env.VERCEL_ENV==='production'&&stage==='local')errors.push('Vercel must not use local configuration');
 if(env.VERCEL_ENV==='preview'&&stage!=='staging')errors.push('Preview must use staging configuration');
 const parse=(name)=>{try{return new URL(env[name]);}catch{errors.push(`${name}: invalid URL`);return null;}};
 const origin=parse('VETT_APP_ORIGIN'),supabase=parse('NEXT_PUBLIC_SUPABASE_URL');
 for(const [name,url] of [['VETT_APP_ORIGIN',origin],['NEXT_PUBLIC_SUPABASE_URL',supabase]]){
  if(!url)continue;
  if(url.username||url.password||url.search||url.hash||!['','/'].includes(url.pathname))errors.push(`${name}: must be an origin without credentials/path/query`);
  const local=['localhost','127.0.0.1','[::1]'].includes(url.hostname);
  if(url.protocol!=='https:'&&!(stage==='local'&&local&&url.protocol==='http:'))errors.push(`${name}: HTTPS required outside local`);
  if(stage!=='local'&&local)errors.push(`${name}: local host outside local`);
 }
 const ref=env.VETT_EXPECTED_PROJECT_REF;
 if(stage!=='local'&&(!ref||supabase?.hostname!==`${ref}.supabase.co`))errors.push('Supabase project does not match independently recorded VETT_EXPECTED_PROJECT_REF');
 const keyCheck=(name,role,prefix)=>{
  const key=env[name]??'';if(key.startsWith(prefix))return;
  try{const parts=key.split('.');if(parts.length!==3)throw new Error();const payload=JSON.parse(Buffer.from(parts[1],'base64url').toString());if(payload.role!==role)throw new Error();if(ref&&payload.ref!==ref)errors.push(`${name}: project reference mismatch`);if(payload.exp&&payload.exp*1000<=Date.now())errors.push(`${name}: expired`);}catch{errors.push(`${name}: wrong key type`);}
 };
 keyCheck('NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY','anon','sb_publishable_');
 keyCheck('SUPABASE_SERVICE_ROLE_KEY','service_role','sb_secret_');
 for(const [name,value] of Object.entries(env))if(name.startsWith('NEXT_PUBLIC_')&&value){
  if(/SECRET|SERVICE_ROLE|PASSWORD|SMTP|DATABASE|TOKEN/.test(name)||value.startsWith('sb_secret_'))errors.push(`${name}: possible secret exposed publicly`);
  try{if(JSON.parse(Buffer.from(value.split('.')[1]??'','base64url').toString()).role==='service_role')errors.push(`${name}: service role exposed publicly`);}catch{}
 }
 return [...new Set(errors)];
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){const errors=checkEnvironment(process.env);for(const error of errors)console.error(error);console.log(errors.length?'BLOCKED: environment preflight failed. Values were not printed.':'PASS: environment structure only; credentials, SMTP and project ownership still require live verification.');process.exitCode=errors.length?1:0;}
