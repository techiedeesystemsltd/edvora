import { chromium } from 'playwright';

const baseUrl=(process.env.EDVORA_BASE_URL||'').replace(/\/$/,'');
if(!baseUrl){console.error('Set EDVORA_BASE_URL, e.g. https://your-edvora.vercel.app');process.exit(2)}
const email=process.env.EDVORA_E2E_EMAIL;
const password=process.env.EDVORA_E2E_PASSWORD;
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1440,height:1000}});
const checks=[];
const check=async(name,fn)=>{try{await fn();checks.push(`PASS: ${name}`)}catch(e){checks.push(`FAIL: ${name} — ${e.message}`);throw e}};
try{
  await check('login page loads',async()=>{const r=await page.goto(`${baseUrl}/login`,{waitUntil:'domcontentloaded'});if(!r||r.status()>=400)throw new Error(`HTTP ${r?.status()}`);await page.locator('input[type="email"]').waitFor()});
  await check('signup page loads',async()=>{const r=await page.goto(`${baseUrl}/signup`,{waitUntil:'domcontentloaded'});if(!r||r.status()>=400)throw new Error(`HTTP ${r?.status()}`);await page.locator('input[type="email"]').waitFor()});
  if(email&&password){
    await page.goto(`${baseUrl}/login`,{waitUntil:'networkidle'});
    await page.locator('input[type="email"]').fill(email);
    await page.locator('input[type="password"]').fill(password);
    await page.locator('button[type="submit"]').click();
    await page.waitForLoadState('networkidle').catch(()=>{});
    await check('authenticated session reaches app',async()=>{if(!/^\/((onboarding|dashboard|student|parent|teacher|admin)|$)/.test(new URL(page.url()).pathname))throw new Error(`unexpected route ${new URL(page.url()).pathname}`)});
    await page.goto(`${baseUrl}/onboarding`,{waitUntil:'networkidle'});
    const ownership=page.locator('select[aria-label="School ownership"]');
    if(await ownership.count()){
      await check('ownership dropdown has four required choices',async()=>{
        const labels=await ownership.locator('option').allTextContents();
        for(const x of ['Private school','Federal government school','State government school','Other public school'])if(!labels.includes(x))throw new Error(`missing ${x}`);
      });
    }
  }
  console.log(checks.join('\n'));
  if(!email) console.log('Authenticated E2E steps skipped; set EDVORA_E2E_EMAIL and EDVORA_E2E_PASSWORD to run them.');
}catch(e){console.error(checks.join('\n'));console.error(e?.stack||e);process.exitCode=1}finally{await browser.close()}
