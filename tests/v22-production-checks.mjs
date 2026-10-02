import fs from 'node:fs';
import path from 'node:path';
import {execFileSync} from 'node:child_process';

const root=process.cwd();
const read=(f)=>fs.readFileSync(path.join(root,f),'utf8');
const required=[
  'app/onboarding/page.js',
  'app/api/onboarding/school/route.js',
  'app/parent/page.js',
  'app/student/page.js',
  'app/student/cbt/[examId]/page.js',
  'supabase/EDVORA_V22_RESULTS_CBT_ONBOARDING.sql',
  'scripts/v22-live-test.mjs'
];
for(const f of required)if(!fs.existsSync(path.join(root,f)))throw new Error(`Missing ${f}`);

const onboarding=read('app/onboarding/page.js');
for(const x of [
  "['private_school','Private school']",
  "['federal_government','Federal government school']",
  "['state_government','State government school']",
  "['other_public','Other public school']"
])if(!onboarding.includes(x))throw new Error(`Ownership option missing: ${x}`);

const api=read('app/api/onboarding/school/route.js');
for(const x of ['create_school_v22','allowedLevels','nursery','primary','secondary','jss','sss','normalizedLevelValues'])if(!api.includes(x))throw new Error(`Onboarding API missing ${x}`);
if(!onboarding.includes("const levelOptions=[['nursery','Nursery'],['primary','Primary'],['secondary','Secondary']]"))throw new Error('Onboarding level choices are not Nursery/Primary/Secondary');
if(!onboarding.includes('step===1')||!onboarding.includes('Step {step+1} of {steps.length}'))throw new Error('Onboarding level step missing');
if(/<select required value=\{ownership\}/.test(onboarding))throw new Error('Ownership is still implemented as a dropdown');
if(/\.rpc\([^\n]+\)\.catch\(/.test(api))throw new Error('Onboarding RPC still chains .catch() directly on rpc()');

const sql=read('supabase/EDVORA_V22_RESULTS_CBT_ONBOARDING.sql');
for(const x of [
  "schools_ownership_check_v22",
  "school_levels text[]",
  "parent_result_reviews",
  "review_student_result",
  "result_has_any_parent_review",
  "status in ('published','locked')",
  "server_expires_at",
  "start_student_cbt_attempt",
  "save_student_cbt_answer",
  "submit_student_cbt_attempt",
  "create_school_v22",
  "'nursery','primary','jss','sss'",
  "when 'secondary' then 'jss'",
  "status not in ('published','locked')"
])if(!sql.includes(x))throw new Error(`V22 SQL missing ${x}`);

const cbt=read('app/student/cbt/[examId]/page.js');
for(const x of ['start_student_cbt_attempt','save_student_cbt_answer','submit_student_cbt_attempt','server_expires_at','fullscreenchange','visibilitychange'])if(!cbt.includes(x))throw new Error(`CBT UI missing ${x}`);

const parent=read('app/parent/page.js');
for(const x of ['review_student_result','parent_result_reviews','Result','reviewed'])if(!parent.includes(x))throw new Error(`Parent result review flow missing ${x}`);

execFileSync(process.execPath,['scripts/v18-syntax-check.mjs'],{stdio:'inherit'});
console.log('Edvora V22 static checks passed. Live Supabase/E2E tests are available through scripts/v22-live-test.mjs.');
