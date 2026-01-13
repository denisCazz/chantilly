-- ============================================
-- RPC: Statistiche Admin Dashboard
-- ============================================

CREATE OR REPLACE FUNCTION public.admin_get_stats()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staff_id UUID;
    v_staff_role TEXT;
    v_stats JSON;
BEGIN
    -- Verifica che l'utente sia staff/admin
    SELECT id, role INTO v_staff_id, v_staff_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    IF v_staff_id IS NULL OR v_staff_role NOT IN ('staff', 'admin') THEN
        RAISE EXCEPTION 'Accesso negato: solo staff/admin';
    END IF;
    
    -- Calcola statistiche
    SELECT json_build_object(
        'total_customers', (
            SELECT COUNT(*) 
            FROM public.profiles 
            WHERE role = 'customer'
        ),
        'total_cards', (
            SELECT COUNT(*) 
            FROM public.loyalty_cards
        ),
        'total_points_distributed', (
            SELECT COALESCE(SUM(delta), 0)
            FROM public.points_ledger
            WHERE delta > 0
        ),
        'total_points_redeemed', (
            SELECT COALESCE(SUM(ABS(delta)), 0)
            FROM public.points_ledger
            WHERE delta < 0
        ),
        'total_redemptions', (
            SELECT COUNT(*)
            FROM public.redemptions
        ),
        'active_cards', (
            SELECT COUNT(*)
            FROM public.loyalty_cards
            WHERE points_int > 0
        ),
        'cards_with_10_plus_points', (
            SELECT COUNT(*)
            FROM public.loyalty_cards
            WHERE points_int >= 10
        ),
        'recent_registrations', (
            SELECT COUNT(*)
            FROM public.profiles
            WHERE role = 'customer'
            AND created_at > NOW() - INTERVAL '7 days'
        ),
        'recent_transactions', (
            SELECT COUNT(*)
            FROM public.points_ledger
            WHERE created_at > NOW() - INTERVAL '7 days'
        )
    ) INTO v_stats;
    
    RETURN v_stats;
END;
$$;

-- Funzione: Lista clienti recenti
CREATE OR REPLACE FUNCTION public.admin_get_recent_customers(limit_count INTEGER DEFAULT 10)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staff_id UUID;
    v_staff_role TEXT;
    v_customers JSON;
BEGIN
    -- Verifica ruolo
    SELECT id, role INTO v_staff_id, v_staff_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    IF v_staff_id IS NULL OR v_staff_role NOT IN ('staff', 'admin') THEN
        RAISE EXCEPTION 'Accesso negato: solo staff/admin';
    END IF;
    
    -- Recupera clienti recenti
    SELECT json_agg(
        json_build_object(
            'id', p.id,
            'email', p.email,
            'full_name', p.full_name,
            'created_at', p.created_at,
            'card', json_build_object(
                'id', lc.id,
                'public_code', lc.public_code,
                'points', lc.points_int,
                'created_at', lc.created_at
            )
        ) ORDER BY p.created_at DESC
    ) INTO v_customers
    FROM (
        SELECT p.id, p.email, p.full_name, p.created_at, lc.id as card_id, lc.public_code, lc.points_int, lc.created_at as card_created
        FROM public.profiles p
        LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
        WHERE p.role = 'customer'
        ORDER BY p.created_at DESC
        LIMIT limit_count
    ) p
    LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id;
    
    RETURN COALESCE(v_customers, '[]'::json);
END;
$$;

-- Funzione: Cerca cliente per email o codice
CREATE OR REPLACE FUNCTION public.admin_search_customer(search_term TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_staff_id UUID;
    v_staff_role TEXT;
    v_results JSON;
BEGIN
    -- Verifica ruolo
    SELECT id, role INTO v_staff_id, v_staff_role
    FROM public.profiles
    WHERE id = auth.uid();
    
    IF v_staff_id IS NULL OR v_staff_role NOT IN ('staff', 'admin') THEN
        RAISE EXCEPTION 'Accesso negato: solo staff/admin';
    END IF;
    
    -- Cerca per email o public_code
    SELECT json_agg(
        json_build_object(
            'id', p.id,
            'email', p.email,
            'full_name', p.full_name,
            'created_at', p.created_at,
            'card', json_build_object(
                'id', lc.id,
                'public_code', lc.public_code,
                'points', lc.points_int
            )
        )
    ) INTO v_results
    FROM public.profiles p
    LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
    WHERE p.role = 'customer'
    AND (
        p.email ILIKE '%' || search_term || '%'
        OR lc.public_code ILIKE '%' || search_term || '%'
        OR COALESCE(p.full_name, '') ILIKE '%' || search_term || '%'
    )
    LIMIT 20;
    
    RETURN COALESCE(v_results, '[]'::json);
END;
$$;
