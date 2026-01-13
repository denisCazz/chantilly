-- ============================================
-- FIX: Ricorsione infinita nelle policy
-- La policy "Staff can read all profiles" causa ricorsione
-- ============================================

-- 1. Rimuovi la policy problematica che causa ricorsione
DROP POLICY IF EXISTS "Staff can read all profiles" ON public.profiles;

-- 2. Assicurati che la policy base per leggere il proprio profile esista
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;
CREATE POLICY "Users can read own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

-- 3. Crea una policy alternativa per staff/admin che NON causa ricorsione
-- Usa una funzione helper o semplicemente permette la lettura se l'utente è autenticato
-- Per ora, staff/admin può leggere il proprio profile come tutti gli altri
-- Se serve leggere tutti i profiles, usa una funzione RPC

-- 4. Verifica che non ci siano altre policy che causano ricorsione
SELECT 
    policyname,
    cmd,
    qual,
    CASE 
        WHEN qual LIKE '%profiles%' AND qual LIKE '%SELECT%' THEN '⚠️ Potrebbe causare ricorsione'
        ELSE '✅ OK'
    END as warning
FROM pg_policies 
WHERE tablename = 'profiles';

-- 5. Test: verifica che un utente possa leggere il proprio profile
-- SELECT role FROM public.profiles WHERE id = auth.uid();
