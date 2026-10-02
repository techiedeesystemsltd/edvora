import { createBrowserClient } from "@supabase/ssr";

let browserClient;

export function getSupabaseConfig() {
  const runtime = typeof window !== 'undefined' ? window.__EDVORA_CONFIG__ || {} : {};
  const url = (
    process.env.NEXT_PUBLIC_SUPABASE_URL ||
    runtime.supabaseUrl
  )?.trim();
  const key = (
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
    runtime.supabaseKey
  )?.trim();
  return { url, key };
}

export function createClient() {
  if (browserClient) return browserClient;

  const { url, key } = getSupabaseConfig();
  if (!url || !key) {
    throw new Error(
      "Supabase is not configured. Add NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (or NEXT_PUBLIC_SUPABASE_ANON_KEY) in Vercel, then redeploy. Open /configuration for the setup steps."
    );
  }

  browserClient = createBrowserClient(url, key);
  return browserClient;
}
