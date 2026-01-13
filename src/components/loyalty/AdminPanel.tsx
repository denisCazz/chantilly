import { useState, useEffect } from 'react';
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
    if (codeFromUrl) {
      setScannedCode(codeFromUrl);
      setShowDashboard(false);
    } else {
      // Assicurati che la dashboard sia visibile al primo accesso
      setScannedCode('');
      setShowDashboard(true);
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
      {scannedCode ? (
        <div className="scanned-result">
          <div className="scanned-code-display">
            <p>Codice Tessera: <strong>{scannedCode}</strong></p>
          </div>
          <AdminActions publicCode={scannedCode} onReset={handleReset} />
        </div>
      ) : (
        <>
          <AdminDashboard />
          <div className="scanner-section">
            <h3>Scanner QR Code</h3>
            <AdminScanner onScanSuccess={handleScanSuccess} />
          </div>
        </>
      )}
    </div>
  );
}
