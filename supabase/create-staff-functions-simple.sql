-- ============================================
-- CREA FUNZIONI STAFF (Versione Semplice)
-- Esegui questo script se le funzioni non vengono trovate
-- ============================================

-- Elimina funzioni esistenti (se presenti)
DROP FUNCTION IF EXISTS public.staff_add_point CASCADE;
DROP FUNCTION IF EXISTS public.staff_redeem CASCADE;

-- Crea funzione staff_add_point
CREATE FUNCTION public.staff_add_point(
    p_code TEXT,
    p_delta INTEGER,
    p_reason TEXT DEFAULT 'Consumazione'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- Crea funzione staff_redeem
CREATE FUNCTION public.staff_redeem(
    p_code TEXT,
    p_reward_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
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

-- Concedi permessi di esecuzione
GRANT EXECUTE ON FUNCTION public.staff_add_point(TEXT, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_redeem(TEXT, UUID) TO authenticated;

-- Verifica creazione
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines
WHERE routine_schema = 'public' 
    AND routine_name IN ('staff_add_point', 'staff_redeem')
ORDER BY routine_name;
