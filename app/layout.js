import './globals.css';
import ConnectivityBanner from '../components/ConnectivityBanner';

export const dynamic = 'force-dynamic';

export const metadata = {
  title: 'Edvora - Everything your school needs. One platform.',
  description: 'Edvora is smart infrastructure for modern schools, connecting administration, academics, examinations, communication and payments.',
  icons: {
    icon: '/favicon.png',
    shortcut: '/favicon.png',
    apple: '/favicon.png',
  },
};

export default function RootLayout({ children }) {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
  const supabaseKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY || '';
  const runtime = JSON.stringify({ supabaseUrl, supabaseKey }).replace(/</g, '\\u003c');

  return (
    <html lang="en">
      <body>
        <script dangerouslySetInnerHTML={{ __html: `window.__EDVORA_CONFIG__=${runtime};` }} />
        <script dangerouslySetInnerHTML={{ __html: `if('serviceWorker' in navigator){window.addEventListener('load',()=>navigator.serviceWorker.register('/sw.js').catch(()=>{}))}` }} />
        <ConnectivityBanner />
        {children}
      </body>
    </html>
  );
}
