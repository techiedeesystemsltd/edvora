import { createClient } from '@supabase/supabase-js';
import crypto from 'node:crypto';

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
if (!url || !serviceKey || !anonKey) {
  console.error('V22 live test requires NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (or NEXT_PUBLIC_SUPABASE_ANON_KEY), and SUPABASE_SERVICE_ROLE_KEY.');
  process.exit(2);
}

const admin = createClient(url, serviceKey, {auth:{autoRefreshToken:false,persistSession:false}});
const password = `EdvoraV22!${crypto.randomBytes(12).toString('hex')}`;
const suffix = crypto.randomUUID().slice(0,8);
const users = {};
const schools = [];

async function createUser(role) {
  const email = `edvora-v22-${role}-${suffix}@example.invalid`;
  const {data,error} = await admin.auth.admin.createUser({email,password,email_confirm:true});
  if (error) throw error;
  users[role] = {id:data.user.id,email};
}
async function signIn(role) {
  const c = createClient(url, anonKey, {auth:{persistSession:false,autoRefreshToken:false}});
  const {data,error} = await c.auth.signInWithPassword({email:users[role].email,password});
  if (error) throw error;
  return c;
}
async function must(promise,label){
  const {data,error}=await promise;
  if(error) throw new Error(`${label}: ${error.message}`);
  return data;
}
async function assert(cond,msg){ if(!cond) throw new Error(`ASSERTION FAILED: ${msg}`); }

try {
  for (const role of ['parentA','studentA','parentB','studentB']) await createUser(role);
  const parentA = await signIn('parentA');
  const parentB = await signIn('parentB');
  const studentA = await signIn('studentA');
  const studentB = await signIn('studentB');

  // School creation RPC + ownership/level validation through the real authenticated API path.
  const schoolA = await must(parentA.rpc('create_school_v22', {
    school_name:`V22 Live Test A ${suffix}`,
    school_ownership:'Private school',
    school_levels:['primary','jss'],
    school_timezone:'Africa/Lagos', school_address:'', school_phone:'', academic_year:'2026/2027'
  }), 'create school A');
  schools.push(schoolA);
  const schoolB = await must(parentB.rpc('create_school_v22', {
    school_name:`V22 Live Test B ${suffix}`,
    school_ownership:'State government school',
    school_levels:['sss'],
    school_timezone:'Africa/Lagos', school_address:'', school_phone:'', academic_year:'2026/2027'
  }), 'create school B');
  schools.push(schoolB);

  // Invalid school level must be rejected by the DB, not just the browser/API.
  const bad = await parentA.rpc('create_school_v22', {
    school_name:`Should Fail ${suffix}`, school_ownership:'private_school', school_levels:['bogus'], school_timezone:'Africa/Lagos'
  });
  assert(bad.error, 'invalid school level was accepted by create_school_v22');

  const clsA = crypto.randomUUID(), clsB = crypto.randomUUID();
  const sessionA = crypto.randomUUID(), termA = crypto.randomUUID();
  const subjectA = crypto.randomUUID(), studentIdA = crypto.randomUUID(), studentIdB = crypto.randomUUID();
  await must(admin.from('classes').insert([{id:clsA,school_id:schoolA,name:`V22 Test Class ${suffix}`},{id:clsB,school_id:schoolB,name:`V22 Test Class B ${suffix}`}]),'insert classes');
  await must(admin.from('academic_sessions').insert({id:sessionA,school_id:schoolA,name:`2026/2027 ${suffix}`}),'insert session');
  await must(admin.from('academic_terms').insert({id:termA,school_id:schoolA,session_id:sessionA,name:`First Term ${suffix}`}),'insert term');
  await must(admin.from('subjects').insert({id:subjectA,school_id:schoolA,name:`Mathematics ${suffix}`}),'insert subject');
  await must(admin.from('students').insert([
    {id:studentIdA,school_id:schoolA,class_id:clsA,first_name:'Tenant',last_name:'A'},
    {id:studentIdB,school_id:schoolB,class_id:clsB,first_name:'Tenant',last_name:'B'}
  ]),'insert students');
  await must(admin.from('student_guardians').insert([
    {school_id:schoolA,student_id:studentIdA,user_id:users.parentA.id,relationship:'Parent'},
    {school_id:schoolB,student_id:studentIdB,user_id:users.parentB.id,relationship:'Parent'}
  ]),'insert guardians');
  await must(admin.from('student_accounts').insert([
    {school_id:schoolA,student_id:studentIdA,user_id:users.studentA.id,status:'active'},
    {school_id:schoolB,student_id:studentIdB,user_id:users.studentB.id,status:'active'}
  ]),'insert student accounts');
  await must(admin.from('student_term_results').insert({school_id:schoolA,student_id:studentIdA,session_id:sessionA,term_id:termA,subject_id:subjectA,total:87,ca_percent:38,exam_percent:92,grade:'A',status:'published'}),'insert result');

  // Parent sees own tenant's published result.
  const ownParentRows = await must(parentA.from('student_term_results').select('id').eq('school_id',schoolA).eq('student_id',studentIdA),'parent own result');
  assert(ownParentRows.length===1,'linked parent could not read own published result');
  // Student must be blocked until a linked parent reviews it.
  const beforeReview = await must(studentA.from('student_term_results').select('id').eq('school_id',schoolA).eq('student_id',studentIdA),'student before review');
  assert(beforeReview.length===0,'student could read result before parent review');
  await must(parentA.rpc('review_student_result',{target_student:studentIdA,target_session:sessionA,target_term:termA}),'review result');
  const afterReview = await must(studentA.from('student_term_results').select('id').eq('school_id',schoolA).eq('student_id',studentIdA),'student after review');
  assert(afterReview.length===1,'student could not read result after parent review');
  // Cross-tenant isolation.
  const crossParent = await must(parentB.from('student_term_results').select('id').eq('school_id',schoolA).eq('student_id',studentIdA),'cross-tenant parent query');
  assert(crossParent.length===0,'parent from school B can read school A result');
  const crossStudent = await must(studentB.from('student_term_results').select('id').eq('school_id',schoolA).eq('student_id',studentIdA),'cross-tenant student query');
  assert(crossStudent.length===0,'student from school B can read school A result');

  // CBT: future start must fail, active start must succeed, end must be server-enforced.
  const examFuture = crypto.randomUUID();
  const questionFuture = crypto.randomUUID();
  await must(admin.from('cbt_exams').insert({id:examFuture,school_id:schoolA,class_id:clsA,subject_id:subjectA,title:`Future CBT ${suffix}`,duration_minutes:10,starts_at:new Date(Date.now()+10*60*1000).toISOString(),ends_at:new Date(Date.now()+20*60*1000).toISOString(),status:'scheduled',created_by:users.parentA.id}),'insert future exam');
  await must(admin.from('cbt_questions').insert({id:questionFuture,school_id:schoolA,exam_id:examFuture,question_text:'2+2?',correct_answer:'4',points:1,position:1}),'insert future question');
  const early = await studentA.rpc('start_student_cbt_attempt',{target_exam_id:examFuture});
  assert(early.error,'CBT allowed a start before starts_at');

  await must(admin.from('cbt_exams').update({starts_at:new Date(Date.now()-60*1000).toISOString(),ends_at:new Date(Date.now()+10*60*1000).toISOString(),status:'live'}).eq('id',examFuture),'activate exam');
  const attemptId = await must(studentA.rpc('start_student_cbt_attempt',{target_exam_id:examFuture}),'start CBT');
  const attempt = await must(admin.from('cbt_attempts').select('server_expires_at,status').eq('id',attemptId).single(),'read attempt');
  assert(attempt.status==='in_progress','CBT attempt did not start in progress');
  assert(new Date(attempt.server_expires_at).getTime()>Date.now(),'server expiry was not set in the future');

  await must(admin.from('cbt_exams').update({ends_at:new Date(Date.now()-1000).toISOString()}).eq('id',examFuture),'force CBT end');
  const saveAfterEnd = await studentA.rpc('save_student_cbt_answer',{target_attempt_id:attemptId,target_question_id:questionFuture,target_answer:'4'});
  assert(saveAfterEnd.error,'CBT accepted an answer after server-side exam end');
  const attemptAfter = await must(admin.from('cbt_attempts').select('status').eq('id',attemptId).single(),'read expired attempt');
  assert(attemptAfter.status==='expired','expired CBT attempt was not marked expired');

  console.log('V22 LIVE TEST: PASS');
  console.log('PASS: school ownership + DB school-level validation');
  console.log('PASS: parent-first result release');
  console.log('PASS: cross-tenant parent/student result isolation');
  console.log('PASS: CBT server start/end enforcement');
} catch (e) {
  console.error('V22 LIVE TEST: FAIL');
  console.error(e?.stack || e);
  process.exitCode=1;
} finally {
  for (const id of schools) await admin.from('schools').delete().eq('id',id);
  for (const role of Object.keys(users)) await admin.auth.admin.deleteUser(users[role].id);
}
