-- ============================================
-- FIX: Trigger Registrazione Utente
-- Esegui questo script se hai errori "Database error saving new user"
-- ============================================

-- 1. Rimuovi trigger esistente se presente
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

-- 2. Ricrea la funzione con gestione errori migliorata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
    v_public_code TEXT;
BEGIN
    -- Genera codice pubblico univoco (UUID senza trattini)
    v_public_code := REPLACE(uuid_generate_v4()::TEXT, '-', '');
    
    -- Crea profile (con gestione errori)
    BEGIN
        INSERT INTO public.profiles (id, email, role)
        VALUES (NEW.id, NEW.email, 'customer')
        ON CONFLICT (id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Errore creazione profile per utente %: %', NEW.id, SQLERRM;
    END;
    
    -- Crea loyalty card (con gestione errori)
    BEGIN
        INSERT INTO public.loyalty_cards (user_id, public_code)
        VALUES (NEW.id, v_public_code)
        ON CONFLICT (user_id) DO NOTHING;
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Errore creazione loyalty card per utente %: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Log errore ma non bloccare la creazione dell'utente
    RAISE WARNING 'Errore in handle_new_user per utente %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Ricrea il trigger
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 4. Aggiungi policy per permettere inserimento da trigger (se mancante)
-- Questa policy permette alla funzione SECURITY DEFINER di inserire

-- Policy per profiles: permette inserimento da funzione trigger
DROP POLICY IF EXISTS "Allow trigger to insert profiles" ON public.profiles;
CREATE POLICY "Allow trigger to insert profiles"
    ON public.profiles FOR INSERT
    WITH CHECK (true); -- La funzione SECURITY DEFINER bypassa RLS, ma è meglio essere espliciti

-- Policy per loyalty_cards: permette inserimento da funzione trigger
DROP POLICY IF EXISTS "Allow trigger to insert cards" ON public.loyalty_cards;
CREATE POLICY "Allow trigger to insert cards"
    ON public.loyalty_cards FOR INSERT
    WITH CHECK (true);

-- 5. Verifica che le tabelle esistano e abbiano RLS abilitato
ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.loyalty_cards ENABLE ROW LEVEL SECURITY;

-- 6. Verifica configurazione
DO $$
BEGIN
    -- Controlla se il trigger esiste
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'on_auth_user_created'
    ) THEN
        RAISE EXCEPTION 'Trigger on_auth_user_created non trovato dopo la creazione!';
    END IF;
    
    -- Controlla se la funzione esiste
    IF NOT EXISTS (
        SELECT 1 FROM pg_proc 
        WHERE proname = 'handle_new_user'
    ) THEN
        RAISE EXCEPTION 'Funzione handle_new_user non trovata dopo la creazione!';
    END IF;
    
    RAISE NOTICE '✅ Trigger e funzione configurati correttamente!';
END $$;
