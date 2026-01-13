-- ============================================
-- FIX: Ricrea le funzioni staff_add_point e staff_redeem
-- Se le funzioni non esistono o hanno problemi
-- ============================================

-- 1. Elimina tutte le varianti esistenti delle funzioni
DO $$ 
BEGIN
    -- Elimina staff_add_point in tutte le varianti possibili
    DROP FUNCTION IF EXISTS public.staff_add_point(TEXT, INTEGER, TEXT) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(TEXT, INTEGER) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(p_public_code TEXT, p_delta INTEGER, p_reason TEXT) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(p_public_code TEXT, p_delta INTEGER) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(p_code TEXT, p_delta INTEGER, p_reason TEXT) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_add_point(p_code TEXT, p_delta INTEGER) CASCADE;
    
    -- Elimina staff_redeem in tutte le varianti possibili
    DROP FUNCTION IF EXISTS public.staff_redeem(TEXT, UUID) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_redeem(p_public_code TEXT, p_reward_id UUID) CASCADE;
    DROP FUNCTION IF EXISTS public.staff_redeem(p_code TEXT, p_reward_id UUID) CASCADE;
EXCEPTION WHEN OTHERS THEN
    -- Ignora errori se le funzioni non esistono
    NULL;
END $$;

-- 2. Crea funzione staff_add_point (supporta sia public_code che short_code)
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

-- 3. Crea funzione staff_redeem (supporta sia public_code che short_code)
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

-- 4. Verifica che le funzioni siano state create correttamente
SELECT 
    'staff_add_point' as function_name,
    proname as function_exists,
    pg_get_function_identity_arguments(oid) as function_signature
FROM pg_proc
WHERE proname = 'staff_add_point' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public')
UNION ALL
SELECT 
    'staff_redeem' as function_name,
    proname as function_exists,
    pg_get_function_identity_arguments(oid) as function_signature
FROM pg_proc
WHERE proname = 'staff_redeem' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'public');

-- 5. Forza il refresh della cache dello schema (se necessario)
NOTIFY pgrst, 'reload schema';
