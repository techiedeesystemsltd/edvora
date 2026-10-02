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
    const name=String(body.name||'').trim();
    const level=String(body.level||'').trim()||null;
    if(!schoolId||!name) return NextResponse.json({error:'School and class name are required.'},{status:400});
    const {data:membership,error:membershipError}=await auth.from('school_memberships').select('role').eq('school_id',schoolId).eq('user_id',user.id).eq('status','active').maybeSingle();
    if(membershipError) throw membershipError;
    if(!membership||!['owner','admin'].includes(membership.role)) return NextResponse.json({error:'Only a school owner or admin can create classes.'},{status:403});
    const admin=createAdminClient();
    const {data:existing,error:existingError}=await admin.from('classes').select('id').eq('school_id',schoolId).ilike('name',name).maybeSingle();
    if(existingError) throw existingError;
    if(existing) return NextResponse.json({error:'A class with this name already exists in this school.'},{status:409});
    const {data,error}=await admin.from('classes').insert({school_id:schoolId,name,level}).select().single();
    if(error) throw error;
    return NextResponse.json({success:true,class:data});
  }catch(error){
    const message=error?.code==='23505'?'A class with this name already exists in this school.':error?.message||'Unable to create class.';
    return NextResponse.json({error:message},{status:500});
  }
}
