import { createClient } from '@supabase/supabase-js';
import { env } from './env.js';

export const supabaseAdmin = createClient(
  env.SUPABASE_URL,
  env.SUPABASE_SERVICE_ROLE_KEY,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

// Legacy credentials live in a separate project from the normalized app schema.
// Keep all application repositories pointed at SUPABASE_URL above.
export const legacySupabaseAdmin = createClient(
  env.LEGACY_SUPABASE_URL ?? env.SUPABASE_URL,
  env.LEGACY_SUPABASE_SERVICE_ROLE_KEY ?? env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { autoRefreshToken: false, persistSession: false } },
);

// Auth clients are request-scoped so one user's session cannot leak to another.
export function createAuthClient() {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
  });
}
