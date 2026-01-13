-- ============================================
-- CREA UTENTE ADMIN
-- Istruzioni passo-passo
-- ============================================

-- METODO 1: Se l'utente ESISTE già in auth.users
-- (Hai già registrato l'utente tramite /account)

-- 1. Trova l'ID dell'utente
SELECT 
    id,
    email,
    created_at
FROM auth.users
WHERE email = 'admin@chantilly.it';  -- Sostituisci con l'email dell'admin

-- 2. Assicurati che esista il profile
INSERT INTO public.profiles (id, email, role, created_at)
SELECT 
    u.id,
    u.email,
    'customer',  -- Inizialmente customer, poi aggiorniamo
    u.created_at
FROM auth.users u
WHERE u.email = 'admin@chantilly.it'  -- Sostituisci con l'email
AND NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = u.id
)
ON CONFLICT (id) DO NOTHING;

-- 3. Aggiorna il ruolo a 'admin'
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'admin@chantilly.it';  -- Sostituisci con l'email

-- 4. Verifica
SELECT 
    p.id,
    p.email,
    p.role,
    CASE WHEN lc.id IS NOT NULL THEN '✅' ELSE '❌' END as has_card
FROM public.profiles p
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE p.email = 'admin@chantilly.it';  -- Sostituisci con l'email

-- ============================================
-- METODO 2: Crea utente direttamente (Solo per sviluppo/test)
-- ⚠️ ATTENZIONE: In produzione usa il metodo 1 (registrazione normale)
-- ============================================

-- Questo metodo richiede la password hash, quindi è più complesso
-- È meglio usare il metodo 1: registrati normalmente e poi aggiorna il ruolo

-- ============================================
-- METODO 3: Via Dashboard Supabase (CONSIGLIATO)
-- ============================================

/*
PASSO 1: Crea utente via Dashboard
1. Vai su Supabase Dashboard → Authentication → Users
2. Clicca "Add user" → "Create new user"
3. Inserisci:
   - Email: admin@chantilly.it (o email a scelta)
   - Password: scegli una password forte
   - Auto Confirm User: ✅ (spunta questa opzione)
4. Clicca "Create user"
5. Copia l'User UID (es: a1b2c3d4-...)

PASSO 2: Esegui questo SQL (sostituisci USER_UID e EMAIL)
*/

-- Crea profile se mancante
INSERT INTO public.profiles (id, email, role)
VALUES (
    'USER_UID_QUI',  -- Sostituisci con l'UID copiato
    'admin@chantilly.it',  -- Sostituisci con l'email
    'admin'
)
ON CONFLICT (id) DO UPDATE
SET role = 'admin';

-- Crea tessera se mancante (opzionale, ma consigliato)
INSERT INTO public.loyalty_cards (user_id, public_code)
SELECT 
    'USER_UID_QUI',  -- Sostituisci con l'UID
    REPLACE(uuid_generate_v4()::TEXT, '-', '')
WHERE NOT EXISTS (
    SELECT 1 FROM public.loyalty_cards 
    WHERE user_id = 'USER_UID_QUI'
)
ON CONFLICT (user_id) DO NOTHING;

-- Verifica finale
SELECT 
    '✅ Utente Admin Creato' as status,
    p.email,
    p.role,
    u.id as user_id
FROM public.profiles p
JOIN auth.users u ON p.id = u.id
WHERE p.email = 'admin@chantilly.it'  -- Sostituisci con l'email
AND p.role = 'admin';
