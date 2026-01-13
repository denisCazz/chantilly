-- ============================================
-- FIX COMPLETO: Crea tutte le tessere mancanti
-- Esegui questo per fixare TUTTI gli utenti
-- ============================================

-- STEP 1: Assicurati che le policy INSERT esistano
-- (Necessarie per permettere la creazione da trigger/funzioni)

-- Policy per profiles
DROP POLICY IF EXISTS "Allow trigger to insert profiles" ON public.profiles;
CREATE POLICY "Allow trigger to insert profiles"
    ON public.profiles FOR INSERT
    WITH CHECK (true);

-- Policy per loyalty_cards
DROP POLICY IF EXISTS "Allow trigger to insert cards" ON public.loyalty_cards;
CREATE POLICY "Allow trigger to insert cards"
    ON public.loyalty_cards FOR INSERT
    WITH CHECK (true);

-- STEP 2: Crea profile per tutti gli utenti senza profile
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

-- STEP 3: Crea tessera per tutti gli utenti senza tessera
INSERT INTO public.loyalty_cards (user_id, public_code, created_at, points_int)
SELECT 
    p.id,
    REPLACE(uuid_generate_v4()::TEXT, '-', ''),
    COALESCE(p.created_at, NOW()),
    0
FROM public.profiles p
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE lc.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

-- STEP 4: Verifica risultato
SELECT 
    'Risultato Fix' as summary,
    (SELECT COUNT(*) FROM auth.users) as total_users,
    (SELECT COUNT(*) FROM public.profiles) as total_profiles,
    (SELECT COUNT(*) FROM public.loyalty_cards) as total_cards,
    (SELECT COUNT(*) FROM auth.users u
     LEFT JOIN public.profiles p ON u.id = p.id
     WHERE p.id IS NULL) as users_without_profile,
    (SELECT COUNT(*) FROM public.profiles p
     LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
     WHERE lc.user_id IS NULL) as profiles_without_card;

-- STEP 5: Mostra utenti ancora senza tessera (se ce ne sono)
SELECT 
    'Utenti ancora senza tessera' as warning,
    u.id,
    u.email,
    u.created_at
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE lc.id IS NULL
ORDER BY u.created_at DESC;
