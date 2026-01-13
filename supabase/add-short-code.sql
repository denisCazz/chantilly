-- ============================================
-- AGGIUNGI: Codice breve per tessere
-- Genera codice breve (6-8 caratteri) invece del lungo UUID
-- ============================================

-- 1. Aggiungi colonna short_code alla tabella loyalty_cards
ALTER TABLE public.loyalty_cards 
ADD COLUMN IF NOT EXISTS short_code TEXT UNIQUE;

-- 2. Crea indice per ricerca veloce
CREATE INDEX IF NOT EXISTS idx_loyalty_cards_short_code ON public.loyalty_cards(short_code);

-- 3. Funzione per generare codice breve univoco (6 caratteri alfanumerici)
CREATE OR REPLACE FUNCTION generate_short_code()
RETURNS TEXT AS $$
DECLARE
    v_code TEXT;
    v_exists BOOLEAN;
    v_chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- Esclude caratteri ambigui (0, O, I, 1)
    v_length INTEGER := 6;
    v_counter INTEGER := 0;
BEGIN
    LOOP
        -- Genera codice casuale
        v_code := '';
        FOR i IN 1..v_length LOOP
            v_code := v_code || substr(v_chars, floor(random() * length(v_chars) + 1)::integer, 1);
        END LOOP;
        
        -- Verifica se esiste già
        SELECT EXISTS(SELECT 1 FROM public.loyalty_cards WHERE short_code = v_code) INTO v_exists;
        
        -- Se non esiste, esci dal loop
        EXIT WHEN NOT v_exists;
        
        -- Contatore di sicurezza per evitare loop infiniti
        v_counter := v_counter + 1;
        IF v_counter > 100 THEN
            RAISE EXCEPTION 'Impossibile generare codice breve univoco dopo 100 tentativi';
        END IF;
    END LOOP;
    
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

-- 4. Aggiorna tessere esistenti senza short_code
UPDATE public.loyalty_cards
SET short_code = generate_short_code()
WHERE short_code IS NULL;

-- 5. Aggiorna funzione handle_new_user per generare anche short_code
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_public_code TEXT;
    v_short_code TEXT;
BEGIN
    -- Genera codice pubblico univoco (UUID senza trattini) - per QR code
    v_public_code := REPLACE(uuid_generate_v4()::TEXT, '-', '');
    
    -- Genera codice breve univoco (6 caratteri) - per dettatura
    v_short_code := generate_short_code();
    
    -- Crea profile (con gestione conflitti)
    INSERT INTO public.profiles (id, email, role)
    VALUES (NEW.id, NEW.email, 'customer')
    ON CONFLICT (id) DO NOTHING;
    
    -- Crea loyalty card (con gestione conflitti)
    INSERT INTO public.loyalty_cards (user_id, public_code, short_code)
    VALUES (NEW.id, v_public_code, v_short_code)
    ON CONFLICT (user_id) DO NOTHING;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log errore ma non bloccare la creazione dell'utente
    RAISE WARNING 'Errore in handle_new_user per utente %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Aggiorna funzione customer_get_card per includere short_code
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
    v_short_code TEXT;
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
        v_short_code := generate_short_code();
        
        INSERT INTO public.loyalty_cards (user_id, public_code, short_code)
        VALUES (v_user_id, v_public_code, v_short_code)
        RETURNING * INTO v_card;
    END IF;
    
    -- Se la card esiste ma non ha short_code, generalo
    IF v_card.short_code IS NULL THEN
        v_short_code := generate_short_code();
        UPDATE public.loyalty_cards
        SET short_code = v_short_code
        WHERE id = v_card.id;
        v_card.short_code := v_short_code;
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
        SELECT r.id, r.created_at, r.staff_id, rw.name as reward_name, rw.cost_points
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
            'short_code', COALESCE(v_card.short_code, ''),
            'points', v_card.points_int,
            'created_at', v_card.created_at
        ),
        'ledger', COALESCE(v_ledger, '[]'::json),
        'redemptions', COALESCE(v_redemptions, '[]'::json)
    );
END;
$$;

-- 7. Aggiorna funzione staff_add_point per accettare anche short_code
-- Prima elimina tutte le varianti possibili della funzione esistente
DO $$ 
BEGIN
    -- Prova a eliminare tutte le varianti possibili
    DROP FUNCTION IF EXISTS public.staff_add_point(TEXT, INTEGER, TEXT) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(TEXT, INTEGER) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(p_public_code TEXT, p_delta INTEGER, p_reason TEXT) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(p_public_code TEXT, p_delta INTEGER) CASCADE;
EXCEPTION WHEN OTHERS THEN
    -- Ignora errori se la funzione non esiste
    NULL;
END $$;

CREATE OR REPLACE FUNCTION public.staff_add_point(
    p_code TEXT,  -- Può essere public_code o short_code
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
    
    -- Trova la card per public_code o short_code
    SELECT id, user_id INTO v_card_id, v_user_id
    FROM public.loyalty_cards
    WHERE public_code = p_code OR short_code = p_code;
    
    IF v_card_id IS NULL THEN
        RAISE EXCEPTION 'Tessera non trovata: %', p_code;
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

-- 8. Aggiorna funzione staff_redeem per accettare anche short_code
-- Prima elimina tutte le varianti possibili della funzione esistente
DO $$ 
BEGIN
    -- Prova a eliminare tutte le varianti possibili
    DROP FUNCTION IF EXISTS public.staff_redeem(TEXT, UUID) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_redeem(p_public_code TEXT, p_reward_id UUID) CASCADE;
EXCEPTION WHEN OTHERS THEN
    -- Ignora errori se la funzione non esiste
    NULL;
END $$;

CREATE OR REPLACE FUNCTION public.staff_redeem(
    p_code TEXT,  -- Può essere public_code o short_code
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
    
    -- Trova card per public_code o short_code
    SELECT id, user_id, points_int INTO v_card_id, v_user_id, v_current_points
    FROM public.loyalty_cards
    WHERE public_code = p_code OR short_code = p_code;
    
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

-- 9. Verifica risultato
SELECT 
    COUNT(*) as total_cards,
    COUNT(short_code) as cards_with_short_code,
    COUNT(*) - COUNT(short_code) as cards_without_short_code
FROM public.loyalty_cards;
