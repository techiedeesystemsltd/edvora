import { createServerSupabase } from './supabase-server';
import { createAdminClient } from './supabase-admin';

/**
 * Validates authenticated user session from server cookies.
 * Throws 401 if unauthenticated.
 */
export async function getAuthenticatedUser() {
  const supabase = createServerSupabase();
  const { data: { user }, error } = await supabase.auth.getUser();
  if (error || !user) {
    const err = new Error('Authentication required. Please sign in.');
    err.status = 401;
    throw err;
  }
  return { supabase, user };
}

/**
 * Validates that the authenticated user holds an active membership for target school
 * and optionally validates allowed roles.
 */
export async function requireSchoolMembership(schoolId, allowedRoles = []) {
  if (!schoolId) {
    const err = new Error('School identifier is required.');
    err.status = 400;
    throw err;
  }

  const { supabase, user } = await getAuthenticatedUser();

  const { data: membership, error } = await supabase
    .from('school_memberships')
    .select('id, school_id, role, status, created_at, schools(id, name, slug, logo_path, currency, timezone, status)')
    .eq('school_id', schoolId)
    .eq('user_id', user.id)
    .eq('status', 'active')
    .maybeSingle();

  if (error || !membership) {
    const err = new Error('Unauthorized: You do not have an active membership in this school.');
    err.status = 403;
    throw err;
  }

  if (allowedRoles.length > 0 && !allowedRoles.includes(membership.role)) {
    const err = new Error(`Forbidden: Role '${membership.role}' is not authorized for this operation.`);
    err.status = 403;
    throw err;
  }

  return {
    supabase,
    user,
    membership,
    school: membership.schools,
    schoolId: membership.school_id,
    role: membership.role
  };
}

/**
 * Validates that the authenticated user is a Platform Super Admin.
 */
export async function requirePlatformSuperAdmin() {
  const { supabase, user } = await getAuthenticatedUser();
  const { data: admin, error } = await supabase
    .from('platform_admins')
    .select('user_id')
    .eq('user_id', user.id)
    .maybeSingle();

  if (error || !admin) {
    const err = new Error('Forbidden: Platform Super Admin privileges required.');
    err.status = 403;
    throw err;
  }

  return { supabase, user };
}
