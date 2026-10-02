import { createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
export function createServerSupabase(){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL?.trim();
 const key=(process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY||process.env.SUPABASE_ANON_KEY)?.trim();
 if(!url||!key) throw new Error('Supabase server configuration is missing. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (or NEXT_PUBLIC_SUPABASE_ANON_KEY) in Vercel.');
 const cookieStore=cookies();
 return createServerClient(url,key,{cookies:{getAll(){return cookieStore.getAll()},setAll(items){try{items.forEach(({name,value,options})=>cookieStore.set(name,value,options))}catch{}}}});
}
