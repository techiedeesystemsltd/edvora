"use client";

import Link from 'next/link';
import { useState } from 'react';
import { createClient } from '../../lib/supabase';
import { Logo, EdvoraMark, Icon } from '../../components/Brand';

export default function Signup() {
  const [form, setForm] = useState({ name: '', email: '', password: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  async function submit(e) {
    e.preventDefault();
    setError('');

    if (form.password.length < 8) {
      setError('Password must be at least 8 characters long.');
      return;
    }

    setLoading(true);
    try {
      const supabase = createClient();
      const { data, error: authError } = await supabase.auth.signUp({
        email: form.email.trim(),
        password: form.password,
        options: {
          data: { full_name: form.name.trim() },
          emailRedirectTo: `${window.location.origin}/auth/callback?next=/onboarding`,
        },
      });

      if (authError) throw authError;

      if (!data.session) {
        // Confirmation email required
        window.location.assign(`/login?confirmed=1&email=${encodeURIComponent(form.email.trim())}`);
        return;
      }

      // Direct session created -> forward to onboarding
      window.location.assign('/onboarding');
    } catch (err) {
      setError(err?.message || 'Unable to create the account. Please try again.');
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
            Start with your school.<br />Connect everything else.
          </h2>
          <p className="auth-hero-desc">
            Set up your owner account in seconds. Create your school workspace and immediately configure academic years, terms, classes, students, and grading scales.
          </p>

          <div className="auth-feature-list">
            <div className="auth-feature-pill">
              <EdvoraMark size={20} />
              <span>Full administrative & financial command</span>
            </div>
            <div className="auth-feature-pill">
              <EdvoraMark size={20} />
              <span>Dedicated teacher, parent & student portals</span>
            </div>
            <div className="auth-feature-pill">
              <EdvoraMark size={20} />
              <span>Automated broadsheets & WAEC report cards</span>
            </div>
          </div>
        </div>

        <div className="auth-foot-note" style={{ fontSize: '11px', color: 'rgba(255,255,255,0.4)', marginTop: '24px' }}>
          © {new Date().getFullYear()} Edvora Systems. Bright outside. Calm inside.
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
            <h1>Create your school account</h1>
            <p>Start with your school owner account. You can invite staff and teachers later.</p>
          </div>

          {error && (
            <div className="notice error" role="alert">
              {error}
            </div>
          )}

          <form onSubmit={submit} className="auth-form">
            <div className="auth-input-group">
              <label htmlFor="name">Your full name</label>
              <input
                id="name"
                type="text"
                autoComplete="name"
                required
                className="auth-input-field"
                placeholder="e.g. Dr. Ngozi Adeyemi"
                value={form.name}
                onChange={(e) => setForm({ ...form, name: e.target.value })}
              />
            </div>

            <div className="auth-input-group">
              <label htmlFor="email">Official email address</label>
              <input
                id="email"
                type="email"
                autoComplete="email"
                required
                className="auth-input-field"
                placeholder="director@school.com"
                value={form.email}
                onChange={(e) => setForm({ ...form, email: e.target.value })}
              />
            </div>

            <div className="auth-input-group">
              <label htmlFor="password">Password (8+ characters)</label>
              <input
                id="password"
                type="password"
                autoComplete="new-password"
                minLength={8}
                required
                className="auth-input-field"
                placeholder="••••••••"
                value={form.password}
                onChange={(e) => setForm({ ...form, password: e.target.value })}
              />
            </div>

            <button type="submit" className="auth-submit-btn" disabled={loading}>
              {loading ? (
                <>
                  <EdvoraMark size={16} animated={true} />
                  <span>Creating account…</span>
                </>
              ) : (
                <>
                  <span>Continue to School Setup</span>
                  <Icon name="arrow" size={16} />
                </>
              )}
            </button>
          </form>

          <div className="auth-foot">
            Already have an account? <Link href="/login">Sign in</Link>
          </div>
        </div>
      </section>
    </div>
  );
}
