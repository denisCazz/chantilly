# 🚀 Quick Start - Sistema Tessera Fedeltà

## Setup Rapido (5 minuti)

### 1. Crea Progetto Supabase
- Vai su https://app.supabase.com
- Crea nuovo progetto
- Copia **Project URL** e **anon key**

### 2. Configura Ambiente
Crea file `.env` nella root:
```env
PUBLIC_SUPABASE_URL=https://xxxxx.supabase.co
PUBLIC_SUPABASE_ANON_KEY=eyJhbGc...
```

### 3. Deploy Database
1. Dashboard Supabase → **SQL Editor**
2. Apri `supabase/schema.sql`
3. Copia tutto e incolla in SQL Editor
4. Clicca **Run**

### 4. Crea Utente Staff
1. **Authentication** → **Users** → **Add user**
2. Crea utente con email (es: `staff@chantilly.it`)
3. **SQL Editor** → Esegui:
```sql
UPDATE public.profiles 
SET role = 'staff' 
WHERE email = 'staff@chantilly.it';
```

### 5. Test
- Cliente: `http://localhost:4321/account` → Registrati
- Staff: `http://localhost:4321/admin` → Accedi con utente staff

---

## 📁 File Creati

```
src/
├── lib/
│   └── supabaseClient.ts          # Client Supabase
├── components/loyalty/
│   ├── AuthGate.tsx               # Guard autenticazione
│   ├── CustomerCard.tsx           # Tessera cliente
│   ├── AdminScanner.tsx           # Scanner QR staff
│   ├── AdminActions.tsx            # Azioni staff (+1, -1, riscatta)
│   └── AdminPanel.tsx             # Container admin
├── pages/
│   ├── account.astro              # Pagina cliente
│   └── admin.astro                # Pagina staff
└── styles/
    └── loyalty.css                # Stili sistema

supabase/
└── schema.sql                     # Schema database completo
```

---

## 🔑 Funzionalità

### Area Cliente (`/account`)
- ✅ Registrazione/Login
- ✅ Visualizza tessera con QR code
- ✅ Saldo punti in tempo reale
- ✅ Storico movimenti
- ✅ Storico riscatti

### Area Staff (`/admin`)
- ✅ Scanner QR code (camera)
- ✅ Input manuale codice
- ✅ Aggiungi punto (+1)
- ✅ Rimuovi punto (-1)
- ✅ Riscatta premio (scala 10 punti)
- ✅ Info cliente in tempo reale

---

## 🛡️ Sicurezza

- ✅ **RLS attivo**: Cliente vede solo i propri dati
- ✅ **RPC functions**: Tutte le operazioni passano da funzioni server-side
- ✅ **Ruoli**: `customer`, `staff`, `admin`
- ✅ **Anti-abuso**: Max 1 punto ogni 5 minuti per card

---

## 📚 Documentazione Completa

Vedi `LOYALTY-SETUP.md` per:
- Setup dettagliato
- Troubleshooting
- Struttura database
- Best practices

---

## ⚠️ Note Importanti

1. **Variabili d'ambiente**: Il prefisso `PUBLIC_` è obbligatorio per Astro
2. **Build**: Funziona anche senza variabili (usa placeholder)
3. **Runtime**: Le variabili sono necessarie per funzionare
4. **HTTPS**: Richiesto per camera/scanner QR in produzione

---

**Pronto!** 🎉 Il sistema è completamente funzionale.
