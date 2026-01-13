# 🔧 Fix: "Tessera non trovata per questo utente"

## ⚡ Soluzione Immediata

Se vedi l'errore **"Tessera non trovata per questo utente"**, la funzione `customer_get_card()` è stata aggiornata per creare automaticamente la tessera se mancante.

### Opzione 1: Ricarica la Pagina (Automatico)

1. **Ricarica la pagina** `/account`
2. La funzione ora crea automaticamente la tessera se mancante
3. Dovrebbe funzionare al primo tentativo

### Opzione 2: Fix Manuale via SQL (Se necessario)

Se il fix automatico non funziona, esegui questo script:

1. Apri **Supabase Dashboard** → **SQL Editor**
2. Apri il file `supabase/fix-missing-card.sql`
3. **Esegui la query 4** (crea tessera per tutti gli utenti senza tessera):

```sql
INSERT INTO public.loyalty_cards (user_id, public_code, created_at)
SELECT 
    p.id,
    REPLACE(uuid_generate_v4()::TEXT, '-', ''),
    COALESCE(p.created_at, NOW())
FROM public.profiles p
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE lc.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;
```

4. Clicca **Run**

### Opzione 3: Fix per Utente Specifico

Se vuoi fixare solo il tuo utente:

1. Trova il tuo User ID:
```sql
SELECT id, email FROM auth.users WHERE email = 'tua@email.com';
```

2. Crea la tessera:
```sql
INSERT INTO public.loyalty_cards (user_id, public_code)
VALUES (
    'USER_ID_QUI',
    REPLACE(uuid_generate_v4()::TEXT, '-', '')
)
ON CONFLICT (user_id) DO NOTHING;
```

---

## 🔍 Verifica

Dopo il fix, verifica che la tessera sia stata creata:

```sql
SELECT 
    u.email,
    p.id as profile_id,
    lc.id as card_id,
    lc.public_code,
    lc.points_int
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE u.email = 'tua@email.com';
```

Dovresti vedere:
- ✅ `profile_id` presente
- ✅ `card_id` presente
- ✅ `public_code` generato
- ✅ `points_int` = 0

---

## 🎯 Cosa è Stato Aggiornato

### 1. Funzione `customer_get_card()` (Automatico)

La funzione ora:
- ✅ Verifica se esiste il profile, altrimenti lo crea
- ✅ Verifica se esiste la tessera, altrimenti la crea automaticamente
- ✅ Genera automaticamente il `public_code` univoco
- ✅ Non genera più l'errore "Tessera non trovata"

### 2. Componente CustomerCard (Retry automatico)

Il componente ora:
- ✅ Rileva l'errore "Tessera non trovata"
- ✅ Riprova automaticamente dopo 1 secondo
- ✅ Mostra messaggio più chiaro all'utente

---

## 📋 Checklist

- [ ] Funzione `customer_get_card()` aggiornata (esegui `supabase/schema.sql` se necessario)
- [ ] Test ricarica pagina `/account`
- [ ] Tessera creata automaticamente
- [ ] QR code visualizzato correttamente
- [ ] Saldo punti = 0 (corretto per nuovo utente)

---

## ⚠️ Nota

Se hai già eseguito lo schema SQL iniziale, devi **rieseguire solo la funzione `customer_get_card()`** aggiornata. Puoi copiare solo quella parte dallo schema aggiornato, oppure rieseguire tutto lo schema (è idempotente, non crea duplicati).

---

**Problema risolto?** Dopo aver aggiornato la funzione, ricarica la pagina e la tessera dovrebbe essere creata automaticamente.
