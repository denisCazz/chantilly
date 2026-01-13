import { useState, useEffect } from 'react';
import AdminScanner from './AdminScanner';
import AdminActions from './AdminActions';
import AdminDashboard from './AdminDashboard';

export default function AdminPanel() {
  const [scannedCode, setScannedCode] = useState<string>('');
  const [showDashboard, setShowDashboard] = useState(true);

  useEffect(() => {
    // Controlla se c'è un codice nell'URL
    const params = new URLSearchParams(window.location.search);
    const codeFromUrl = params.get('code');
    if (codeFromUrl) {
      setScannedCode(codeFromUrl);
      setShowDashboard(false);
    }
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

  return (
    <div className="admin-panel">
      {showDashboard && !scannedCode ? (
        <>
          <AdminDashboard />
          <div className="scanner-section">
            <h3>📷 Scanner QR Code</h3>
            <AdminScanner onScanSuccess={handleScanSuccess} />
          </div>
        </>
      ) : scannedCode ? (
        <div className="scanned-result">
          <div className="scanned-code-display">
            <p>Codice Tessera: <strong>{scannedCode}</strong></p>
          </div>
          <AdminActions publicCode={scannedCode} onReset={handleReset} />
        </div>
      ) : null}
    </div>
  );
}
