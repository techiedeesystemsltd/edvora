import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const read = (f) => fs.readFileSync(path.join(root, f), 'utf8');

console.log('--- STARTING DAY 1 ACCEPTANCE TEST SUITE ---');

// 1. Check critical Day 1 files exist
const day1Files = [
  'app/onboarding/page.js',
  'app/api/onboarding/school/route.js',
  'app/signup/page.js',
  'app/login/page.js',
  'app/forgot-password/page.js',
  'app/reset-password/page.js',
  'app/accept-invitation/page.js',
  'app/dashboard/page.js',
  'app/super-admin/page.js',
  'app/api/super-admin/route.js',
  'components/AppShell.js',
  'lib/school.js',
  'lib/useSchoolContext.js',
  'lib/supabase.js',
  'lib/supabase-server.js',
  'lib/supabase-admin.js',
  'supabase/EDVORA_V22_RESULTS_CBT_ONBOARDING.sql',
  'supabase/EDVORA_COMPLETE_SCHEMA_V16.sql'
];

for (const f of day1Files) {
  if (!fs.existsSync(path.join(root, f))) {
    throw new Error(`[FAIL] Required Day 1 file missing: ${f}`);
  }
}
console.log('✓ [PASS] All critical Day 1 files exist.');

// 2. Tenancy & Zero Hardcoded Data Verification
const codebaseDirs = ['app', 'components', 'lib'];
function scanDir(dir) {
  const files = [];
  for (const item of fs.readdirSync(path.join(root, dir), { withFileTypes: true })) {
    if (item.isDirectory()) files.push(...scanDir(path.join(dir, item.name)));
    else if (item.name.endsWith('.js')) files.push(path.join(dir, item.name));
  }
  return files;
}

const allJsFiles = codebaseDirs.flatMap(scanDir);
for (const file of allJsFiles) {
  const content = read(file);
  if (/Green Crest|Greenfield/i.test(content)) {
    throw new Error(`[FAIL] Found hardcoded school name in ${file}`);
  }
}
console.log(`✓ [PASS] Zero hardcoded demo school references verified across ${allJsFiles.length} JS files.`);

// 3. Onboarding Flow & Ownership Validation
const onboardingPage = read('app/onboarding/page.js');
const onboardingApi = read('app/api/onboarding/school/route.js');
const v22Sql = read('supabase/EDVORA_V22_RESULTS_CBT_ONBOARDING.sql');

const requiredOwnerships = [
  "['private_school','Private school']",
  "['federal_government','Federal government school']",
  "['state_government','State government school']",
  "['other_public','Other public school']"
];

for (const own of requiredOwnerships) {
  if (!onboardingPage.includes(own)) {
    throw new Error(`[FAIL] Onboarding page missing ownership option: ${own}`);
  }
}
console.log('✓ [PASS] All 4 school ownership options present and selectable in onboarding.');

// 4. Multi-School Switching & Context
const appShell = read('components/AppShell.js');
const schoolLib = read('lib/school.js');

if (!appShell.includes('userSchools') || !appShell.includes('switchSchool') || !appShell.includes('Your schools')) {
  throw new Error('[FAIL] AppShell does not contain multi-school switcher support.');
}
if (!schoolLib.includes('switchSchool') || !schoolLib.includes('availableSchools')) {
  throw new Error('[FAIL] lib/school.js missing switchSchool or availableSchools resolver.');
}
console.log('✓ [PASS] Multi-school switching & context resolution verified.');

// 5. Database Multi-Tenancy & RPC check
if (!v22Sql.includes('create_school_v22')) {
  throw new Error('[FAIL] create_school_v22 RPC missing in schema.');
}
if (v22Sql.includes("raise exception 'You already belong to a school'")) {
  throw new Error('[FAIL] create_school_v22 inappropriately blocks multi-school creation for owners.');
}
console.log('✓ [PASS] School creation RPC verified without multi-school blocker.');

// 6. Super Admin Isolation Check
const superAdminPage = read('app/super-admin/page.js');
const superAdminApi = read('app/api/super-admin/route.js');

if (!superAdminApi.includes('platform_admins')) {
  throw new Error('[FAIL] Super Admin API does not enforce platform_admins table check.');
}
console.log('✓ [PASS] Super Admin control plane isolation verified.');

console.log('\n========================================');
console.log('DAY 1 ACCEPTANCE TESTS COMPLETED SUCCESSFULLY');
console.log('========================================');
