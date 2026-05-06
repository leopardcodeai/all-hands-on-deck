import { createClient, type SupabaseClient } from '@supabase/supabase-js';

type ClientEnv = Record<string, string | undefined>;

const env = import.meta.env as ClientEnv;

export const supabaseConfig = {
  url: env.VITE_SUPABASE_URL ?? env.SUPABASE_URL ?? '',
  anonKey: env.VITE_SUPABASE_ANON_KEY ?? env.SUPABASE_ANON_KEY ?? '',
};

let cachedClient: SupabaseClient | null = null;

export function isSupabaseConfigured(): boolean {
  return Boolean(supabaseConfig.url && supabaseConfig.anonKey);
}

export function getSupabaseClient(): SupabaseClient {
  if (!isSupabaseConfigured()) {
    throw new Error('Supabase is not configured. Set VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY for the web client.');
  }

  cachedClient ??= createClient(supabaseConfig.url, supabaseConfig.anonKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
    },
    realtime: {
      params: {
        eventsPerSecond: 12,
      },
    },
  });
  return cachedClient;
}
