-- ============================================
-- DIAGNOSTICA: Perché non c'è la tessera?
-- Esegui questo per capire cosa manca
-- ============================================

-- 1. Verifica utente corrente
SELECT 
    'Utente Autenticato' as check_type,
    auth.uid() as user_id,
    (SELECT email FROM auth.users WHERE id = auth.uid()) as email;

-- 2. Verifica se esiste il profile
SELECT 
    'Profile Esistente' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid()) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status,
    (SELECT email FROM public.profiles WHERE id = auth.uid()) as email,
    (SELECT role FROM public.profiles WHERE id = auth.uid()) as role;

-- 3. Verifica se esiste la tessera
SELECT 
    'Tessera Esistente' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM public.loyalty_cards WHERE user_id = auth.uid()) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status,
    (SELECT public_code FROM public.loyalty_cards WHERE user_id = auth.uid()) as public_code,
    (SELECT points_int FROM public.loyalty_cards WHERE user_id = auth.uid()) as points;

-- 4. Verifica trigger
SELECT 
    'Trigger Attivo' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'on_auth_user_created'
        ) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status;

-- 5. Verifica funzione handle_new_user
SELECT 
    'Funzione handle_new_user' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'handle_new_user'
        ) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status;

-- 6. Verifica funzione customer_get_card
SELECT 
    'Funzione customer_get_card' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_proc 
            WHERE proname = 'customer_get_card'
        ) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status;

-- 7. Verifica policy INSERT su profiles
SELECT 
    'Policy INSERT profiles' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE tablename = 'profiles' 
            AND policyname LIKE '%insert%' OR policyname LIKE '%trigger%'
        ) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status,
    (SELECT string_agg(policyname, ', ') 
     FROM pg_policies 
     WHERE tablename = 'profiles' 
     AND (policyname LIKE '%insert%' OR policyname LIKE '%trigger%')) as policy_names;

-- 8. Verifica policy INSERT su loyalty_cards
SELECT 
    'Policy INSERT loyalty_cards' as check_type,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_policies 
            WHERE tablename = 'loyalty_cards' 
            AND (policyname LIKE '%insert%' OR policyname LIKE '%trigger%')
        ) 
        THEN '✅ SÌ' 
        ELSE '❌ NO' 
    END as status,
    (SELECT string_agg(policyname, ', ') 
     FROM pg_policies 
     WHERE tablename = 'loyalty_cards' 
     AND (policyname LIKE '%insert%' OR policyname LIKE '%trigger%')) as policy_names;

-- 9. Lista tutti gli utenti e loro stato
SELECT 
    u.id,
    u.email,
    u.created_at as user_created,
    CASE WHEN p.id IS NOT NULL THEN '✅' ELSE '❌' END as has_profile,
    CASE WHEN lc.id IS NOT NULL THEN '✅' ELSE '❌' END as has_card,
    lc.public_code,
    lc.points_int
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON u.id = lc.user_id
ORDER BY u.created_at DESC
LIMIT 10;
