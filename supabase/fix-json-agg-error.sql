-- ============================================
-- FIX: Errore "column must appear in GROUP BY"
-- Corregge la sintassi di json_agg() nella funzione customer_get_card()
-- ============================================

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
    
    -- Recupera ultimi 20 movimenti (FIX: usa subquery per evitare errore GROUP BY)
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
    
    -- Recupera ultimi 10 riscatti (FIX: usa subquery per evitare errore GROUP BY)
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

-- Verifica che la funzione sia stata aggiornata
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'customer_get_card'
    ) THEN
        RAISE NOTICE '✅ Funzione customer_get_card() aggiornata con successo!';
        RAISE NOTICE 'Errore GROUP BY risolto usando subquery.';
    ELSE
        RAISE EXCEPTION '❌ Errore: funzione non trovata dopo l''aggiornamento!';
    END IF;
END $$;
