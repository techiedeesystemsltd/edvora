import Link from 'next/link';

/**
 * Official Edvora Colourful "E" Mark
 * Composed of four vibrant geometric bars:
 * - Blue: #2563EB
 * - Lime/Green: #10B981
 * - Yellow/Amber: #F59E0B
 * - Coral/Red: #EF4444
 */
export function EdvoraMark({ size = 32, className = '', animated = false }) {
  const s = size;
  return (
    <svg
      width={s}
      height={s}
      viewBox="0 0 40 40"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={`edvora-mark ${animated ? 'edvora-mark-animated' : ''} ${className}`}
      aria-hidden="true"
    >
      {/* Top Bar - Vibrant Blue */}
      <rect
        x="6"
        y="6"
        width="28"
        height="6.5"
        rx="3.25"
        fill="#2563EB"
        className="edvora-bar edvora-bar-top"
      />
      {/* Vertical Spine - Blue to Coral gradient blend */}
      <rect
        x="6"
        y="6"
        width="6.5"
        height="28"
        rx="3.25"
        fill="#1D4ED8"
        className="edvora-bar edvora-bar-spine"
      />
      {/* Middle Bar - Fresh Lime Green */}
      <rect
        x="6"
        y="16.75"
        width="22"
        height="6.5"
        rx="3.25"
        fill="#10B981"
        className="edvora-bar edvora-bar-mid"
      />
      {/* Bottom Bar - Warm Amber Yellow */}
      <rect
        x="6"
        y="27.5"
        width="28"
        height="6.5"
        rx="3.25"
        fill="#F59E0B"
        className="edvora-bar edvora-bar-bot"
      />
      {/* Dynamic Accent Dot / Spark - Coral Red */}
      <circle
        cx="34.5"
        cy="20"
        r="2.5"
        fill="#EF4444"
        className="edvora-bar edvora-bar-dot"
      />
    </svg>
  );
}

/**
 * Animated Loading State with the Colourful Edvora "E"
 */
export function EdvoraLoader({ label = 'Loading Edvora workspace…', size = 48, fullScreen = false }) {
  return (
    <div className={fullScreen ? 'edvora-loading-screen' : 'edvora-loader-inline'} role="status" aria-live="polite">
      <div className="edvora-loader-container">
        <div className="edvora-loader-pulse-ring" />
        <EdvoraMark size={size} animated={true} />
      </div>
      {label && <span className="edvora-loader-label">{label}</span>}
    </div>
  );
}

export function Logo({ light = false, compact = false, showMarkOnly = false }) {
  if (showMarkOnly) {
    return (
      <Link href="/" className="brand-logo-mark" aria-label="Edvora home">
        <EdvoraMark size={32} />
      </Link>
    );
  }

  return (
    <Link href="/" className={`brand-logo ${light ? 'brand-logo-light' : ''}`} aria-label="Edvora home">
      <img
        src={light ? '/edvora-logo-light.png' : '/edvora-logo.png'}
        alt="Edvora"
        className={compact ? 'brand-logo-img compact' : 'brand-logo-img'}
      />
    </Link>
  );
}

export function Icon({ name, size = 20, className = '' }) {
  const common = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    strokeWidth: '1.8',
    strokeLinecap: 'round',
    strokeLinejoin: 'round',
    className,
    'aria-hidden': 'true',
  };

  const paths = {
    home: <><path d="m3 10 9-7 9 7"/><path d="M5 9.5V21h14V9.5"/><path d="M9 21v-7h6v7"/></>,
    users: <><path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="9.5" cy="7" r="4"/><path d="M17 11a4 4 0 0 0 0-8"/><path d="M21 21v-2a4 4 0 0 0-3-3.87"/></>,
    class: <><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M8 8h8M8 12h8M8 16h5"/></>,
    wallet: <><path d="M4 6h15a2 2 0 0 1 2 2v10H5a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h13"/><path d="M16 13h5"/><circle cx="16" cy="13" r=".7"/></>,
    chart: <><path d="M4 19V5M4 19h17"/><path d="m7 15 4-4 3 2 5-7"/></>,
    clipboard: <><rect x="5" y="4" width="14" height="17" rx="2"/><path d="M9 4.5V3h6v1.5M8 9h8M8 13h6M8 17h4"/></>,
    calendar: <><rect x="3" y="4" width="18" height="17" rx="2"/><path d="M8 2v4M16 2v4M3 9h18"/></>,
    message: <><path d="M20 11.5a7.5 7.5 0 0 1-8 7.5 8.6 8.6 0 0 1-3.5-.7L4 20l1.5-4A7.3 7.3 0 0 1 4.5 12 7.5 7.5 0 0 1 12 4.5a7.5 7.5 0 0 1 8 7Z"/><path d="M8 12h.01M12 12h.01M16 12h.01"/></>,
    settings: <><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-1.7 1.7-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.1h-2.4v-.1a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L6 17l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H4.7v-2.4h.1a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L6 8.6l1.7-1.7.1.1a1.7 1.7 0 0 0 1.9.3 1.7 1.7 0 0 0 1-1.6v-.1h2.4v.1a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1 1.7 1.7-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.1V14h-.1a1.7 1.7 0 0 0-1.6 1Z"/></>,
    arrow: <><path d="M5 12h14M13 6l6 6-6 6"/></>,
    arrowLeft: <><path d="M19 12H5M12 19l-7-7 7-7"/></>,
    check: <><path d="m5 12 4 4L19 6"/></>,
    plus: <><path d="M12 5v14M5 12h14"/></>,
    menu: <><path d="M4 7h16M4 12h16M4 17h16"/></>,
    search: <><circle cx="11" cy="11" r="6.5"/><path d="m16 16 5 5"/></>,
    close: <><path d="m6 6 12 12M18 6 6 18"/></>,
    spark: <><path d="m12 3 1.7 5.3L19 10l-5.3 1.7L12 17l-1.7-5.3L5 10l5.3-1.7L12 3Z"/><path d="m19 16 .8 2.2L22 19l-2.2.8L19 22l-.8-2.2L16 19l2.2-.8L19 16Z"/></>,
    shield: <><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></>,
    building: <><rect x="4" y="2" width="16" height="20" rx="2"/><path d="M9 22v-4h6v4M8 6h.01M16 6h.01M8 10h.01M16 10h.01M8 14h.01M16 14h.01"/></>,
    globe: <><circle cx="12" cy="12" r="10"/><path d="M12 2a15.3 15.3 0 0 0 4 10 15.3 15.3 0 0 0-4 10 15.3 15.3 0 0 0-4-10 15.3 15.3 0 0 0 4-10z"/><path d="M2 12h20"/></>,
    phone: <><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/></>,
    mapPin: <><path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z"/><circle cx="12" cy="10" r="3"/></>,
    award: <><circle cx="12" cy="8" r="7"/><polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"/></>,
    bookOpen: <><path d="M2 3h6a4 4 0 0 1 4 4v14a3 3 0 0 0-3-3H2z"/><path d="M22 3h-6a4 4 0 0 0-4 4v14a3 3 0 0 1 3-3h7z"/></>,
    mail: <><rect width="20" height="16" x="2" y="4" rx="2"/><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></>,
    lock: <><rect width="18" height="11" x="3" y="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></>,
  };

  return <svg {...common}>{paths[name] || paths.home}</svg>;
}
