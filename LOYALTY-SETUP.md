# 🎯 Sistema Tessera Fedeltà - Guida Setup Completa

## 📋 Indice
1. [Prerequisiti](#prerequisiti)
2. [Setup Supabase](#setup-supabase)
3. [Configurazione Ambiente](#configurazione-ambiente)
4. [Deploy Database](#deploy-database)
5. [Creazione Utente Staff/Admin](#creazione-utente-staffadmin)
6. [Test del Sistema](#test-del-sistema)
7. [Troubleshooting](#troubleshooting)

---

## 🔧 Prerequisiti

- Account Supabase (gratuito): https://supabase.com
- Node.js 18+ e npm installati
- Progetto Astro configurato e funzionante

---

## 🚀 Setup Supabase

### 1. Crea un Nuovo Progetto Supabase

1. Vai su https://app.supabase.com
2. Clicca "New Project"
3. Compila:
   - **Name**: `bar-chantilly-loyalty` (o nome a scelta)
   - **Database Password**: scegli una password forte (salvala!)
   - **Region**: scegli la più vicina (es. `West Europe`)
4. Clicca "Create new project"
5. Attendi 2-3 minuti per il provisioning

### 2. Ottieni le Credenziali

1. Nel dashboard Supabase, vai su **Settings** → **API**
2. Copia:
   - **Project URL** (es: `https://xxxxx.supabase.co`)
   - **anon/public key** (chiave pubblica)

---

## ⚙️ Configurazione Ambiente

### 1. Crea File `.env`

Nella root del progetto, crea un file `.env`:

```bash
PUBLIC_SUPABASE_URL=https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
```

**⚠️ IMPORTANTE**: 
- Il prefisso `PUBLIC_` è obbligatorio per Astro
- Non committare `.env` nel repository (è già in `.gitignore`)

### 2. Verifica Installazione Dipendenze

```bash
npm install
```

Dovresti avere installato:
- `@supabase/supabase-js`
- `@astrojs/react`
- `react` e `react-dom`
- `html5-qrcode`
- `qrcode`

---

## 🗄️ Deploy Database

### Opzione A: SQL Editor (Consigliato)

1. Nel dashboard Supabase, vai su **SQL Editor**
2. Clicca "New Query"
3. Apri il file `supabase/schema.sql` dal progetto
4. Copia **tutto il contenuto** e incollalo nell'editor SQL
5. Clicca "Run" (o `Ctrl+Enter`)
6. Verifica che non ci siano errori

### Opzione B: Supabase CLI (Avanzato)

```bash
# Installa Supabase CLI
npm install -g supabase

# Login
supabase login

# Link al progetto
supabase link --project-ref your-project-ref

# Deploy schema
supabase db push
```

### Verifica Tabelle Create

Nel dashboard Supabase, vai su **Table Editor**. Dovresti vedere:
- ✅ `profiles`
- ✅ `loyalty_cards`
- ✅ `points_ledger`
- ✅ `rewards`
- ✅ `redemptions`

---

## 👤 Creazione Utente Staff/Admin

### Metodo 1: Via Dashboard Supabase (Consigliato)

1. Vai su **Authentication** → **Users**
2. Clicca "Add user" → "Create new user"
3. Inserisci:
   - **Email**: `staff@chantilly.it` (o email a scelta)
   - **Password**: scegli una password forte
   - **Auto Confirm User**: ✅ (spunta questa opzione)
4. Clicca "Create user"
5. Copia l'**User UID** (es: `a1b2c3d4-...`)

6. Vai su **SQL Editor** e esegui:

```sql
-- Sostituisci 'USER_UID_QUI' con l'UID copiato
UPDATE public.profiles
SET role = 'staff'
WHERE id = 'USER_UID_QUI';
```

Per creare un **admin**:

```sql
UPDATE public.profiles
SET role = 'admin'
WHERE id = 'USER_UID_QUI';
```

### Metodo 2: Via Registrazione + Update

1. Vai su `/account` e registrati con una email
2. Copia l'UID dalla tabella `auth.users` (SQL Editor)
3. Esegui l'UPDATE SQL come sopra

---

## ✅ Test del Sistema

### 1. Test Registrazione Cliente

1. Avvia il server: `npm run dev`
2. Vai su `http://localhost:4321/account`
3. Clicca "Registrati"
4. Inserisci email e password
5. Dovresti vedere:
   - ✅ Messaggio di conferma
   - ✅ Tessera con QR code
   - ✅ Saldo iniziale: 0 punti

### 2. Test Area Staff

1. Accedi con un utente **staff/admin** su `/admin`
2. Dovresti vedere lo scanner QR
3. Testa:
   - **Scanner**: clicca "Avvia Scanner QR" e scansiona il QR code di un cliente
   - **Input Manuale**: inserisci il `public_code` della tessera
4. Dopo lo scan, dovresti vedere:
   - ✅ Info cliente
   - ✅ Saldo punti
   - ✅ Pulsanti +1 / -1 / Riscatta

### 3. Test Operazioni

1. **Aggiungi Punto**:
   - Clicca "+1 Punto"
   - Verifica che il saldo aumenti
   - Controlla lo storico in `/account`

2. **Riscatta Premio**:
   - Assicurati che il cliente abbia almeno 10 punti
   - Seleziona un premio
   - Clicca "Riscatta Premio"
   - Verifica che il saldo diminuisca di 10 punti

3. **Anti-Abuso**:
   - Prova a cliccare "+1" due volte in rapida successione
   - Dovresti vedere un errore: "Troppo veloce: attendi 5 minuti"

---

## 🔍 Troubleshooting

### Errore: "Missing Supabase environment variables"

**Causa**: File `.env` mancante o variabili non configurate.

**Soluzione**:
1. Crea `.env` nella root
2. Aggiungi `PUBLIC_SUPABASE_URL` e `PUBLIC_SUPABASE_ANON_KEY`
3. Riavvia il server: `npm run dev`

### Errore: "Accesso negato: solo staff/admin"

**Causa**: L'utente non ha il ruolo corretto.

**Soluzione**:
1. Verifica il ruolo in `profiles`:
```sql
SELECT id, email, role FROM public.profiles WHERE email = 'tua@email.com';
```
2. Aggiorna il ruolo:
```sql
UPDATE public.profiles SET role = 'staff' WHERE email = 'tua@email.com';
```

### Errore: "Tessera non trovata"

**Causa**: La card non è stata creata automaticamente.

**Soluzione**:
1. Verifica che il trigger `on_auth_user_created` sia attivo:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```
2. Crea manualmente la card:
```sql
INSERT INTO public.loyalty_cards (user_id, public_code)
VALUES ('USER_UID', REPLACE(uuid_generate_v4()::TEXT, '-', ''));
```

### Camera non funziona (Scanner QR)

**Causa**: Permessi camera non concessi o browser non supportato.

**Soluzione**:
- Usa Chrome/Firefox (non Safari su iOS)
- Concedi permessi camera quando richiesto
- Usa l'input manuale come alternativa

### Errore RPC: "function does not exist"

**Causa**: Le funzioni RPC non sono state create.

**Soluzione**:
1. Verifica che lo schema SQL sia stato eseguito completamente
2. Controlla le funzioni:
```sql
SELECT routine_name FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE 'staff_%' OR routine_name LIKE 'customer_%';
```
3. Riesegui lo script SQL se mancanti

---

## 📊 Struttura Database

### Tabelle Principali

- **`profiles`**: Estende `auth.users` con ruolo
- **`loyalty_cards`**: Tessera fedeltà (1:1 con user)
- **`points_ledger`**: Storico movimenti (immutabile)
- **`rewards`**: Premi disponibili
- **`redemptions`**: Storico riscatti

### Flusso Operazioni

1. **Registrazione**: 
   - Trigger crea `profile` + `loyalty_card` automaticamente

2. **Aggiunta Punto**:
   - Staff chiama `staff_add_point()`
   - RPC inserisce in `points_ledger`
   - RPC aggiorna `loyalty_cards.points_int` atomico

3. **Riscatto**:
   - Staff chiama `staff_redeem()`
   - RPC verifica punti sufficienti
   - RPC inserisce `redemption` + movimento negativo in `ledger`
   - RPC aggiorna saldo

---

## 🔒 Sicurezza

### Row Level Security (RLS)

- ✅ Cliente può leggere solo i propri dati
- ✅ Staff può leggere tutti i dati
- ✅ Solo RPC possono scrivere (non client diretto)
- ✅ Tutte le RPC verificano ruolo server-side

### Best Practices

- ✅ Non esporre mai la `service_role_key` nel client
- ✅ Usa sempre `PUBLIC_SUPABASE_ANON_KEY` nel frontend
- ✅ Le RPC usano `SECURITY DEFINER` per controlli server-side
- ✅ Anti-abuso: limite 1 punto ogni 5 minuti per card

---

## 📝 Checklist Setup

- [ ] Progetto Supabase creato
- [ ] Credenziali copiate in `.env`
- [ ] Schema SQL eseguito senza errori
- [ ] Tabelle verificate in Table Editor
- [ ] Utente staff/admin creato e configurato
- [ ] Test registrazione cliente OK
- [ ] Test area staff OK
- [ ] Test operazioni (+1, riscatto) OK
- [ ] QR scanner funzionante (o input manuale)

---

## 🎉 Completato!

Il sistema è pronto. I clienti possono:
- Registrarsi su `/account`
- Visualizzare la tessera con QR code
- Vedere saldo e storico

Lo staff può:
- Accedere a `/admin`
- Scansionare QR code o inserire codice manualmente
- Aggiungere/rimuovere punti
- Gestire riscatti premi

---

**Supporto**: Per problemi, controlla i log del browser (F12) e i log Supabase (Dashboard → Logs).
