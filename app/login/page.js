"use client";

import Link from 'next/link';
import { useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { createClient } from '../../lib/supabase';
import { Logo, EdvoraMark, Icon } from '../../components/Brand';

export default function Login() {
  const params = useSearchParams();
  const next = params.get('next') || '/dashboard';
  const confirmed = params.get('confirmed') === '1';
  const confirmedEmail = params.get('email') || '';
  const callbackError = params.get('error') || '';

  const [email, setEmail] = useState(confirmedEmail);
  const [password, setPassword] = useState('');
  const [error, setError] = useState(callbackError);
  const [loading, setLoading] = useState(false);
  const [resending, setResending] = useState(false);
  const [resent, setResent] = useState(false);
  const [resendCooldown, setResendCooldown] = useState(0);

  async function resend() {
    if (resendCooldown > 0 || resending || !email.trim()) return;
    setResending(true);
    setResent(false);
    try {
      const r = await fetch('/api/auth/resend-confirmation', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email.trim() }),
      });
      const data = await r.json();
      if (!r.ok) throw new Error(data.error || 'Unable to resend confirmation email.');
      setResent(true);
      setResendCooldown(60);
      const timer = window.setInterval(() => {
        setResendCooldown((v) => {
          if (v <= 1) {
            window.clearInterval(timer);
            return 0;
          }
          return v - 1;
        });
      }, 1000);
    } catch (err) {
      setError(err.message);
    } finally {
      setResending(false);
    }
  }

  async function submit(e) {
    e.preventDefault();
    setError('');
    setLoading(true);
    try {
      const supabase = createClient();
      const { error: authError } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      });
      if (authError) throw authError;

      // Clean local storage if switching or logging in
      if (typeof window !== 'undefined') {
        const target = next.startsWith('/') ? next : '/dashboard';
        window.location.assign(target);
      }
    } catch (err) {
      setError(err?.message || 'Unable to sign in. Please verify your email and password.');
      setLoading(false);
    }
  }

  return (
    <div className="auth-split">
      {/* Left Brand Showcase Pane */}
      <section className="auth-hero-pane">
        <div className="auth-hero-content">
          <Logo light />
          <h2 className="auth-hero-title">
            Smart infrastructure for modern African schools.
          </h2>
          <p className="auth-hero-desc">
            Connect students, teachers, academics, attendance, examinations, and payments into one calm, unified operating workspace.
          </p>

          <div className="auth-feature-list">
            <div className="auth-feature-pill">
              <EdvoraMark size={20} />
              <span>Multi-level school architecture (Nursery, Primary, Secondary)</span>
            </div>
            <div className="auth-feature-pill">
              <EdvoraMark size={20} />
              <span>Nigerian grading system (WAEC A1-F9 standard)</span>
            </div>
            <div className="auth-feature-pill">
              <EdvoraMark size={20} />
              <span>Instant CBT exams & automated result computation</span>
            </div>
          </div>
        </div>

        <div className="auth-foot-note" style={{ fontSize: '11px', color: 'rgba(255,255,255,0.4)', marginTop: '24px' }}>
          © {new Date().getFullYear()} Edvora Systems. Built with pride for African education.
        </div>
      </section>

      {/* Right Form Pane */}
      <section className="auth-form-pane">
        <div className="auth-card-box">
          <div className="auth-header">
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <EdvoraMark size={32} />
              <strong style={{ fontSize: '18px', color: '#0b1f3b', fontWeight: 800 }}>Edvora</strong>
            </div>
            <h1>Welcome back</h1>
            <p>Sign in to your school workspace.</p>
          </div>

          {confirmed && (
            <div className="notice" style={{ background: '#eff6ff', color: '#1e40af', border: '1px solid #bfdbfe' }}>
              Check your email to confirm your Edvora account. If it hasn't arrived, check Spam/Junk or resend below.
            </div>
          )}

          {resent && (
            <div className="notice success">
              A new confirmation email has been requested.
            </div>
          )}

          {error && (
            <div className="notice error" role="alert">
              {error}
            </div>
          )}

          <form onSubmit={submit} className="auth-form">
            <div className="auth-input-group">
              <label htmlFor="email">Email address</label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                required
                className="auth-input-field"
                placeholder="name@school.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>

            <div className="auth-input-group">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '6px' }}>
                <label htmlFor="password" style={{ margin: 0 }}>Password</label>
                <Link
                  href={`/forgot-password?email=${encodeURIComponent(email)}`}
                  style={{ fontSize: '12px', color: '#2563eb', fontWeight: 600 }}
                >
                  Forgot password?
                </Link>
              </div>
              <input
                id="password"
                type="password"
                autoComplete="current-password"
                required
                className="auth-input-field"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>

            <button type="submit" className="auth-submit-btn" disabled={loading}>
              {loading ? (
                <>
                  <EdvoraMark size={16} animated={true} />
                  <span>Signing in…</span>
                </>
              ) : (
                <>
                  <span>Sign in</span>
                  <Icon name="arrow" size={16} />
                </>
              )}
            </button>
          </form>

          {confirmed && (
            <div style={{ textAlign: 'center', marginTop: '16px' }}>
              <button
                type="button"
                className="auth-inline-button"
                onClick={resend}
                disabled={resending || resendCooldown > 0 || !email}
              >
                {resending
                  ? 'Sending…'
                  : resendCooldown > 0
                  ? `Resend available in ${resendCooldown}s`
                  : 'Resend confirmation email'}
              </button>
            </div>
          )}

          <div className="auth-foot">
            New school? <Link href="/signup">Create an account</Link>
          </div>
        </div>
      </section>
    </div>
  );
}
