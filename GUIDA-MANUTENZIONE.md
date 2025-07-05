# 📋 Guida Completa - Bar Chantilly Website

## 🎯 Panoramica del Progetto

Il sito web del **Bar Tabaccheria Chantilly** è stato realizzato con **Astro 5+** per garantire:
- **Performance ottimali** (caricamento veloce)
- **SEO ottimizzato** (indicizzazione sui motori di ricerca)
- **Accessibilità completa** (utilizzabile da tutti)
- **Design responsive** (perfetto su tutti i dispositivi)

---

## 🏗️ Struttura del Progetto

```
chanty/
├── src/
│   ├── components/          # Componenti riutilizzabili
│   │   ├── Header.astro     # Navigazione principale
│   │   ├── Hero.astro       # Sezione di benvenuto
│   │   ├── About.astro      # Chi siamo
│   │   ├── Services.astro   # Servizi offerti
│   │   ├── QRMenu.astro     # Sezione QR Code menu
│   │   ├── Hours.astro      # Orari di apertura
│   │   ├── Reviews.astro    # Recensioni clienti
│   │   ├── Contact.astro    # Contatti e mappa
│   │   ├── Footer.astro     # Piè di pagina
│   │   └── Scripts.astro    # JavaScript e animazioni
│   ├── layouts/
│   │   └── Layout.astro     # Layout base con meta tag
│   └── pages/
│       ├── index.astro      # Homepage
│       └── menu/
│           └── index.astro  # Pagina menu dedicata
├── public/
│   ├── favicon.svg          # Icona del sito
│   ├── robots.txt           # SEO crawling rules
│   └── sitemap.xml          # Mappa del sito per SEO
└── qr-generator.html        # Tool per generare QR Code
```

---

## 🚀 Come Avviare il Sito

### Sviluppo Locale
```bash
cd /path/to/chanty
npm run dev
```
Il sito sarà disponibile su: `http://localhost:4321`

### Build di Produzione
```bash
npm run build
npm run preview
```

---

## 📱 Pagine e Funzionalità

### 🏠 **Homepage** (`/`)
- **Hero Section**: Benvenuto accogliente
- **Chi Siamo**: Presentazione del bar
- **Servizi**: Tutti i servizi offerti
- **QR Menu**: Accesso rapido al menu digitale
- **Orari**: Orari di apertura settimanali
- **Recensioni**: Testimonianze clienti
- **Contatti**: Mappa e informazioni

### 🍽️ **Menu Digitale** (`/menu/`)
- **Design dedicato** ottimizzato per mobile
- **Categorie organizzate**: Caffetteria, Bevande, Snack, Dolci
- **Prezzi aggiornati** facilmente modificabili
- **Offerte speciali** in evidenza
- **Link di ritorno** alla homepage

---

## 🎨 Personalizzazione

### Colori del Brand
I colori sono definiti in `/src/layouts/Layout.astro`:
```css
:root {
  --color-primary: #8B4513;    /* Marrone elegante */
  --color-secondary: #D2691E;  /* Arancione caldo */
  --color-accent: #F4A460;     /* Beige chiaro */
  --color-warm: #FFF8DC;       /* Crema */
}
```

### Modifica Contenuti

#### ✏️ **Aggiornare Menu e Prezzi**
File: `/src/pages/menu/index.astro`
- Modifica le sezioni `menu-category`
- Aggiorna `item-name`, `item-description`, `item-price`

#### ⏰ **Cambiare Orari**
File: `/src/components/Hours.astro`
- Modifica la sezione `hours-row`
- Evidenzia i giorni chiusi con classe `closed`

#### 📞 **Aggiornare Contatti**
File: `/src/components/Contact.astro`
- Numero telefono: cerca `tel:+390112966215`
- Indirizzo: modifica `Viale Barbaroux, 68`
- Mappa: aggiorna l'URL dell'iframe

#### ⭐ **Modificare Recensioni**
File: `/src/components/Reviews.astro`
- Aggiungi/rimuovi `review-card`
- Mantieni il formato con `review-text` e `review-author`

---

## 📱 Tag NFC e QR Code

### Setup per Tag NFC
1. **Apri** `qr-generator.html` nel browser
2. **Genera** il QR Code per `https://bar-chantilly.it/menu/`
3. **Programma** i tag NFC con l'URL del menu
4. **Posiziona** i tag sui tavoli del bar

### URL da programmare nei tag:
```
https://bar-chantilly.it/menu/
```

### Vantaggi del Menu Digitale:
- ✅ Accesso immediato senza app
- ✅ Sempre aggiornato
- ✅ Funziona su qualsiasi smartphone
- ✅ Riduce l'uso di menu cartacei
- ✅ Facile da aggiornare

---

## 🔧 Manutenzione

### Aggiornamenti Regolari
- **Menu**: Controlla prezzi mensilmente
- **Orari**: Aggiorna per festività
- **Recensioni**: Aggiungi nuove testimonianze
- **Offerte**: Modifica promozioni stagionali

### SEO e Performance
- **Sitemap**: Aggiorna `/public/sitemap.xml` per nuove pagine
- **Meta tag**: Modifica descriptions in `Layout.astro`
- **Immagini**: Ottimizza dimensioni per velocità

### Backup
```bash
# Backup del codice
git add .
git commit -m "Aggiornamento contenuti [data]"
git push

# Backup database (se applicabile)
# Non necessario per questo sito statico
```

---

## 🌐 Deploy e Hosting

### Opzioni Consigliate:
1. **Netlify** (gratuito) - Collegamento diretto da Git
2. **Vercel** (gratuito) - Deploy automatico
3. **GitHub Pages** (gratuito) - Per repository pubblici

### Processo di Deploy:
```bash
npm run build
# Upload cartella /dist/ al provider hosting
```

---

## 📊 Analytics e Monitoraggio

### Metriche da Monitorare:
- **Visite totali** e pagine viste
- **Tempo di permanenza** sulla pagina menu
- **Dispositivi utilizzati** (mobile vs desktop)
- **Orari di maggior traffico**

### Tools Consigliati:
- **Google Analytics 4** per statistiche dettagliate
- **Google Search Console** per SEO
- **PageSpeed Insights** per performance

---

## 🆘 Risoluzione Problemi

### Problemi Comuni:

#### Il sito non si carica
```bash
# Verifica dipendenze
npm install

# Riavvia server
npm run dev
```

#### Errori di build
```bash
# Pulisci cache
rm -rf node_modules dist .astro
npm install
npm run build
```

#### Menu non aggiornato
- Controlla modifiche in `/src/pages/menu/index.astro`
- Verifica sintassi HTML
- Ribuilld: `npm run build`

---

## 📞 Supporto Tecnico

### Contatti per Assistenza:
- **Sviluppatore**: [info tecnico]
- **Hosting**: [provider dettagli]
- **Dominio**: [registrar info]

### File di Log:
- Errori build: Console del terminale
- Errori runtime: DevTools del browser (F12)

---

## 🔒 Sicurezza

### Best Practices:
- ✅ **HTTPS obbligatorio** per tutti i domini
- ✅ **Backup regolari** del codice
- ✅ **Aggiornamenti** dipendenze periodici
- ✅ **Monitoraggio** uptime del sito

---

## 📈 Roadmap Future

### Possibili Miglioramenti:
- 🎯 **Sistema prenotazioni** online
- 🎯 **Galleria foto** prodotti
- 🎯 **Newsletter** per offerte
- 🎯 **Integrazione social** automatica
- 🎯 **Chat bot** per informazioni base

---

*📝 Ultimo aggiornamento: 5 Luglio 2025*
*✨ Realizzato con Astro 5+ per Bar Tabaccheria Chantilly*
