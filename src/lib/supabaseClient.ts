import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = import.meta.env.PUBLIC_SUPABASE_ANON_KEY || '';

// Crea client anche se le variabili non sono presenti (per build-time)
// L'errore verrà gestito a runtime quando si tenta di usare il client
export const supabase = createClient(
  supabaseUrl || 'https://placeholder.supabase.co',
  supabaseAnonKey || 'placeholder-key',
  {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true
    }
  }
);

// Funzione helper per verificare se Supabase è configurato
export function isSupabaseConfigured(): boolean {
  return !!(supabaseUrl && supabaseAnonKey && supabaseUrl !== 'https://placeholder.supabase.co');
}

// Tipi TypeScript per il database
export interface Profile {
  id: string;
  email: string;
  role: 'customer' | 'staff' | 'admin';
  full_name: string | null;
  created_at: string;
}

export interface LoyaltyCard {
  id: string;
  user_id: string;
  public_code: string;
  points_int: number;
  created_at: string;
  updated_at: string;
}

export interface PointsLedgerEntry {
  id: number;
  card_id: string;
  delta: number;
  reason: string;
  staff_id: string | null;
  created_at: string;
}

export interface Reward {
  id: string;
  name: string;
  cost_points: number;
  active: boolean;
  description: string | null;
  created_at: string;
}

export interface Redemption {
  id: string;
  card_id: string;
  reward_id: string;
  staff_id: string;
  created_at: string;
}
