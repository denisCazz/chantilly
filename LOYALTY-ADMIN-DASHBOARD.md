# 📊 Dashboard Admin - Guida

## 🎯 Funzionalità

La dashboard admin include:

### 📈 Statistiche in Tempo Reale
- **Clienti Totali**: Numero totale di clienti registrati
- **Tessere Attive**: Numero di tessere fedeltà create
- **Punti Distribuiti**: Totale punti assegnati
- **Premi Riscattati**: Numero di premi riscattati
- **Tessere con Punti**: Clienti con saldo > 0
- **Pronti per Premio**: Clienti con almeno 10 punti
- **Nuovi (7 giorni)**: Nuove registrazioni nell'ultima settimana
- **Transazioni (7 giorni)**: Movimenti punti nell'ultima settimana

### 🔍 Ricerca Cliente
- Cerca per **email**
- Cerca per **nome** (se presente)
- Cerca per **codice tessera**
- Risultati in tempo reale
- Pulsante "Gestisci" per aprire direttamente la gestione punti

### 👥 Clienti Recenti
- Lista degli ultimi 10 clienti registrati
- Mostra email, nome, data registrazione
- Mostra saldo punti corrente
- Accesso rapido alla gestione punti

### 📷 Scanner QR Code
- Integrato nella dashboard
- Accesso rapido per scansionare tessere

---

## 🚀 Setup

### 1. Esegui Funzioni RPC

1. Vai su **Supabase Dashboard** → **SQL Editor**
2. Apri `supabase/admin-stats-rpc.sql`
3. Copia tutto il contenuto e incolla
4. Clicca **Run**

Questo crea 3 funzioni RPC:
- `admin_get_stats()` - Statistiche dashboard
- `admin_get_recent_customers()` - Clienti recenti
- `admin_search_customer()` - Ricerca clienti

### 2. Verifica

Dopo aver eseguito lo script, verifica:

```sql
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE 'admin_%';
```

Dovresti vedere:
- ✅ `admin_get_stats`
- ✅ `admin_get_recent_customers`
- ✅ `admin_search_customer`

---

## 📱 Utilizzo

### Accesso Dashboard

1. Accedi come **admin** o **staff** su `/admin`
2. Vedi automaticamente la dashboard con statistiche
3. Scanner QR disponibile in basso

### Ricerca Cliente

1. Inserisci email, nome o codice tessera nel campo ricerca
2. Clicca "Cerca"
3. Vedi risultati con info cliente
4. Clicca "Gestisci" per aprire la gestione punti

### Gestione Cliente da Ricerca

1. Cerca il cliente
2. Clicca "Gestisci" sul cliente
3. Vedi automaticamente le azioni (+1, -1, riscatta)
4. Il codice tessera viene precompilato

---

## 🎨 Layout Dashboard

```
┌─────────────────────────────────────┐
│  Dashboard Amministrazione  [🔄]   │
├─────────────────────────────────────┤
│                                     │
│  [Statistiche in Grid 2x4]         │
│  👥 Clienti    💳 Tessere          │
│  ⭐ Punti      🎁 Premi            │
│  🔥 Attive    🏆 Pronti            │
│  📈 Nuovi     📊 Transazioni       │
│                                     │
├─────────────────────────────────────┤
│  🔍 Cerca Cliente                   │
│  [Input ricerca] [Cerca]           │
│  [Risultati se presenti]           │
├─────────────────────────────────────┤
│  👥 Clienti Recenti                 │
│  [Lista ultimi 10 clienti]         │
├─────────────────────────────────────┤
│  📷 Scanner QR Code                 │
│  [Scanner component]                │
└─────────────────────────────────────┘
```

---

## 🔒 Sicurezza

- ✅ Solo utenti con ruolo `staff` o `admin` possono accedere
- ✅ Tutte le funzioni RPC verificano il ruolo server-side
- ✅ RLS attivo: le query rispettano le policy di sicurezza
- ✅ Nessun dato sensibile esposto al client

---

## 🐛 Troubleshooting

### Errore: "function does not exist"

**Causa**: Funzioni RPC non create.

**Soluzione**: Esegui `supabase/admin-stats-rpc.sql` in SQL Editor.

### Statistiche non si aggiornano

**Causa**: Cache del browser o dati non aggiornati.

**Soluzione**: 
1. Clicca "🔄 Aggiorna"
2. Ricarica la pagina (F5)

### Ricerca non trova clienti

**Causa**: 
- Cliente non esiste
- Email/nome non corrisponde

**Soluzione**:
- Verifica che il cliente sia registrato
- Prova a cercare solo parte dell'email
- Il codice tessera deve essere completo

---

## 📊 Statistiche Dettagliate

### Calcoli

- **Punti Distribuiti**: Somma di tutti i `delta > 0` nel ledger
- **Punti Riscattati**: Somma di tutti i `delta < 0` nel ledger
- **Tessere Attive**: Tessere con `points_int > 0`
- **Pronti per Premio**: Tessere con `points_int >= 10`

### Aggiornamento

Le statistiche vengono calcolate in tempo reale ogni volta che:
- Carichi la dashboard
- Clicchi "🔄 Aggiorna"

---

**La dashboard è ora completamente funzionale!** 🎉
