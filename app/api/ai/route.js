import {createServerSupabase} from '../../../lib/supabase-server';
export async function POST(req){
 try{
  const body=await req.json(); const question=String(body.question||'').trim();
  if(!question||question.length>1000)return Response.json({error:'Enter a question up to 1,000 characters.'},{status:400});
  const supabase=createServerSupabase(); const {data:{user}}=await supabase.auth.getUser();
  if(!user)return Response.json({error:'Sign in required.'},{status:401});
  const {data:m}=await supabase.from('school_memberships').select('school_id,role').eq('user_id',user.id).eq('status','active').order('created_at').limit(1).maybeSingle();
  if(!m)return Response.json({error:'School workspace not found.'},{status:403});
  const sid=m.school_id;
  const count=(table, extra={})=>{let q=supabase.from(table).select('id',{count:'exact',head:true}).eq('school_id',sid);for(const [k,v] of Object.entries(extra))q=q.eq(k,v);return q};
  const [school,students,classes,staff,attendance,results,fees,assignments,exams,applications]=await Promise.all([
   supabase.from('schools').select('name,school_type,status').eq('id',sid).single(), count('students'),count('classes'),count('staff_profiles'),count('attendance_records'),count('results'),count('fee_invoices'),count('assignments'),count('cbt_exams'),count('admission_applications')
  ]);
  const context=`School: ${school.data?.name||'Unknown'} (${school.data?.school_type||'school'})\nStudents: ${students.count||0}\nClasses: ${classes.count||0}\nStaff: ${staff.count||0}\nAttendance records: ${attendance.count||0}\nResult records: ${results.count||0}\nFee invoices: ${fees.count||0}\nAssignments: ${assignments.count||0}\nCBT exams: ${exams.count||0}\nAdmission applications: ${applications.count||0}\nCurrent user role: ${m.role}`;
  if(!process.env.OPENAI_API_KEY)return Response.json({answer:`Edvora AI is ready, but OPENAI_API_KEY is not configured on the server yet. I can already see these school metrics:\n\n${context}`});
  const r=await fetch('https://api.openai.com/v1/responses',{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${process.env.OPENAI_API_KEY}`},body:JSON.stringify({model:process.env.OPENAI_MODEL||'gpt-5-mini',input:`You are Edvora AI, a school operations assistant. Use only the supplied aggregate school context. Never invent individual student records, grades, payments, attendance, or policy. Respect the user's role and say when the supplied context is insufficient. Give concise practical answers.\n\nContext:\n${context}\n\nQuestion:\n${question}`})});
  const j=await r.json();if(!r.ok)throw new Error(j.error?.message||'AI provider error');return Response.json({answer:j.output_text||'No answer returned.'});
 }catch(e){return Response.json({error:e.message||'AI request failed.'},{status:500})}
}
