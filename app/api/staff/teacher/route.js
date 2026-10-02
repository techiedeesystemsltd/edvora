import {NextResponse} from 'next/server';
import crypto from 'crypto';
import {createServerSupabase} from '../../../../lib/supabase-server';
import {createAdminClient} from '../../../../lib/supabase-admin';

export async function POST(request){
  try{
    const auth=createServerSupabase();
    const {data:{user}}=await auth.auth.getUser();
    if(!user)return NextResponse.json({error:'Your session has expired. Please sign in again.'},{status:401});
    const body=await request.json().catch(()=>({}));
    const schoolId=String(body.school_id||'');
    const fullName=String(body.full_name||'').trim();
    const email=String(body.email||'').trim().toLowerCase();
    if(!schoolId||!fullName)return NextResponse.json({error:'School and teacher name are required.'},{status:400});
    const {data:membership,error:membershipError}=await auth.from('school_memberships').select('school_id,role').eq('school_id',schoolId).eq('user_id',user.id).eq('status','active').maybeSingle();
    if(membershipError)throw membershipError;
    if(!membership||!['owner','admin'].includes(membership.role))return NextResponse.json({error:'Only a school owner or admin can add teachers.'},{status:403});
    const admin=createAdminClient();
    const {data:existing,error:existingError}=email?await admin.from('staff_profiles').select('id').eq('school_id',schoolId).ilike('email',email).maybeSingle():{data:null,error:null};
    if(existingError)throw existingError;
    let profile;
    if(existing){
      const {data,error}=await admin.from('staff_profiles').update({full_name:fullName,phone:String(body.phone||'').trim()||null,employee_number:String(body.employee_number||'').trim()||null,department:String(body.department||'').trim()||null,staff_type:'teacher',status:'invited',updated_at:new Date().toISOString()}).eq('id',existing.id).select().single();
      if(error)throw error; profile=data;
    }else{
      const {data,error}=await admin.from('staff_profiles').insert({school_id:schoolId,full_name:fullName,email:email||null,phone:String(body.phone||'').trim()||null,employee_number:String(body.employee_number||'').trim()||null,department:String(body.department||'').trim()||null,staff_type:'teacher',status:email?'invited':'active'}).select().single();
      if(error)throw error; profile=data;
    }
    let invitation=null;
    if(email){
      const token=crypto.randomBytes(32).toString('hex');
      const tokenHash=crypto.createHash('sha256').update(token).digest('hex');
      const {error}=await admin.from('school_invitations').insert({school_id:schoolId,email,role:'teacher',token_hash:tokenHash,invited_by:user.id,expires_at:new Date(Date.now()+7*86400000).toISOString()});
      if(error)throw error;
      const base=process.env.NEXT_PUBLIC_APP_URL||'http://localhost:3000';
      invitation={link:`${base}/accept-invitation?token=${token}`};
      if(process.env.RESEND_API_KEY&&process.env.EMAIL_FROM){
        const school=await admin.from('schools').select('name').eq('id',schoolId).maybeSingle();
        const schoolName=school.data?.name||'your school';
        const mail=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:`Bearer ${process.env.RESEND_API_KEY}`,'Content-Type':'application/json'},body:JSON.stringify({from:process.env.EMAIL_FROM,to:[email],subject:`Invitation to ${schoolName} on Edvora`,html:`<p>Hello ${fullName},</p><p>You have been invited to join ${schoolName} on Edvora as a teacher.</p><p><a href=\"${invitation.link}\">Accept your invitation</a></p><p>This invitation expires in 7 days.</p>`})});
        invitation.emailed=mail.ok;
      }else invitation.emailed=false;
    }
    return NextResponse.json({success:true,profile,invitation});
  }catch(error){return NextResponse.json({error:error?.message||'Unable to add teacher.'},{status:500});}
}
