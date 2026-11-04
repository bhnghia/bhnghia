import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import {mkdir} from 'node:fs/promises';
const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const base='http://127.0.0.1:3119';
const server=spawn(process.execPath,['node_modules/next/dist/bin/next','start','-p','3119'],{stdio:['ignore','pipe','pipe']});
let output='';server.stdout.on('data',c=>output+=c);server.stderr.on('data',c=>output+=c);
let browser;
try{
 let ready=false;for(let i=0;i<60;i++){try{if((await fetch(base)).ok){ready=true;break;}}catch{}await new Promise(r=>setTimeout(r,500));}assert.ok(ready,output);
 browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox']});
 await mkdir('/tmp/vett-qa-screenshots',{recursive:true});let checks=0;
 for(const width of [375,768,1440]){const page=await browser.newPage({viewport:{width,height:900}});
  for(const route of ['/','/login','/register','/forgot-password']){const response=await page.goto(base+route);assert.equal(response.status(),200);await page.locator('h1').first().waitFor();assert.ok(await page.locator('body').innerText());assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),`overflow ${route} ${width}`);await page.screenshot({path:`/tmp/vett-qa-screenshots/${width}-${route.replaceAll('/','')||'home'}.png`});checks++;}
  await page.goto(base+'/login');const email=page.locator('input[type=email]');await email.fill('invalid');assert.equal(await email.evaluate(el=>el.checkValidity()),false);checks++;
  await page.goto(base+'/auth/confirm?token_hash=bad&type=unrecognized');assert.ok(page.url().includes('/login?error=confirmation'));checks++;
  await page.close();
 }
 for(const route of ['/api/candidate/cv','/api/organization/logo']){const r=await fetch(base+route,{method:'POST',headers:{origin:'https://attacker.invalid'}});assert.equal(r.status,403);checks++;}
 console.log(`PASS ${checks} public browser/HTTP checks; widths 375/768/1440. Authenticated journeys NOT executed.`);
}finally{await browser?.close();server.kill('SIGTERM');}
