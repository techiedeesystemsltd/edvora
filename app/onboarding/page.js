"use client";

import { useEffect, useState } from 'react';
import { createClient } from '../../lib/supabase';
import { Logo, EdvoraMark, Icon, EdvoraLoader } from '../../components/Brand';

const steps = [
  { title: 'Identity', subtitle: 'Name and ownership structure' },
  { title: 'Levels', subtitle: 'Educational stages operated' },
  { title: 'Location', subtitle: 'Campus location and contact' },
  { title: 'Academics', subtitle: 'Academic year and grading scale' },
  { title: 'Review', subtitle: 'Final review and launch' },
];

const ownershipOptions = [
  ['private_school','Private school'],
  ['federal_government','Federal government school'],
  ['state_government','State government school'],
  ['other_public','Other public school'],
];

const ownershipDescriptions = {
  private_school: 'Independently owned, faith-based or private educational institution.',
  federal_government: 'Federal Unity College or national federal school.',
  state_government: 'State-funded public secondary or primary school.',
  other_public: 'Community, military, or municipal public institution.',
};

const levelOptions = [
  ['nursery','Nursery'],
  ['primary','Primary'],
  ['secondary','Secondary'],
];

const levelDescriptions = {
  nursery: 'Early Years / Kindergarten / Creche',
  primary: 'Basic 1 to 6 / Elementary',
  secondary: 'Junior Secondary (JSS) & Senior Secondary (SSS)',
};

export default function Onboarding() {
  const [step, setStep] = useState(0);
  const [name, setName] = useState('');
  const [ownership, setOwnership] = useState('private_school');
  const [levels, setLevels] = useState(['primary', 'secondary']);
  const [timezone, setTimezone] = useState('Africa/Lagos');
  const [address, setAddress] = useState('');
  const [phone, setPhone] = useState('');
  const [academicYear, setAcademicYear] = useState('2026/2027');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const supabase = createClient();
        const { data: { user } } = await supabase.auth.getUser();
        if (!user) {
          window.location.assign('/login?next=/onboarding');
          return;
        }
        if (active) setLoading(false);
      } catch (e) {
        if (active) {
          setError(e.message);
          setLoading(false);
        }
      }
    })();
    return () => { active = false; };
  }, []);

  function handleNext(e) {
    if (e) e.preventDefault();
    setError('');

    if (step === 0) {
      if (!name.trim()) return setError('Please enter your official school name.');
      if (!ownership) return setError('Please select a school ownership structure.');
    }
    if (step === 1 && levels.length === 0) {
      return setError('Please select at least one educational level.');
    }
    if (step === 3 && !academicYear.trim()) {
      return setError('Please provide the current academic year (e.g. 2026/2027).');
    }

    setStep((s) => Math.min(steps.length - 1, s + 1));
  }

  function handleBack() {
    setError('');
    setStep((s) => Math.max(0, s - 1));
  }

  const toggleLevel = (id) => {
    setLevels((prev) =>
      prev.includes(id) ? prev.filter((v) => v !== id) : [...prev, id]
    );
  };

  async function submit() {
    if (saving) return;
    setSaving(true);
    setError('');

    try {
      const res = await fetch('/api/onboarding/school', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          name: name.trim(),
          ownership,
          levels,
          timezone,
          address: address.trim(),
          phone: phone.trim(),
          academicYear: academicYear.trim(),
        }),
      });

      const data = await res.json();
      if (!res.ok) throw new Error(data.error || 'Unable to create your school workspace.');

      if (data.schoolId && typeof window !== 'undefined') {
        localStorage.setItem('edvora.currentSchoolId', data.schoolId);
      }

      window.location.assign(data.redirect || '/dashboard');
    } catch (err) {
      setError(err.message || 'An error occurred while creating your workspace.');
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <div className="edvora-loading-screen">
        <EdvoraLoader label="Preparing school setup wizard…" size={48} />
      </div>
    );
  }

  return (
    <div className="onboard-layout">
      {/* Top Bar */}
      <header className="onboard-top-nav">
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <Logo />
        </div>

        {/* Stepper Progress */}
        <div className="onboard-stepper">
          {steps.map((st, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <div className={`step-dot ${i === step ? 'active' : i < step ? 'done' : ''}`}>
                {i < step ? <Icon name="check" size={14} /> : i + 1}
              </div>
              {i < steps.length - 1 && (
                <div className={`step-connector ${i < step ? 'done' : ''}`} />
              )}
            </div>
          ))}
        </div>
      </header>

      {/* Main Wizard Content */}
      <main className="onboard-wizard-wrapper">
        <div className="onboard-card-main">
          {/* Header */}
          <div className="wizard-header">
            <span className="wizard-kicker">
              Step {step + 1} of {steps.length} · {steps[step].title}
            </span>
            <h1>
              {step === 0 && 'Set up your school identity'}
              {step === 1 && 'What levels does your school offer?'}
              {step === 2 && 'Where is your campus located?'}
              {step === 3 && 'Academic calendar & grading'}
              {step === 4 && 'Review your school workspace'}
            </h1>
            <p>{steps[step].subtitle}</p>
          </div>

          {error && (
            <div className="notice error" role="alert" style={{ marginBottom: '20px' }}>
              {error}
            </div>
          )}

          {/* Step 0: Identity & Ownership */}
          {step === 0 && (
            <form onSubmit={handleNext}>
              <div className="auth-input-group">
                <label htmlFor="school-name">School official name</label>
                <input
                  id="school-name"
                  type="text"
                  required
                  autoFocus
                  className="auth-input-field"
                  placeholder="e.g. Corona International School"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
                {name && (
                  <small style={{ display: 'block', marginTop: '6px', color: '#64748b', fontSize: '12px' }}>
                    School URL slug: <strong style={{ color: '#2563eb' }}>{name.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')}</strong>
                  </small>
                )}
              </div>

              <div className="auth-input-group">
                <label>School ownership structure</label>
                <div className="ownership-cards-grid" role="radiogroup">
                  {ownershipOptions.map(([id, label]) => {
                    const isSelected = ownership === id;
                    return (
                      <div
                        key={id}
                        className={`ownership-card-item ${isSelected ? 'selected' : ''}`}
                        onClick={() => setOwnership(id)}
                        role="radio"
                        aria-checked={isSelected}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                          <strong>{label}</strong>
                          <div
                            style={{
                              width: '18px',
                              height: '18px',
                              borderRadius: '50%',
                              border: isSelected ? '5px solid #2563eb' : '2px solid #cbd5e1',
                              background: '#fff',
                            }}
                          />
                        </div>
                        <small>{ownershipDescriptions[id]}</small>
                      </div>
                    );
                  })}
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '28px' }}>
                <button type="submit" className="auth-submit-btn" style={{ width: 'auto', padding: '0 24px' }}>
                  <span>Continue</span>
                  <Icon name="arrow" size={16} />
                </button>
              </div>
            </form>
          )}

          {/* Step 1: School Levels */}
          {step === 1 && (
            <form onSubmit={handleNext}>
              <div className="auth-input-group">
                <label>Select all levels that apply</label>
                <p style={{ fontSize: '12px', color: '#64748b', margin: '0 0 12px' }}>
                  Edvora will provision standard classes, grade books, and timetables for each selected level.
                </p>

                <div className="level-cards-grid">
                  {levelOptions.map(([id, label]) => {
                    const isSelected = levels.includes(id);
                    return (
                      <div
                        key={id}
                        className={`level-card-item ${isSelected ? 'selected' : ''}`}
                        onClick={() => toggleLevel(id)}
                        role="checkbox"
                        aria-checked={isSelected}
                      >
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                          <strong>{label}</strong>
                          <div
                            style={{
                              width: '18px',
                              height: '18px',
                              borderRadius: '6px',
                              background: isSelected ? '#10b981' : '#fff',
                              border: isSelected ? 'none' : '2px solid #cbd5e1',
                              display: 'grid',
                              placeItems: 'center',
                              color: '#fff',
                            }}
                          >
                            {isSelected && <Icon name="check" size={12} />}
                          </div>
                        </div>
                        <small>{levelDescriptions[id]}</small>
                      </div>
                    );
                  })}
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '32px' }}>
                <button type="button" className="app-button" onClick={handleBack}>
                  <Icon name="arrowLeft" size={15} />
                  <span>Back</span>
                </button>
                <button type="submit" className="auth-submit-btn" style={{ width: 'auto', padding: '0 24px' }}>
                  <span>Continue</span>
                  <Icon name="arrow" size={16} />
                </button>
              </div>
            </form>
          )}

          {/* Step 2: Location & Contact */}
          {step === 2 && (
            <form onSubmit={handleNext}>
              <div className="auth-input-group">
                <label htmlFor="address">Campus physical address</label>
                <input
                  id="address"
                  type="text"
                  className="auth-input-field"
                  placeholder="e.g. 14 Admiralty Way, Lekki Phase 1, Lagos"
                  value={address}
                  onChange={(e) => setAddress(e.target.value)}
                />
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div className="auth-input-group">
                  <label htmlFor="phone">Official phone number</label>
                  <input
                    id="phone"
                    type="tel"
                    className="auth-input-field"
                    placeholder="e.g. 0803 123 4567"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                  />
                </div>

                <div className="auth-input-group">
                  <label htmlFor="tz">Timezone</label>
                  <select
                    id="tz"
                    className="auth-input-field"
                    value={timezone}
                    onChange={(e) => setTimezone(e.target.value)}
                  >
                    <option value="Africa/Lagos">West Africa Time (Lagos, GMT+1)</option>
                    <option value="Africa/Accra">Ghana Time (Accra, GMT+0)</option>
                    <option value="Africa/Nairobi">East Africa Time (Nairobi, GMT+3)</option>
                    <option value="Africa/Johannesburg">South Africa Time (Johannesburg, GMT+2)</option>
                  </select>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '32px' }}>
                <button type="button" className="app-button" onClick={handleBack}>
                  <Icon name="arrowLeft" size={15} />
                  <span>Back</span>
                </button>
                <button type="submit" className="auth-submit-btn" style={{ width: 'auto', padding: '0 24px' }}>
                  <span>Continue</span>
                  <Icon name="arrow" size={16} />
                </button>
              </div>
            </form>
          )}

          {/* Step 3: Academic Setup */}
          {step === 3 && (
            <form onSubmit={handleNext}>
              <div className="auth-input-group">
                <label htmlFor="acad-year">Current academic year</label>
                <input
                  id="acad-year"
                  type="text"
                  required
                  className="auth-input-field"
                  placeholder="2026/2027"
                  value={academicYear}
                  onChange={(e) => setAcademicYear(e.target.value)}
                />
              </div>

              <div style={{ background: '#f8fafc', border: '1px solid #e2e8f0', borderRadius: '12px', padding: '16px', marginTop: '16px' }}>
                <strong style={{ fontSize: '13px', color: '#0b1f3b', display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <EdvoraMark size={16} />
                  <span>Default Nigerian / WAEC Grading Scale Included</span>
                </strong>
                <p style={{ fontSize: '12px', color: '#64748b', margin: '6px 0 0' }}>
                  A1 (75-100), B2 (70-74), B3 (65-69), C4 (60-64), C5 (55-59), C6 (50-54), D7 (45-49), E8 (40-44), F9 (0-39). You can customize weights and thresholds anytime in settings.
                </p>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '32px' }}>
                <button type="button" className="app-button" onClick={handleBack}>
                  <Icon name="arrowLeft" size={15} />
                  <span>Back</span>
                </button>
                <button type="submit" className="auth-submit-btn" style={{ width: 'auto', padding: '0 24px' }}>
                  <span>Review setup</span>
                  <Icon name="arrow" size={16} />
                </button>
              </div>
            </form>
          )}

          {/* Step 4: Summary & Workspace Generation */}
          {step === 4 && (
            <div>
              <div className="onboard-summary-box">
                <div className="summary-line">
                  <span>School Name</span>
                  <strong>{name}</strong>
                </div>
                <div className="summary-line">
                  <span>Ownership</span>
                  <strong>
                    {ownershipOptions.find(([id]) => id === ownership)?.[1] || ownership}
                  </strong>
                </div>
                <div className="summary-line">
                  <span>Educational Levels</span>
                  <strong>
                    {levels
                      .map((v) => levelOptions.find(([id]) => id === v)?.[1] || v)
                      .join(', ')}
                  </strong>
                </div>
                <div className="summary-line">
                  <span>Campus Address</span>
                  <strong>{address || 'Not specified'}</strong>
                </div>
                <div className="summary-line">
                  <span>Phone & Timezone</span>
                  <strong>{phone || 'No phone'} · {timezone}</strong>
                </div>
                <div className="summary-line">
                  <span>Academic Calendar</span>
                  <strong>{academicYear} (First Term Active)</strong>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: '32px' }}>
                <button type="button" className="app-button" onClick={handleBack} disabled={saving}>
                  <Icon name="arrowLeft" size={15} />
                  <span>Back</span>
                </button>

                <button
                  type="button"
                  className="auth-submit-btn"
                  style={{ width: 'auto', padding: '0 28px', background: '#10b981' }}
                  disabled={saving}
                  onClick={submit}
                >
                  {saving ? (
                    <>
                      <EdvoraMark size={18} animated={true} />
                      <span>Creating school workspace…</span>
                    </>
                  ) : (
                    <>
                      <EdvoraMark size={18} />
                      <span>Create School Workspace</span>
                    </>
                  )}
                </button>
              </div>
            </div>
          )}
        </div>
      </main>
    </div>
  );
}
