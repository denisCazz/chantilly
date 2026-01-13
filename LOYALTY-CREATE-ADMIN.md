# 👤 Come Creare Utente Admin

## 🎯 Metodo Consigliato (Via Dashboard)

### Passo 1: Crea Utente in Supabase

1. Vai su **Supabase Dashboard** → **Authentication** → **Users**
2. Clicca **"Add user"** → **"Create new user"**
3. Compila:
   - **Email**: `admin@chantilly.it` (o email a scelta)
   - **Password**: scegli una password forte
   - **Auto Confirm User**: ✅ (spunta questa opzione - importante!)
4. Clicca **"Create user"**
5. **Copia l'User UID** (es: `a1b2c3d4-e5f6-7890-abcd-ef1234567890`)

### Passo 2: Assegna Ruolo Admin

1. Vai su **SQL Editor** in Supabase
2. Apri il file `supabase/create-admin-user.sql`
3. **Sostituisci**:
   - `USER_UID_QUI` con l'UID copiato
   - `admin@chantilly.it` con l'email usata
4. Esegui questa query:

```sql
-- Crea profile se mancante
INSERT INTO public.profiles (id, email, role)
VALUES (
    'USER_UID_QUI',  -- Sostituisci con l'UID
    'admin@chantilly.it',  -- Sostituisci con l'email
    'admin'
)
ON CONFLICT (id) DO UPDATE
SET role = 'admin';

-- Crea tessera se mancante
INSERT INTO public.loyalty_cards (user_id, public_code)
SELECT 
    'USER_UID_QUI',  -- Sostituisci con l'UID
    REPLACE(uuid_generate_v4()::TEXT, '-', '')
WHERE NOT EXISTS (
    SELECT 1 FROM public.loyalty_cards 
    WHERE user_id = 'USER_UID_QUI'
)
ON CONFLICT (user_id) DO NOTHING;
```

5. Clicca **Run**

### Passo 3: Verifica

```sql
SELECT 
    p.email,
    p.role,
    u.id
FROM public.profiles p
JOIN auth.users u ON p.id = u.id
WHERE p.role = 'admin';
```

Dovresti vedere il tuo utente con `role = 'admin'`.

---

## 🔄 Metodo Alternativo (Utente Già Registrato)

Se hai già registrato un utente normalmente:

1. Vai su `/account` e registrati con l'email che vuoi usare come admin
2. Vai su **SQL Editor**
3. Esegui:

```sql
-- Aggiorna ruolo a admin
UPDATE public.profiles
SET role = 'admin'
WHERE email = 'tua@email.com';  -- Sostituisci con la tua email
```

4. Verifica:

```sql
SELECT email, role FROM public.profiles WHERE email = 'tua@email.com';
```

---

## ✅ Test Accesso Admin

1. **Esci** dall'account corrente (se loggato)
2. Vai su `/admin`
3. **Accedi** con l'email admin e password
4. Dovresti vedere l'area staff senza errori

---

## 🔍 Verifica Ruoli Esistenti

Per vedere tutti gli utenti e i loro ruoli:

```sql
SELECT 
    u.email,
    p.role,
    p.created_at,
    CASE WHEN lc.id IS NOT NULL THEN '✅' ELSE '❌' END as has_card
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
ORDER BY p.created_at DESC;
```

---

## ⚠️ Note Importanti

1. **Auto Confirm**: Quando crei l'utente via Dashboard, spunta "Auto Confirm User" altrimenti dovrà confermare l'email
2. **Password Forte**: Usa una password complessa per l'admin
3. **Ruoli Disponibili**:
   - `customer` - Cliente normale
   - `staff` - Staff (può accedere a `/admin`)
   - `admin` - Amministratore (può accedere a `/admin`)

---

## 🛡️ Sicurezza

- L'utente admin può:
  - ✅ Accedere a `/admin`
  - ✅ Scansionare QR code
  - ✅ Aggiungere/rimuovere punti
  - ✅ Gestire riscatti premi
  - ✅ Vedere tutti i clienti

- L'utente admin NON può:
  - ❌ Modificare direttamente il database (solo via RPC)
  - ❌ Bypassare RLS (le policy sono sempre attive)

---

**Dopo aver eseguito lo script, l'utente può accedere a `/admin` come amministratore!** 🎉
