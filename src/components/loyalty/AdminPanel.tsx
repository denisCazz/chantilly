import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import AdminScanner from './AdminScanner';
import AdminActions from './AdminActions';
import AdminDashboard from './AdminDashboard';

export default function AdminPanel() {
  const [scannedCode, setScannedCode] = useState<string>('');
  const [showDashboard, setShowDashboard] = useState(true);
  const [initialized, setInitialized] = useState(false);

  useEffect(() => {
    // Controlla se c'è un codice nell'URL
    const params = new URLSearchParams(window.location.search);
    const codeFromUrl = params.get('code');
    
    // Inizializza sempre con dashboard visibile, a meno che non ci sia un codice nell'URL
    if (codeFromUrl && codeFromUrl.trim() !== '') {
      setScannedCode(codeFromUrl);
      setShowDashboard(false);
    } else {
      // Assicurati che la dashboard sia visibile al primo accesso
      // Pulisci anche eventuali parametri nell'URL
      setScannedCode('');
      setShowDashboard(true);
      // Rimuovi eventuali parametri code dall'URL
      if (window.location.search.includes('code=')) {
        window.history.replaceState({}, '', '/admin');
      }
    }
    
    setInitialized(true);
  }, []);

  const handleScanSuccess = (code: string) => {
    setScannedCode(code);
    setShowDashboard(false);
  };

  const handleReset = () => {
    setScannedCode('');
    setShowDashboard(true);
    // Rimuovi codice dall'URL
    window.history.replaceState({}, '', '/admin');
  };

  const handleLogout = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) {
        console.error('Errore durante il logout:', error);
      }
      window.location.replace('/');
    } catch (error) {
      console.error('Errore durante il logout:', error);
      window.location.replace('/');
    }
  };

  // Mostra loading fino a quando non è inizializzato
  if (!initialized) {
    return (
      <div className="admin-loading">
        <div className="loading-spinner"></div>
        <p>Caricamento...</p>
      </div>
    );
  }

  return (
    <div className="admin-panel">
      <div className="admin-header-actions">
        <button onClick={handleLogout} className="admin-logout-btn">
          <svg className="logout-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M9 21H5C4.46957 21 3.96086 20.7893 3.58579 20.4142C3.21071 20.0391 3 19.5304 3 19V5C3 4.46957 3.21071 3.96086 3.58579 3.58579C3.96086 3.21071 4.46957 3 5 3H9M16 17L21 12M21 12L16 7M21 12H9" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          <span>Esci</span>
        </button>
      </div>
      {scannedCode ? (
        <div className="scanned-result">
          <AdminActions publicCode={scannedCode} onReset={handleReset} />
        </div>
      ) : (
        <>
          <div className="scanner-section">
            <div className="scanner-header">
              <h3>Scanner QR Code</h3>
              <p className="scanner-info">Clicca sul pulsante per avviare la fotocamera e scansionare il codice QR della tessera fedeltà</p>
            </div>
            <AdminScanner onScanSuccess={handleScanSuccess} />
          </div>
          <AdminDashboard />
        </>
      )}
    </div>
  );
}
