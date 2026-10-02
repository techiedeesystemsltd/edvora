import { NextResponse } from 'next/server';
import { createServerSupabase } from '../../../lib/supabase-server';

export async function GET(request) {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get('code');
  const next = requestUrl.searchParams.get('next') || '/dashboard';
  const safeNext = next.startsWith('/') && !next.startsWith('//') ? next : '/dashboard';

  if (code) {
    try {
      const supabase = createServerSupabase();
      const { error } = await supabase.auth.exchangeCodeForSession(code);
      if (!error) return NextResponse.redirect(new URL(safeNext, requestUrl.origin));
    } catch (error) {
      console.error('[auth/callback]', error);
    }
  }

  return NextResponse.redirect(new URL(`/login?error=${encodeURIComponent('The confirmation link is invalid or has expired. Please request a new one.')}`, requestUrl.origin));
}
