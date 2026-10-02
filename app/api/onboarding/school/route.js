import {NextResponse} from 'next/server';
import {createServerSupabase} from '../../../../lib/supabase-server';

export async function POST(request){
  try{
    const supabase=createServerSupabase();
    const {data:{user},error:authError}=await supabase.auth.getUser();
    if(authError||!user)return NextResponse.json({error:'Your session has expired. Please sign in again.'},{status:401});
    const body=await request.json().catch(()=>({}));
    const name=String(body.name||'').trim();
    const rawOwnership=String(body.ownership||body.type||body.schoolOwnership||body.school_type||'').trim().toLowerCase();
    const ownershipAliases={
      private:'private_school','private school':'private_school','private_school':'private_school',
      federal:'federal_government','federal government':'federal_government','federal government school':'federal_government','federal_government':'federal_government',
      state:'state_government','state government':'state_government','state government school':'state_government','state_government':'state_government',
      public:'other_public','other public':'other_public','other public school':'other_public','other_public':'other_public'
    };
    const ownership=ownershipAliases[rawOwnership]||'';
    const levels=Array.isArray(body.levels)?body.levels.map(v=>String(v).trim().toLowerCase()).filter(Boolean):[];
    const normalizedLevelValues=[];
    for(const level of levels){
      if(level==='secondary'){normalizedLevelValues.push('jss','sss');}
      else normalizedLevelValues.push(level);
    }
    const allowedLevels=new Set(['nursery','primary','jss','sss']);
    const normalizedLevels=[...new Set(normalizedLevelValues)];
    const timezone=String(body.timezone||'Africa/Lagos').trim();
    const address=String(body.address||'').trim();
    const phone=String(body.phone||'').trim();
    const academicYear=String(body.academicYear||'').trim();
    if(!name)return NextResponse.json({error:'School name is required.'},{status:400});
    if(!['private_school','federal_government','state_government','other_public'].includes(ownership))return NextResponse.json({error:'Select a valid school ownership type.'},{status:400});
    if(!normalizedLevels.length)return NextResponse.json({error:'Select at least one school level.'},{status:400});
    if(normalizedLevels.some(level=>!allowedLevels.has(level)))return NextResponse.json({error:'Select valid school levels: Nursery, Primary, or Secondary.'},{status:400});
    const {data:schoolId,error}=await supabase.rpc('create_school_v22',{
      school_name:name,school_ownership:ownership,school_levels:normalizedLevels,school_timezone:timezone,
      school_address:address,school_phone:phone,academic_year:academicYear
    });
    if(error)throw error;
    return NextResponse.json({schoolId,redirect:`/dashboard?school=${encodeURIComponent(schoolId)}`});
  }catch(error){
    return NextResponse.json({error:error?.message||'Unable to create your school workspace.'},{status:500});
  }
}
