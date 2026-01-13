import { useState, useEffect, useRef } from 'react';
import { Html5QrcodeScanner } from 'html5-qrcode';

interface AdminScannerProps {
  onScanSuccess: (code: string) => void;
  onError?: (error: string) => void;
}

export default function AdminScanner({ onScanSuccess, onError }: AdminScannerProps) {
  const [scanning, setScanning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);
  const scannerId = 'admin-qr-scanner';

  useEffect(() => {
    return () => {
      // Cleanup on unmount
      if (scannerRef.current) {
        scannerRef.current.clear();
      }
    };
  }, []);

  const startScan = () => {
    try {
      setError(null);
      
      // Pulisci eventuali scanner precedenti
      const element = document.getElementById(scannerId);
      if (element) {
        element.innerHTML = '';
      }

      const html5QrCode = new Html5QrcodeScanner(
        scannerId,
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
          aspectRatio: 1.0,
          supportedScanTypes: [],
          videoConstraints: {
            facingMode: 'environment' // Camera posteriore di default
          }
        },
        false // verbose
      );

      scannerRef.current = html5QrCode;

      html5QrCode.render(
        (decodedText) => {
          // QR code letto con successo
          stopScan();
          onScanSuccess(decodedText);
        },
        (errorMessage) => {
          // Ignora errori di scanning continuo (non è un errore critico)
        }
      );

      setScanning(true);
    } catch (err) {
      const errorMsg = err instanceof Error ? err.message : 'Errore nell\'avvio della camera';
      setError(errorMsg);
      if (onError) onError(errorMsg);
    }
  };

  const stopScan = () => {
    if (scannerRef.current) {
      try {
        scannerRef.current.clear();
      } catch (err) {
        // Ignora errori di stop
      }
      scannerRef.current = null;
    }
    setScanning(false);
    
    // Pulisci il container
    const element = document.getElementById(scannerId);
    if (element) {
      element.innerHTML = '';
    }
  };

  const handleManualInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const code = e.target.value.trim();
    if (code.length > 0) {
      onScanSuccess(code);
      e.target.value = '';
    }
  };

  return (
    <div className="admin-scanner">
      <div className="scanner-controls">
        {!scanning ? (
          <button onClick={startScan} className="btn btn-primary scanner-btn">
            Avvia Scanner QR
          </button>
        ) : (
          <button onClick={stopScan} className="btn btn-secondary scanner-btn">
            Ferma Scanner
          </button>
        )}
        
        <div className="scanner-divider">oppure</div>
        
        <input
          type="text"
          placeholder="Inserisci codice tessera manualmente"
          onKeyPress={(e) => {
            if (e.key === 'Enter') {
              handleManualInput(e as any);
            }
          }}
          onChange={handleManualInput}
          className="manual-code-input"
        />
      </div>

      {error && (
        <div className="scanner-error">
          {error}
        </div>
      )}

      <div id={scannerId} className="qr-scanner-container"></div>
    </div>
  );
}
