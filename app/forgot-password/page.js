"use client";

import Link from 'next/link';
import { useState } from 'react';
import { createClient } from '../../lib/supabase';
import { Logo, EdvoraMark, Icon } from '../../components/Brand';

export default function ForgotPassword() {
  const [email, setEmail] = useState('');
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setBusy(true);
    setNotice('');

    try {
      const supabase = createClient();
      const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), {
        redirectTo: `${window.location.origin}/auth/callback?next=/reset-password`,
      });

      if (error) {
        setNotice(error.message);
        setIsSuccess(false);
      } else {
        setNotice('If an Edvora account exists for that email, password reset instructions have been sent.');
        setIsSuccess(true);
      }
    } catch (err) {
      setNotice(err?.message || 'Unable to process your request.');
      setIsSuccess(false);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="auth-split">
      <section className="auth-hero-pane">
        <div className="auth-hero-content">
          <Logo light />
          <h2 className="auth-hero-title">
            Account recovery & security.
          </h2>
          <p className="auth-hero-desc">
            We'll send a single-use secure reset link to your verified school email address.
          </p>
        </div>
        <div className="auth-foot-note" style={{ fontSize: '11px', color: 'rgba(255,255,255,0.4)' }}>
          © {new Date().getFullYear()} Edvora Systems.
        </div>
      </section>

      <section className="auth-form-pane">
        <div className="auth-card-box">
          <div className="auth-header">
            <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
              <EdvoraMark size={32} />
              <strong style={{ fontSize: '18px', color: '#0b1f3b', fontWeight: 800 }}>Edvora</strong>
            </div>
            <h1>Reset your password</h1>
            <p>Enter your account email to receive recovery instructions.</p>
          </div>

          {notice && (
            <div className={`notice ${isSuccess ? 'success' : 'error'}`} role="alert">
              {notice}
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

            <button type="submit" className="auth-submit-btn" disabled={busy}>
              {busy ? (
                <>
                  <EdvoraMark size={16} animated={true} />
                  <span>Sending reset link…</span>
                </>
              ) : (
                <>
                  <span>Send reset link</span>
                  <Icon name="arrow" size={16} />
                </>
              )}
            </button>
          </form>

          <div className="auth-foot">
            Remembered your password? <Link href="/login">Back to sign in</Link>
          </div>
        </div>
      </section>
    </div>
  );
}
