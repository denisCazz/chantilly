# 🔧 Fix Rapido: "Database error saving new user"

## ⚡ Soluzione Immediata

Se stai riscontrando l'errore **"Database error saving new user"** durante la registrazione, segui questi passaggi:

### Passo 1: Esegui Fix Trigger

1. Apri il dashboard Supabase
2. Vai su **SQL Editor**
3. Apri il file `supabase/fix-trigger.sql` dal progetto
4. **Copia tutto il contenuto** e incollalo nell'editor SQL
5. Clicca **Run** (o premi `Ctrl+Enter`)
6. Verifica che non ci siano errori

### Passo 2: Verifica Fix

Dopo aver eseguito lo script, verifica che tutto sia a posto:

```sql
-- Verifica trigger
SELECT tgname FROM pg_trigger WHERE tgname = 'on_auth_user_created';

-- Verifica funzione
SELECT proname FROM pg_proc WHERE proname = 'handle_new_user';

-- Verifica policy
SELECT policyname FROM pg_policies 
WHERE tablename IN ('profiles', 'loyalty_cards') 
AND policyname LIKE '%trigger%';
```

Dovresti vedere:
- ✅ `on_auth_user_created` (trigger)
- ✅ `handle_new_user` (funzione)
- ✅ `Allow trigger to insert profiles` (policy)
- ✅ `Allow trigger to insert cards` (policy)

### Passo 3: Test Registrazione

1. Vai su `/account`
2. Prova a registrare un nuovo utente
3. Dovrebbe funzionare senza errori

---

## 🔍 Se il Problema Persiste

### Opzione A: Fix Utenti Esistenti

Se hai già utenti registrati senza profile/card:

1. Esegui `supabase/manual-user-fix.sql` in SQL Editor
2. Questo creerà profile e card per tutti gli utenti mancanti

### Opzione B: Verifica Log

1. Dashboard Supabase → **Logs** → **Postgres Logs**
2. Cerca errori durante la registrazione
3. Controlla se ci sono warning o errori relativi a `handle_new_user`

### Opzione C: Controlla RLS

Se le policy non sono state create correttamente:

```sql
-- Aggiungi policy manualmente se mancanti
CREATE POLICY IF NOT EXISTS "Allow trigger to insert profiles"
    ON public.profiles FOR INSERT
    WITH CHECK (true);

CREATE POLICY IF NOT EXISTS "Allow trigger to insert cards"
    ON public.loyalty_cards FOR INSERT
    WITH CHECK (true);
```

---

## 📋 Checklist Post-Fix

- [ ] Script `fix-trigger.sql` eseguito senza errori
- [ ] Trigger `on_auth_user_created` presente
- [ ] Funzione `handle_new_user` presente
- [ ] Policy INSERT presenti su `profiles` e `loyalty_cards`
- [ ] Test registrazione nuovo utente OK
- [ ] Utenti esistenti fixati (se necessario)

---

## 🎯 Cosa Fa il Fix

Il fix aggiorna:

1. **Funzione `handle_new_user`**:
   - Aggiunge gestione errori migliorata
   - Usa `ON CONFLICT DO NOTHING` per evitare duplicati
   - Non blocca la creazione utente anche in caso di errore

2. **Policy RLS**:
   - Aggiunge policy esplicite per permettere INSERT da trigger
   - La funzione `SECURITY DEFINER` bypassa RLS, ma è meglio essere espliciti

3. **Trigger**:
   - Ricrea il trigger con configurazione corretta

---

## ⚠️ Nota Importante

Dopo aver applicato il fix, **tutti i nuovi utenti** avranno automaticamente:
- ✅ Profile creato in `public.profiles`
- ✅ Loyalty card creata in `public.loyalty_cards`
- ✅ Codice pubblico univoco generato

Se hai utenti registrati **prima** del fix, esegui anche `manual-user-fix.sql` per creare i loro profile/card.

---

**Problema risolto?** Se sì, puoi procedere normalmente. Se no, consulta `LOYALTY-TROUBLESHOOTING.md` per diagnosi approfondita.
