-- ============================================
-- SISTEMA TESSERA FEDELTÀ - BAR CHANTILLY
-- Database Schema completo con RLS e RPC
-- ============================================

-- Abilita estensioni necessarie
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================
-- TABELLE
-- ============================================

-- Profiles: estende auth.users con ruolo
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'staff', 'admin')),
    full_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Loyalty Cards: tessera fedeltà per ogni cliente
CREATE TABLE IF NOT EXISTS public.loyalty_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    public_code TEXT UNIQUE NOT NULL, -- Codice usato nel QR code
    points_int INTEGER NOT NULL DEFAULT 0 CHECK (points_int >= 0),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Points Ledger: storico movimenti punti
CREATE TABLE IF NOT EXISTS public.points_ledger (
    id BIGSERIAL PRIMARY KEY,
    card_id UUID NOT NULL REFERENCES public.loyalty_cards(id) ON DELETE CASCADE,
    delta INTEGER NOT NULL, -- +1 o -10, etc.
    reason TEXT NOT NULL, -- "Consumazione", "Riscatto premio", etc.
    staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- Chi ha fatto l'azione
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Rewards: premi disponibili
CREATE TABLE IF NOT EXISTS public.rewards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    cost_points INTEGER NOT NULL DEFAULT 10 CHECK (cost_points > 0),
    active BOOLEAN NOT NULL DEFAULT true,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Redemptions: storico riscatti
CREATE TABLE IF NOT EXISTS public.redemptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    card_id UUID NOT NULL REFERENCES public.loyalty_cards(id) ON DELETE CASCADE,
    reward_id UUID NOT NULL REFERENCES public.rewards(id) ON DELETE RESTRICT,
    staff_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL, -- NULL se riscattato dall'utente direttamente
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- INDICI
-- ============================================

CREATE INDEX IF NOT EXISTS idx_loyalty_cards_public_code ON public.loyalty_cards(public_code);
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_user_id ON public.loyalty_cards(user_id);
CREATE INDEX IF NOT EXISTS idx_points_ledger_card_id ON public.points_ledger(card_id);
CREATE INDEX IF NOT EXISTS idx_points_ledger_created_at ON public.points_ledger(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_redemptions_card_id ON public.redemptions(card_id);
CREATE INDEX IF NOT EXISTS idx_redemptions_created_at ON public.redemptions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON public.profiles(role);

-- ============================================
-- TRIGGER per updated_at
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loyalty_cards_updated_at BEFORE UPDATE ON public.loyalty_cards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rewards_updated_at BEFORE UPDATE ON public.rewards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- FUNZIONE: Crea automaticamente profile e card alla registrazione
-- ============================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_public_code TEXT;
BEGIN
    -- Genera codice pubblico univoco (UUID senza trattini)
    v_public_code := REPLACE(uuid_generate_v4()::TEXT, '-', '');
    
    -- Crea profile (con gestione conflitti)
    INSERT INTO public.profiles (id, email, role)
    VALUES (NEW.id, NEW.email, 'customer')
    ON CONFLICT (id) DO NOTHING;
    
    -- Crea loyalty card (con gestione conflitti)
    INSERT INTO public.loyalty_cards (user_id, public_code)
    VALUES (NEW.id, v_public_code)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log errore ma non bloccare la creazione dell'utente
    RAISE WARNING 'Errore in handle_new_user per utente %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Abilita RLS su tutte le tabelle
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.redemptions ENABLE ROW LEVEL SECURITY;

-- ============================================
-- POLICIES: Profiles
-- ============================================

-- Cliente può leggere solo il proprio profile
CREATE POLICY "Customers can read own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

-- NOTA: Policy "Staff can read all profiles" rimossa per evitare ricorsione infinita
-- Se staff/admin deve leggere tutti i profiles, usa una funzione RPC invece
-- Per ora, tutti possono leggere solo il proprio profile tramite "Users can read own profile"

-- Cliente può aggiornare solo il proprio profile (nome, etc)
CREATE POLICY "Customers can update own profile"
    ON public.profiles FOR UPDATE
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id AND role = 'customer');

-- Permetti inserimento da trigger (funzione SECURITY DEFINER)
CREATE POLICY "Allow trigger to insert profiles"
    ON public.profiles FOR INSERT
    WITH CHECK (true);

-- ============================================
-- POLICIES: Loyalty Cards
-- ============================================

-- Cliente può leggere solo la propria card
CREATE POLICY "Customers can read own card"
    ON public.loyalty_cards FOR SELECT
    USING (auth.uid() = user_id);

-- Staff/Admin può leggere tutte le cards
CREATE POLICY "Staff can read all cards"
    ON public.loyalty_cards FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- Permetti inserimento da trigger (funzione SECURITY DEFINER)
CREATE POLICY "Allow trigger to insert cards"
    ON public.loyalty_cards FOR INSERT
    WITH CHECK (true);

-- ============================================
-- POLICIES: Points Ledger
-- ============================================

-- Cliente può leggere solo il proprio ledger
CREATE POLICY "Customers can read own ledger"
    ON public.points_ledger FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.loyalty_cards
            WHERE id = points_ledger.card_id AND user_id = auth.uid()
        )
    );

-- Staff/Admin può leggere tutti i ledger
CREATE POLICY "Staff can read all ledger"
    ON public.points_ledger FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- Solo RPC possono inserire nel ledger (vedi funzioni sotto)

-- ============================================
-- POLICIES: Rewards
-- ============================================

-- Tutti possono leggere rewards attivi
CREATE POLICY "Anyone can read active rewards"
    ON public.rewards FOR SELECT
    USING (active = true);

-- Staff/Admin può leggere tutti i rewards
CREATE POLICY "Staff can read all rewards"
    ON public.rewards FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- ============================================
-- POLICIES: Redemptions
-- ============================================

-- Cliente può leggere solo i propri riscatti
CREATE POLICY "Customers can read own redemptions"
    ON public.redemptions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.loyalty_cards
            WHERE id = redemptions.card_id AND user_id = auth.uid()
        )
    );

-- Staff/Admin può leggere tutti i riscatti
CREATE POLICY "Staff can read all redemptions"
    ON public.redemptions FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role IN ('staff', 'admin')
        )
    );

-- Solo RPC possono inserire redemptions

-- ============================================
-- RPC FUNCTIONS (Security Definer)
-- ============================================

-- Funzione: Staff aggiunge/rimuove punti
CREATE OR REPLACE FUNCTION public.staff_add_point(
    p_public_code TEXT,
    p_delta INTEGER,
    p_reason TEXT DEFAULT 'Consumazione'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staff_id UUID;
    v_staff_role TEXT;
    v_card_id UUID;
    v_user_id UUID;
    v_new_balance INTEGER;
    v_customer_email TEXT;
    v_customer_name TEXT;
BEGIN
    -- Verifica che l'utente sia staff/admin
    SELECT id, role INTO v_staff_id, v_staff_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    IF v_staff_id IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;
    
    IF v_staff_role NOT IN ('staff', 'admin') THEN
        RAISE EXCEPTION 'Accesso negato: solo staff/admin può eseguire questa operazione';
    END IF;
    
    -- Trova la card
    SELECT id, user_id INTO v_card_id, v_user_id
    FROM public.loyalty_cards
    WHERE public_code = p_public_code;
    
    IF v_card_id IS NULL THEN
        RAISE EXCEPTION 'Tessera non trovata: %', p_public_code;
    END IF;
    
    -- Anti-abuso: limita +1 a max 1 ogni 5 minuti per la stessa card
    IF p_delta > 0 THEN
        IF EXISTS (
            SELECT 1 FROM public.points_ledger
            WHERE card_id = v_card_id
                AND delta > 0
                AND created_at > NOW() - INTERVAL '5 minutes'
        ) THEN
            RAISE EXCEPTION 'Troppo veloce: attendi 5 minuti tra un timbro e l''altro';
        END IF;
    END IF;
    
    -- Inserisci movimento nel ledger
    INSERT INTO public.points_ledger (card_id, delta, reason, staff_id)
    VALUES (v_card_id, p_delta, p_reason, v_staff_id);
    
    -- Aggiorna saldo atomico (non può andare negativo)
    UPDATE public.loyalty_cards
    SET points_int = GREATEST(0, points_int + p_delta),
        updated_at = NOW()
    WHERE id = v_card_id
    RETURNING points_int INTO v_new_balance;
    
    -- Recupera dati cliente per risposta
    SELECT email, full_name INTO v_customer_email, v_customer_name
    FROM public.profiles
    WHERE id = v_user_id;
    
    -- Ritorna JSON con risultato
    RETURN json_build_object(
        'success', true,
        'card_id', v_card_id,
        'new_balance', v_new_balance,
        'delta', p_delta,
        'customer', json_build_object(
            'id', v_user_id,
            'email', v_customer_email,
            'name', COALESCE(v_customer_name, 'Cliente')
        )
    );
END;
$$;

-- Funzione: Staff riscatta premio
CREATE OR REPLACE FUNCTION public.staff_redeem(
    p_public_code TEXT,
    p_reward_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staff_id UUID;
    v_staff_role TEXT;
    v_card_id UUID;
    v_user_id UUID;
    v_current_points INTEGER;
    v_reward_cost INTEGER;
    v_reward_name TEXT;
    v_new_balance INTEGER;
    v_redemption_id UUID;
BEGIN
    -- Verifica staff
    SELECT id, role INTO v_staff_id, v_staff_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    IF v_staff_id IS NULL OR v_staff_role NOT IN ('staff', 'admin') THEN
        RAISE EXCEPTION 'Accesso negato: solo staff/admin';
    END IF;
    
    -- Trova card
    SELECT id, user_id, points_int INTO v_card_id, v_user_id, v_current_points
    FROM public.loyalty_cards
    WHERE public_code = p_public_code;
    
    IF v_card_id IS NULL THEN
        RAISE EXCEPTION 'Tessera non trovata';
    END IF;
    
    -- Verifica reward
    SELECT cost_points, name INTO v_reward_cost, v_reward_name
    FROM public.rewards
    WHERE id = p_reward_id AND active = true;
    
    IF v_reward_name IS NULL THEN
        RAISE EXCEPTION 'Premio non valido o non attivo';
    END IF;
    
    -- Verifica punti sufficienti
    IF v_current_points < v_reward_cost THEN
        RAISE EXCEPTION 'Punti insufficienti: hai %, servono %', v_current_points, v_reward_cost;
    END IF;
    
    -- Inserisci redemption
    v_redemption_id := uuid_generate_v4();
    INSERT INTO public.redemptions (id, card_id, reward_id, staff_id)
    VALUES (v_redemption_id, v_card_id, p_reward_id, v_staff_id);
    
    -- Inserisci movimento negativo nel ledger
    INSERT INTO public.points_ledger (card_id, delta, reason, staff_id)
    VALUES (v_card_id, -v_reward_cost, 'Riscatto: ' || v_reward_name, v_staff_id);
    
    -- Aggiorna saldo
    UPDATE public.loyalty_cards
    SET points_int = points_int - v_reward_cost,
        updated_at = NOW()
    WHERE id = v_card_id
    RETURNING points_int INTO v_new_balance;
    
    RETURN json_build_object(
        'success', true,
        'redemption_id', v_redemption_id,
        'reward_name', v_reward_name,
        'cost', v_reward_cost,
        'new_balance', v_new_balance
    );
END;
$$;

-- Funzione: Cliente recupera la propria card
CREATE OR REPLACE FUNCTION public.customer_get_card()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_card RECORD;
    v_ledger JSON;
    v_redemptions JSON;
    v_public_code TEXT;
    v_profile_exists BOOLEAN;
BEGIN
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;
    
    -- Verifica se esiste il profile, altrimenti crealo
    SELECT EXISTS(SELECT 1 FROM public.profiles WHERE id = v_user_id) INTO v_profile_exists;
    
    IF NOT v_profile_exists THEN
        -- Crea profile se mancante
        INSERT INTO public.profiles (id, email, role)
        SELECT id, email, 'customer'
        FROM auth.users
        WHERE id = v_user_id
        ON CONFLICT (id) DO NOTHING;
    END IF;
    
    -- Recupera card
    SELECT * INTO v_card
    FROM public.loyalty_cards
    WHERE user_id = v_user_id;
    
    -- Se la card non esiste, creala automaticamente
    IF v_card IS NULL THEN
        v_public_code := REPLACE(uuid_generate_v4()::TEXT, '-', '');
        
        INSERT INTO public.loyalty_cards (user_id, public_code)
        VALUES (v_user_id, v_public_code)
        RETURNING * INTO v_card;
    END IF;
    
    -- Recupera ultimi 20 movimenti
    SELECT json_agg(
        json_build_object(
            'id', id,
            'delta', delta,
            'reason', reason,
            'created_at', created_at,
            'staff_name', (
                SELECT COALESCE(full_name, email) 
                FROM public.profiles 
                WHERE id = staff_id
            )
        ) ORDER BY created_at DESC
    ) INTO v_ledger
    FROM (
        SELECT id, delta, reason, created_at, staff_id
        FROM public.points_ledger
        WHERE card_id = v_card.id
        ORDER BY created_at DESC
        LIMIT 20
    ) pl;
    
    -- Recupera ultimi 10 riscatti
    SELECT json_agg(
        json_build_object(
            'id', red.id,
            'reward_name', red.reward_name,
            'cost', red.cost_points,
            'created_at', red.created_at,
            'staff_name', (
                SELECT COALESCE(p.full_name, p.email)
                FROM public.profiles p
                WHERE p.id = red.staff_id
            )
        ) ORDER BY red.created_at DESC
    ) INTO v_redemptions
    FROM (
        SELECT 
            r.id, 
            r.created_at, 
            r.staff_id, 
            rw.name as reward_name, 
            rw.cost_points
        FROM public.redemptions r
        JOIN public.rewards rw ON r.reward_id = rw.id
        WHERE r.card_id = v_card.id
        ORDER BY r.created_at DESC
        LIMIT 10
    ) red;
    
    RETURN json_build_object(
        'card', json_build_object(
            'id', v_card.id,
            'public_code', v_card.public_code,
            'points', v_card.points_int,
            'created_at', v_card.created_at
        ),
        'ledger', COALESCE(v_ledger, '[]'::json),
        'redemptions', COALESCE(v_redemptions, '[]'::json)
    );
END;
$$;

-- ============================================
-- SETUP INIZIALE: Crea reward di default
-- ============================================

INSERT INTO public.rewards (id, name, cost_points, description, active)
VALUES 
    (uuid_generate_v4(), 'Caffè Gratis', 10, 'Un caffè in omaggio', true),
    (uuid_generate_v4(), 'Cappuccino Gratis', 10, 'Un cappuccino in omaggio', true)
ON CONFLICT DO NOTHING;

-- ============================================
-- FINE SCHEMA
-- ============================================
