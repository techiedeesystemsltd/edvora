import {NextResponse} from 'next/server';
export function middleware(req){
 const host=(req.headers.get('host')||'').split(':')[0].toLowerCase();
 const path=req.nextUrl.pathname;
 if(!host||host==='localhost'||host==='127.0.0.1'||host.endsWith('.vercel.app')||host.includes('edvora')) return NextResponse.next();
 if(path.startsWith('/_next')||path.startsWith('/api')||path.startsWith('/favicon')||path.startsWith('/sw.js')) return NextResponse.next();
 const url=req.nextUrl.clone();
 url.pathname='/domain/'+host+(path==='/'?'':path);
 return NextResponse.rewrite(url);
}
export const config={matcher:['/((?!_next/static|_next/image|favicon.ico).*)']};
