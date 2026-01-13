-- ============================================
-- TEST: Verifica lettura ruolo
-- Esegui questo per verificare che il ruolo sia leggibile
-- ============================================

-- 1. Verifica che la tabella profiles esista
SELECT 
    'Tabella profiles' as check_type,
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'profiles'
    ) THEN '✅ Esiste' ELSE '❌ Non esiste' END as status;

-- 2. Verifica RLS su profiles
SELECT 
    'RLS su profiles' as check_type,
    CASE WHEN (
        SELECT tablename FROM pg_tables 
        WHERE schemaname = 'public' 
        AND tablename = 'profiles'
        AND rowsecurity = true
    ) IS NOT NULL THEN '✅ Attivo' ELSE '❌ Non attivo' END as status;

-- 3. Lista tutte le policy su profiles
SELECT 
    'Policy su profiles' as check_type,
    policyname,
    cmd as operation,
    qual as using_expression
FROM pg_policies 
WHERE tablename = 'profiles'
ORDER BY policyname;

-- 4. Verifica utenti e ruoli
SELECT 
    u.id,
    u.email,
    p.role,
    p.created_at as profile_created
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
ORDER BY u.created_at DESC
LIMIT 10;

-- 5. Test query che fa il componente (sostituisci USER_ID con un ID reale)
-- SELECT role FROM public.profiles WHERE id = 'USER_ID_QUI';

-- 6. Verifica che ci siano policy SELECT per tutti
SELECT 
    'Policy SELECT per tutti' as check_type,
    CASE WHEN EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'profiles' 
        AND cmd = 'SELECT'
        AND (qual LIKE '%auth.uid()%' OR qual LIKE '%true%')
    ) THEN '✅ Presente' ELSE '❌ Mancante' END as status;
