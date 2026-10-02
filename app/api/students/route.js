import {NextResponse} from 'next/server';
import {createServerSupabase} from '../../../lib/supabase-server';
import {createAdminClient} from '../../../lib/supabase-admin';

export async function POST(request){
  try{
    const auth=createServerSupabase();
    const {data:{user}}=await auth.auth.getUser();
    if(!user) return NextResponse.json({error:'Your session has expired. Please sign in again.'},{status:401});
    const body=await request.json().catch(()=>({}));
    const schoolId=String(body.school_id||'');
    const firstName=String(body.first_name||'').trim();
    const lastName=String(body.last_name||'').trim();
    if(!schoolId||!firstName||!lastName) return NextResponse.json({error:'School, first name and last name are required.'},{status:400});
    const {data:membership,error:membershipError}=await auth.from('school_memberships').select('role').eq('school_id',schoolId).eq('user_id',user.id).eq('status','active').maybeSingle();
    if(membershipError) throw membershipError;
    if(!membership||!['owner','admin'].includes(membership.role)) return NextResponse.json({error:'Only a school owner or admin can add students.'},{status:403});
    const admin=createAdminClient();
    const {data:created,error}=await admin.from('students').insert({
      school_id:schoolId,
      first_name:firstName,
      last_name:lastName,
      gender:String(body.gender||'').trim()||null,
      class_id:String(body.class_id||'').trim()||null,
      date_of_birth:String(body.date_of_birth||'').trim()||null
    }).select().single();
    if(error) throw error;
    if(created?.class_id){
      const {data:session}=await admin.from('academic_sessions').select('id').eq('school_id',schoolId).eq('is_current',true).maybeSingle();
      await admin.from('student_enrollments').insert({school_id:schoolId,student_id:created.id,class_id:created.class_id,session_id:session?.id||null,is_current:true});
    }
    return NextResponse.json({success:true,student:created});
  }catch(error){
    return NextResponse.json({error:error?.message||'Unable to create student.'},{status:500});
  }
}
