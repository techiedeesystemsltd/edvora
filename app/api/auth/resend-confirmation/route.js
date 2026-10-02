import { NextResponse } from 'next/server';
import { createServerSupabase } from '../../../../lib/supabase-server';

export async function POST(request) {
  try {
    const { email } = await request.json();
    if (!email || typeof email !== 'string') return NextResponse.json({ error: 'Email is required.' }, { status: 400 });

    const origin = request.headers.get('origin') || request.nextUrl.origin;
    const supabase = createServerSupabase();
    const { error } = await supabase.auth.resend({
      type: 'signup',
      email: email.trim(),
      options: { emailRedirectTo: `${origin}/auth/callback?next=/onboarding` }
    });

    // Do not reveal whether an account exists.
    if (error) console.error('[auth/resend-confirmation]', error.message);
    return NextResponse.json({ ok: true, message: 'If that account needs confirmation, a new confirmation email has been sent.' });
  } catch (error) {
    console.error('[auth/resend-confirmation]', error);
    return NextResponse.json({ error: 'We could not send the confirmation email right now. Please try again.' }, { status: 500 });
  }
}
