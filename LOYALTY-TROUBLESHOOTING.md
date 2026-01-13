# 🔧 Troubleshooting - Sistema Tessera Fedeltà

## ❌ Errore: "Database error saving new user"

Questo errore si verifica quando il trigger che crea automaticamente profile e loyalty card alla registrazione non funziona correttamente.

### 🔍 Diagnosi

1. **Verifica che il trigger esista:**
```sql
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```

2. **Verifica che la funzione esista:**
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name = 'handle_new_user';
```

3. **Controlla i log Supabase:**
   - Dashboard → **Logs** → **Postgres Logs**
   - Cerca errori durante la registrazione

### ✅ Soluzione 1: Ricrea Trigger (Consigliato)

1. Vai su **SQL Editor** in Supabase
2. Apri il file `supabase/fix-trigger.sql`
3. Copia e incolla tutto il contenuto
4. Clicca **Run**
5. Verifica che non ci siano errori

### ✅ Soluzione 2: Fix Manuale per Utenti Esistenti

Se hai già utenti registrati senza profile/card:

1. Esegui `supabase/manual-user-fix.sql`
2. Questo creerà profile e card per tutti gli utenti mancanti

### ✅ Soluzione 3: Verifica RLS Policies

Le policy RLS potrebbero bloccare l'inserimento. Verifica:

```sql
-- Controlla policy su profiles
SELECT * FROM pg_policies WHERE tablename = 'profiles';

-- Controlla policy su loyalty_cards
SELECT * FROM pg_policies WHERE tablename = 'loyalty_cards';
```

Se mancano policy per INSERT, aggiungi:

```sql
-- Policy per profiles
CREATE POLICY "Allow trigger to insert profiles"
    ON public.profiles FOR INSERT
    WITH CHECK (true);

-- Policy per loyalty_cards
CREATE POLICY "Allow trigger to insert cards"
    ON public.loyalty_cards FOR INSERT
    WITH CHECK (true);
```

### ✅ Soluzione 4: Disabilita Temporaneamente RLS (Solo per Test)

⚠️ **ATTENZIONE**: Solo per debug, non usare in produzione!

```sql
-- Disabilita RLS temporaneamente
ALTER TABLE public.profiles DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_cards DISABLE ROW LEVEL SECURITY;

-- Testa registrazione

-- Riabilita RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loyalty_cards ENABLE ROW LEVEL SECURITY;
```

---

## ❌ Errore: "Tessera non trovata"

### Causa
La loyalty card non è stata creata per l'utente.

### Soluzione

1. **Verifica se esiste il profile:**
```sql
SELECT * FROM public.profiles WHERE id = 'USER_ID_QUI';
```

2. **Verifica se esiste la card:**
```sql
SELECT * FROM public.loyalty_cards WHERE user_id = 'USER_ID_QUI';
```

3. **Crea manualmente se mancante:**
```sql
-- Crea card per un utente specifico
INSERT INTO public.loyalty_cards (user_id, public_code)
VALUES (
    'USER_ID_QUI',
    REPLACE(uuid_generate_v4()::TEXT, '-', '')
)
ON CONFLICT (user_id) DO NOTHING;
```

---

## ❌ Errore: "Accesso negato: solo staff/admin"

### Causa
L'utente non ha il ruolo corretto nel database.

### Soluzione

1. **Verifica ruolo attuale:**
```sql
SELECT id, email, role 
FROM public.profiles 
WHERE email = 'tua@email.com';
```

2. **Aggiorna ruolo:**
```sql
-- Per staff
UPDATE public.profiles 
SET role = 'staff' 
WHERE email = 'tua@email.com';

-- Per admin
UPDATE public.profiles 
SET role = 'admin' 
WHERE email = 'tua@email.com';
```

---

## ❌ Errore: "function does not exist"

### Causa
Le funzioni RPC non sono state create.

### Soluzione

1. **Verifica funzioni esistenti:**
```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND (routine_name LIKE 'staff_%' OR routine_name LIKE 'customer_%');
```

2. **Riesegui lo schema completo:**
   - Apri `supabase/schema.sql`
   - Copia tutto il contenuto
   - Esegui in SQL Editor

---

## ❌ Errore: "Missing Supabase environment variables"

### Causa
File `.env` mancante o variabili non configurate.

### Soluzione

1. **Crea file `.env` nella root del progetto:**
```env
PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
```

2. **Riavvia il server:**
```bash
npm run dev
```

3. **Verifica che le variabili siano caricate:**
   - Apri DevTools (F12)
   - Console → Dovresti vedere errori se mancano

---

## ❌ Camera non funziona (Scanner QR)

### Causa
- Permessi camera non concessi
- Browser non supportato
- HTTPS non abilitato (richiesto per camera)

### Soluzione

1. **Concedi permessi camera** quando richiesto dal browser
2. **Usa Chrome o Firefox** (Safari su iOS ha limitazioni)
3. **Usa HTTPS in produzione** (obbligatorio per camera)
4. **Usa input manuale** come alternativa

---

## 🔍 Debug Generale

### 1. Verifica Configurazione Database

```sql
-- Verifica tabelle
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('profiles', 'loyalty_cards', 'points_ledger', 'rewards', 'redemptions');

-- Verifica trigger
SELECT tgname, tgrelid::regclass 
FROM pg_trigger 
WHERE tgname = 'on_auth_user_created';

-- Verifica funzioni
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname LIKE '%loyalty%' OR proname LIKE '%staff%' OR proname LIKE '%customer%';
```

### 2. Test Manuale Trigger

```sql
-- Simula inserimento utente (solo per test)
-- ATTENZIONE: Non eseguire in produzione senza modifiche!
INSERT INTO auth.users (id, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES (
    uuid_generate_v4(),
    'test@example.com',
    crypt('password123', gen_salt('bf')),
    NOW(),
    NOW(),
    NOW()
);

-- Verifica che profile e card siano stati creati
SELECT * FROM public.profiles WHERE email = 'test@example.com';
SELECT * FROM public.loyalty_cards WHERE user_id IN (
    SELECT id FROM public.profiles WHERE email = 'test@example.com'
);
```

### 3. Controlla Log Supabase

1. Dashboard → **Logs** → **Postgres Logs**
2. Filtra per errori o warning
3. Cerca messaggi relativi a `handle_new_user` o `on_auth_user_created`

---

## 📞 Supporto

Se il problema persiste:

1. **Raccogli informazioni:**
   - Messaggio errore completo
   - Log da browser console (F12)
   - Log da Supabase (Dashboard → Logs)
   - Screenshot se possibile

2. **Verifica setup:**
   - Schema SQL eseguito completamente?
   - Variabili ambiente configurate?
   - Utente staff creato correttamente?

3. **Test isolato:**
   - Prova a registrare un nuovo utente
   - Verifica se il problema è specifico o generale

---

**Ultimo aggiornamento**: Dopo aver applicato `fix-trigger.sql`, il sistema dovrebbe funzionare correttamente.
