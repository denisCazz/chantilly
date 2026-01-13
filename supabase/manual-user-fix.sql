-- ============================================
-- FIX MANUALE: Crea profile e card per utenti esistenti
-- Usa questo se hai utenti già registrati senza profile/card
-- ============================================

-- 1. Trova utenti senza profile
SELECT 
    u.id,
    u.email,
    u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL;

-- 2. Crea profile per utenti mancanti
INSERT INTO public.profiles (id, email, role, created_at)
SELECT 
    u.id,
    u.email,
    'customer',
    u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- 3. Trova utenti senza loyalty card
SELECT 
    p.id,
    p.email
FROM public.profiles p
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE lc.user_id IS NULL;

-- 4. Crea loyalty card per utenti mancanti
INSERT INTO public.loyalty_cards (user_id, public_code, created_at)
SELECT 
    p.id,
    REPLACE(uuid_generate_v4()::TEXT, '-', ''),
    p.created_at
FROM public.profiles p
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE lc.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

-- 5. Verifica risultato
SELECT 
    COUNT(*) as total_users,
    (SELECT COUNT(*) FROM public.profiles) as total_profiles,
    (SELECT COUNT(*) FROM public.loyalty_cards) as total_cards
FROM auth.users;
