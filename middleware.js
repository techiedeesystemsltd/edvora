import {NextResponse} from 'next/server';

const standardRoutes = new Set([
  '', 'login', 'signup', 'onboarding', 'dashboard', 'students', 'teachers', 'teacher',
  'classes', 'attendance', 'assignments', 'results', 'grading', 'cbt', 'timetable',
  'fees', 'finance', 'reports', 'analytics', 'communications', 'notifications',
  'website', 'question-bank', 'imports', 'integrations', 'support', 'ai', 'operations',
  'data-governance', 'security', 'observability', 'members', 'settings', 'pricing',
  'audit', 'parent', 'parent-link', 'student', 'super-admin', 'admissions', 'promotion',
  'report-cards', 'school', 'contact', 'privacy', 'profile', 'forgot-password',
  'reset-password', 'accept-invitation'
]);

export function middleware(req){
  const host=(req.headers.get('host')||'').split(':')[0].toLowerCase();
  const path=req.nextUrl.pathname;
  const firstSegment=path.split('/')[1]||'';

  if(!host||host==='localhost'||host==='127.0.0.1'||host==='0.0.0.0'||host.endsWith('.vercel.app')||host.includes('edvora')||host.includes('.run.app')||host.includes('google')||host.includes('aistudio')) {
    return NextResponse.next();
  }
  if(path.startsWith('/_next')||path.startsWith('/api')||path.startsWith('/favicon')||path.startsWith('/sw.js')||path.startsWith('/domain')) {
    return NextResponse.next();
  }
  if(standardRoutes.has(firstSegment)) {
    return NextResponse.next();
  }
  const url=req.nextUrl.clone();
  url.pathname='/domain/'+host+(path==='/'?'':path);
  return NextResponse.rewrite(url);
}

export const config={matcher:['/((?!_next/static|_next/image|favicon.ico).*)']};

