"use client";

import { useEffect, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '../../lib/supabase';
import { Logo, EdvoraMark, EdvoraLoader, Icon } from '../../components/Brand';

export default function AcceptInvitation() {
  const params = useSearchParams();
  const token = params.get('token');
  const [status, setStatus] = useState('Verifying invitation…');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        if (!token) throw new Error('Invitation token is missing or invalid.');

        const supabase = createClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          if (active) {
            setStatus('Please sign in with the invited email address to continue.');
            setLoading(false);
          }
          return;
        }

        const r = await fetch('/api/invitations/accept', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token }),
        });
        const j = await r.json();
        if (!r.ok) throw new Error(j.error || 'Failed to accept invitation.');

        if (active) {
          setStatus('Invitation accepted! Directing you to your school workspace…');
          if (j.schoolId && typeof window !== 'undefined') {
            localStorage.setItem('edvora.currentSchoolId', j.schoolId);
          }
          setTimeout(() => window.location.assign('/dashboard'), 800);
        }
      } catch (e) {
        if (active) {
          setError(e.message);
          setStatus('Invitation could not be accepted.');
          setLoading(false);
        }
      }
    })();
    return () => { active = false; };
  }, [token]);

  return (
    <div className="auth-split">
      <section className="auth-hero-pane">
        <div className="auth-hero-content">
          <Logo light />
          <h2 className="auth-hero-title">
            Join your school's team on Edvora.
          </h2>
          <p className="auth-hero-desc">
            Secure collaborative platform for teachers, school administrators, and bursars.
          </p>
        </div>
        <div className="auth-foot-note" style={{ fontSize: '11px', color: 'rgba(255,255,255,0.4)' }}>
          © {new Date().getFullYear()} Edvora Systems.
        </div>
      </section>

      <section className="auth-form-pane">
        <div className="auth-card-box" style={{ textAlign: 'center' }}>
          <div style={{ display: 'inline-flex', alignItems: 'center', gap: '8px', marginBottom: '16px' }}>
            <EdvoraMark size={36} animated={loading} />
          </div>

          <h1 style={{ fontFamily: 'Sora, sans-serif', fontSize: '24px', color: '#0b1f3b', margin: '0 0 8px' }}>
            {status}
          </h1>

          {error ? (
            <div className="notice error" role="alert" style={{ textAlign: 'left', marginTop: '16px' }}>
              {error}
            </div>
          ) : loading ? (
            <div style={{ margin: '24px 0' }}>
              <EdvoraLoader label="Activating your membership…" size={40} />
            </div>
          ) : (
            <p style={{ color: '#64748b', fontSize: '13px', lineHeight: 1.6, margin: '16px 0 24px' }}>
              Invitations expire after seven days. If you haven't signed in yet, click below to log in.
            </p>
          )}

          <div style={{ marginTop: '24px', display: 'flex', justifyContent: 'center', gap: '10px' }}>
            <Link className="auth-submit-btn" style={{ width: 'auto', padding: '0 24px' }} href={`/login?next=${encodeURIComponent(`/accept-invitation?token=${token || ''}`)}`}>
              <span>Go to login</span>
              <Icon name="arrow" size={16} />
            </Link>
          </div>
        </div>
      </section>
    </div>
  );
}
