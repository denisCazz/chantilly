-- ============================================
-- FIX: Policy per lettura ruolo nel componente
-- Assicura che tutti possano leggere il proprio profile
-- ============================================

-- Rimuovi policy se esiste già (per evitare duplicati)
DROP POLICY IF EXISTS "Users can read own profile" ON public.profiles;

-- Policy per permettere a tutti di leggere il proprio profile
-- Questa è la più permissiva e dovrebbe funzionare sempre
CREATE POLICY "Users can read own profile"
    ON public.profiles FOR SELECT
    USING (auth.uid() = id);

-- Verifica che la policy sia stata creata
SELECT 
    'Policy creata' as status,
    policyname,
    cmd,
    qual
FROM pg_policies 
WHERE tablename = 'profiles' 
AND policyname = 'Users can read own profile';

-- Test: verifica che un utente possa leggere il proprio ruolo
-- (Sostituisci con un USER_ID reale)
-- SELECT role FROM public.profiles WHERE id = auth.uid();
