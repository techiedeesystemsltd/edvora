"use client";

import Link from 'next/link';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '../../lib/supabase';
import { Logo, EdvoraMark, Icon } from '../../components/Brand';

export default function ResetPassword() {
  const router = useRouter();
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [ready, setReady] = useState(false);
  const [notice, setNotice] = useState('');
  const [busy, setBusy] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);

  useEffect(() => {
    const s = createClient();
    s.auth.getSession().then(({ data }) => setReady(Boolean(data.session)));
  }, []);

  async function submit(e) {
    e.preventDefault();
    if (password !== confirm) {
      setNotice('Passwords do not match.');
      setIsSuccess(false);
      return;
    }
    if (password.length < 8) {
      setNotice('Password must be at least 8 characters long.');
      setIsSuccess(false);
      return;
    }

    setBusy(true);
    setNotice('');
    try {
      const s = createClient();
      const { error } = await s.auth.updateUser({ password });
      if (error) {
        setNotice(error.message);
        setIsSuccess(false);
      } else {
        setNotice('Password updated successfully. Forwarding to dashboard…');
        setIsSuccess(true);
        setTimeout(() => router.push('/dashboard'), 800);
      }
    } catch (err) {
      setNotice(err?.message || 'Unable to update password.');
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
            Choose a new secure password.
          </h2>
          <p className="auth-hero-desc">
            Create a strong password with at least 8 characters to protect your school management workspace.
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
            <h1>Create new password</h1>
            <p>
              {ready
                ? 'Enter your new password below.'
                : 'Open this page from the password reset email to continue.'}
            </p>
          </div>

          {notice && (
            <div className={`notice ${isSuccess ? 'success' : 'error'}`} role="alert">
              {notice}
            </div>
          )}

          {ready && (
            <form onSubmit={submit} className="auth-form">
              <div className="auth-input-group">
                <label htmlFor="new-pass">New password (8+ characters)</label>
                <input
                  id="new-pass"
                  type="password"
                  minLength={8}
                  required
                  className="auth-input-field"
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>

              <div className="auth-input-group">
                <label htmlFor="confirm-pass">Confirm new password</label>
                <input
                  id="confirm-pass"
                  type="password"
                  minLength={8}
                  required
                  className="auth-input-field"
                  placeholder="••••••••"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                />
              </div>

              <button type="submit" className="auth-submit-btn" disabled={busy}>
                {busy ? (
                  <>
                    <EdvoraMark size={16} animated={true} />
                    <span>Updating password…</span>
                  </>
                ) : (
                  <>
                    <span>Update password</span>
                    <Icon name="check" size={16} />
                  </>
                )}
              </button>
            </form>
          )}

          <div className="auth-foot">
            <Link href="/login">Return to login</Link>
          </div>
        </div>
      </section>
    </div>
  );
}
