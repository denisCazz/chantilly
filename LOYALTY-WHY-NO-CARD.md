# 🔍 Perché non c'è la tessera?

## Diagnostica Rapida

Esegui questo script per capire cosa manca:

1. **Supabase Dashboard** → **SQL Editor**
2. Apri `supabase/diagnose-missing-card.sql`
3. Copia tutto e incolla
4. Clicca **Run**

Questo ti dirà esattamente cosa manca:
- ✅/❌ Profile esistente?
- ✅/❌ Tessera esistente?
- ✅/❌ Trigger attivo?
- ✅/❌ Funzioni presenti?
- ✅/❌ Policy RLS corrette?

---

## Cause Comuni

### 1. ❌ Trigger non funziona

**Sintomo**: Utente creato ma nessun profile/tessera

**Soluzione**:
```sql
-- Esegui fix-trigger.sql
```

### 2. ❌ Policy RLS bloccano inserimento

**Sintomo**: Trigger esiste ma non crea nulla

**Soluzione**:
```sql
-- Le policy devono permettere INSERT da trigger
-- Esegui fix-all-missing.sql (include fix policy)
```

### 3. ❌ Utente creato prima del trigger

**Sintomo**: Utenti vecchi senza tessera

**Soluzione**:
```sql
-- Esegui fix-all-missing.sql
```

### 4. ❌ Funzione customer_get_card non aggiornata

**Sintomo**: Errore "Tessera non trovata" anche dopo fix

**Soluzione**:
```sql
-- Esegui update-customer-get-card.sql
```

---

## 🔧 Fix Completo (Consigliato)

Se non sai quale sia il problema, esegui questo fix completo:

1. **Esegui `supabase/fix-all-missing.sql`**
   - Crea policy mancanti
   - Crea profile per tutti
   - Crea tessera per tutti
   - Mostra statistiche

2. **Esegui `supabase/update-customer-get-card.sql`**
   - Aggiorna funzione per creare automaticamente

3. **Ricarica la pagina `/account`**

---

## 📊 Verifica Manuale

Dopo il fix, verifica:

```sql
-- Verifica il tuo utente specifico
SELECT 
    u.email,
    p.id IS NOT NULL as has_profile,
    lc.id IS NOT NULL as has_card,
    lc.public_code,
    lc.points_int
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
LEFT JOIN public.loyalty_cards lc ON p.id = lc.user_id
WHERE u.email = 'tua@email.com';
```

Dovresti vedere:
- `has_profile = true`
- `has_card = true`
- `public_code` presente (lunga stringa)
- `points_int = 0`

---

## 🎯 Checklist Completa

- [ ] Eseguito `diagnose-missing-card.sql` per capire il problema
- [ ] Eseguito `fix-all-missing.sql` per fixare tutto
- [ ] Eseguito `update-customer-get-card.sql` per aggiornare funzione
- [ ] Verificato con query manuale che tessera esista
- [ ] Ricaricato pagina `/account`
- [ ] Tessera visualizzata correttamente

---

## ⚠️ Se Ancora Non Funziona

1. **Controlla Log Supabase**:
   - Dashboard → **Logs** → **Postgres Logs**
   - Cerca errori durante la creazione

2. **Verifica Permessi**:
   - Le policy RLS devono permettere INSERT
   - La funzione deve essere `SECURITY DEFINER`

3. **Test Manuale**:
   ```sql
   -- Prova a creare manualmente
   INSERT INTO public.loyalty_cards (user_id, public_code)
   VALUES (
       auth.uid(),
       REPLACE(uuid_generate_v4()::TEXT, '-', '')
   );
   ```
   
   Se questo funziona, il problema è nella funzione/trigger.
   Se non funziona, il problema è nelle policy RLS.

---

**Dopo aver eseguito `fix-all-missing.sql` e `update-customer-get-card.sql`, la tessera dovrebbe essere creata automaticamente!**
