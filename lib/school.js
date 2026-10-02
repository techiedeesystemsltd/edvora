import { createClient } from './supabase';

export async function getCurrentContext() {
  const supabase = createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) throw new Error('Please sign in again.');
  const urlParamSchoolId = typeof window !== 'undefined' ? new URLSearchParams(window.location.search).get('school') : null;
  const preferredSchoolId = urlParamSchoolId || (typeof window !== 'undefined' ? window.localStorage.getItem('edvora.currentSchoolId') : null);
  const membershipBase = () => supabase
    .from('school_memberships')
    .select('id, school_id, role, status, created_at, schools(id,name,slug,logo_path,currency,timezone,status)')
    .eq('user_id', user.id)
    .eq('status', 'active');

  let membership = null;
  if (preferredSchoolId) {
    const { data, error } = await membershipBase().eq('school_id', preferredSchoolId).maybeSingle();
    if (error) throw error;
    membership = data;
  }

  // If preferredSchoolId from stale localStorage didn't belong to this user, check their active memberships
  if (!membership) {
    const { data, error } = await membershipBase().order('created_at', { ascending: false }).limit(1).maybeSingle();
    if (error) throw error;
    membership = data;
  }

  if (membership) {
    if (typeof window !== 'undefined') window.localStorage.setItem('edvora.currentSchoolId', membership.school_id);
    const { data: allMemberships } = await supabase
      .from('school_memberships')
      .select('school_id, role, schools(id,name,slug,logo_path)')
      .eq('user_id', user.id)
      .eq('status', 'active');
    return {
      supabase,
      user,
      membership,
      school: membership.schools,
      schoolId: membership.school_id,
      role: membership.role,
      availableSchools: (allMemberships || []).map(m => ({ id: m.school_id, role: m.role, name: m.schools?.name || 'School' }))
    };
  }

  const { data: guardian } = await supabase.from('student_guardians').select('school_id,students(id,schools(id,name,slug,currency,status))').eq('user_id',user.id).limit(1).maybeSingle();
  if (guardian?.school_id) return { supabase, user, membership:null, school:guardian.students?.schools, schoolId:guardian.school_id, role:'parent', studentId:guardian.students?.id };
  const { data: studentAccount } = await supabase.from('student_accounts').select('school_id,student_id,students(id,schools(id,name,slug,currency,status))').eq('user_id',user.id).eq('status','active').limit(1).maybeSingle();
  if (studentAccount?.school_id) return { supabase, user, membership:null, school:studentAccount.students?.schools, schoolId:studentAccount.school_id, role:'student', studentId:studentAccount.student_id };

  if (typeof window !== 'undefined') {
    window.localStorage.removeItem('edvora.currentSchoolId');
    window.location.assign('/onboarding');
  }
  throw new Error('No active Edvora school or portal account was found. Redirecting to school onboarding…');
}

export function switchSchool(schoolId) {
  if (typeof window !== 'undefined' && schoolId) {
    window.localStorage.setItem('edvora.currentSchoolId', schoolId);
    window.location.assign(`/dashboard?school=${encodeURIComponent(schoolId)}`);
  }
}


export function canManage(role, area) {
  if (role === 'owner') return true;
  if (area === 'finance') return ['admin','bursar'].includes(role);
  if (area === 'settings') return role === 'admin';
  if (area === 'staff') return ['admin'].includes(role);
  return ['admin','teacher','staff'].includes(role);
}

export function money(value, currency='NGN') {
  return new Intl.NumberFormat('en-NG', { style:'currency', currency, maximumFractionDigits:0 }).format(Number(value || 0));
}
