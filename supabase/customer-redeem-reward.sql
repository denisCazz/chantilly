-- ============================================
-- FUNZIONE: Cliente riscatta premio
-- Permette all'utente di riscattare un premio
-- Azzera i punti e crea il record di riscatto
-- ============================================

CREATE OR REPLACE FUNCTION public.customer_redeem_reward(
    p_reward_id UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_card_id UUID;
    v_current_points INTEGER;
    v_reward_cost INTEGER;
    v_reward_name TEXT;
    v_new_balance INTEGER;
    v_redemption_id UUID;
BEGIN
    -- Verifica autenticazione
    v_user_id := auth.uid();
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Utente non autenticato';
    END IF;
    
    -- Recupera card dell'utente
    SELECT id, points_int INTO v_card_id, v_current_points
    FROM public.loyalty_cards
    WHERE user_id = v_user_id;
    
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
    
    -- Crea redemption (staff_id sarà NULL per riscatti utente diretti)
    v_redemption_id := uuid_generate_v4();
    INSERT INTO public.redemptions (id, card_id, reward_id, staff_id)
    VALUES (v_redemption_id, v_card_id, p_reward_id, NULL);
    
    -- Inserisci movimento negativo nel ledger
    INSERT INTO public.points_ledger (card_id, delta, reason, staff_id)
    VALUES (v_card_id, -v_reward_cost, 'Riscatto: ' || v_reward_name, NULL);
    
    -- Azzera i punti (o sottrae i punti del premio)
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
        'new_balance', v_new_balance,
        'redeemed_at', NOW()
    );
END;
$$;

-- Concedi permessi
GRANT EXECUTE ON FUNCTION public.customer_redeem_reward(UUID) TO authenticated;
