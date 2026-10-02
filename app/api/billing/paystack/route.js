import { NextResponse } from 'next/server';
import { createServerSupabase } from '../../../../lib/supabase-server';
const planEnv=(code,cycle)=>`PAYSTACK_PLAN_${String(code).toUpperCase()}_${String(cycle).toUpperCase()}`;
export async function POST(req){
 try{
  const supabase=createServerSupabase();const {data:{user}}=await supabase.auth.getUser();if(!user)return NextResponse.json({error:'Unauthorized'},{status:401});
  const body=await req.json();const requestedSchoolId=String(body.school_id||'');const plan=String(body.plan_code||'');const cycle=body.cycle==='yearly'?'yearly':'monthly';
  const {data:m,error:me}=await supabase.from('school_memberships').select('school_id,role,schools(name)').eq('user_id',user.id).eq('status','active').eq('school_id',requestedSchoolId).limit(1).maybeSingle();if(me)throw me;if(!m||!['owner','admin'].includes(m.role))return NextResponse.json({error:'Only a school owner or admin can manage billing.'},{status:403});
  const {data:p,error:pe}=await supabase.from('subscription_plans').select('*').eq('code',plan).eq('active',true).maybeSingle();if(pe)throw pe;if(!p)return NextResponse.json({error:'Plan not found.'},{status:404});
  if(!process.env.PAYSTACK_SECRET_KEY)return NextResponse.json({error:'Paystack is not configured.'},{status:503});
  const providerPlan=process.env[planEnv(plan,cycle)];
  if(!providerPlan)return NextResponse.json({error:`Recurring billing is not configured for ${p.name} ${cycle}. Add ${planEnv(plan,cycle)} in Vercel using the matching Paystack plan code.`},{status:503});
  const reference=`edvora_sub_${m.school_id}_${Date.now()}`;
  const response=await fetch('https://api.paystack.co/transaction/initialize',{method:'POST',headers:{Authorization:`Bearer ${process.env.PAYSTACK_SECRET_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({email:user.email,amount:Math.round(Number(cycle==='yearly'?p.yearly_amount:p.monthly_amount)*100),plan:providerPlan,reference,metadata:{school_id:m.school_id,plan_code:plan,cycle,kind:'edvora_subscription'}})});
  const json=await response.json();if(!response.ok||!json.status)return NextResponse.json({error:json.message||'Unable to initialize Paystack.'},{status:502});
  return NextResponse.json({authorization_url:json.data.authorization_url,reference:json.data.reference});
 }catch(e){return NextResponse.json({error:e.message||'Billing initialization failed.'},{status:500})}
}
