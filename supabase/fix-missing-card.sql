-- ============================================
-- FIX: Crea tessera mancante per utente corrente
-- Esegui questo per fixare un utente specifico
-- ============================================

-- Sostituisci 'USER_ID_QUI' con l'ID dell'utente (puoi trovarlo in auth.users)
-- Oppure usa questa query per trovare utenti senza tessera:

-- 1. Trova utenti autenticati senza tessera
SELECT 
    u.id as user_id,
    u.email,
    p.id as profile_id,
    lc.id as card_id
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON u.id = lc.user_id
WHERE lc.id IS NULL;

-- 2. Crea profile se mancante
INSERT INTO public.profiles (id, email, role, created_at)
SELECT 
    u.id,
    u.email,
    'customer',
    COALESCE(u.created_at, NOW())
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;

-- 3. Crea tessera per utente specifico (sostituisci USER_ID_QUI)
-- INSERT INTO public.loyalty_cards (user_id, public_code, created_at)
-- VALUES (
--     'USER_ID_QUI',
--     REPLACE(uuid_generate_v4()::TEXT, '-', ''),
--     NOW()
-- )
-- ON CONFLICT (user_id) DO NOTHING;

-- 4. Crea tessera per TUTTI gli utenti senza tessera
INSERT INTO public.loyalty_cards (user_id, public_code, created_at)
SELECT 
    p.id,
    REPLACE(uuid_generate_v4()::TEXT, '-', ''),
    COALESCE(p.created_at, NOW())
FROM public.profiles p
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE lc.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

-- 5. Verifica risultato
SELECT 
    COUNT(*) FILTER (WHERE lc.id IS NOT NULL) as users_with_card,
    COUNT(*) FILTER (WHERE lc.id IS NULL) as users_without_card,
    COUNT(*) as total_users
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id;
