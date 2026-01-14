import { useState, useEffect, useRef } from 'react';
import { Html5Qrcode } from 'html5-qrcode';

interface AdminScannerProps {
  onScanSuccess: (code: string) => void;
  onError?: (error: string) => void;
}

export default function AdminScanner({ onScanSuccess, onError }: AdminScannerProps) {
  const [scanning, setScanning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [cameraReady, setCameraReady] = useState(false);
  const scannerRef = useRef<Html5Qrcode | null>(null);
  const scannerId = 'admin-qr-scanner';

  useEffect(() => {
    return () => {
      // Cleanup on unmount
      if (scannerRef.current) {
        scannerRef.current.clear();
      }
    };
  }, []);

  const startScan = async () => {
    try {
      setError(null);
      setScanning(true); // Imposta subito scanning a true per feedback immediato
      
      // Pulisci eventuali scanner precedenti
      const element = document.getElementById(scannerId);
      if (element) {
        element.innerHTML = '';
      }

      const html5QrCode = new Html5Qrcode(scannerId);
      scannerRef.current = html5QrCode;

      // Avvia la camera direttamente - la richiesta permessi appare automaticamente
      await html5QrCode.start(
        { facingMode: 'environment' }, // Camera posteriore
        {
          fps: 10,
          qrbox: { width: 250, height: 250 },
          aspectRatio: 1.0,
          disableFlip: true // Disabilita il ribaltamento automatico
        },
        (decodedText) => {
          // QR code letto con successo
          stopScan();
          onScanSuccess(decodedText);
        },
        (errorMessage) => {
          // Ignora errori di scanning continuo (non è un errore critico)
          // Solo log per debug, non mostrare all'utente
          console.debug('Scan error (ignored):', errorMessage);
        }
      );

      // La camera è partita con successo
      setCameraReady(true);
      
      // Nascondi eventuali elementi duplicati o che si ribaltano
      setTimeout(() => {
        const element = document.getElementById(scannerId);
        if (element) {
          // Rimuovi eventuali video duplicati o canvas che si ribaltano
          const videos = element.querySelectorAll('video');
          const canvases = element.querySelectorAll('canvas');
          
          // Mantieni solo il primo video e il primo canvas
          if (videos.length > 1) {
            for (let i = 1; i < videos.length; i++) {
              videos[i].remove();
            }
          }
          if (canvases.length > 1) {
            for (let i = 1; i < canvases.length; i++) {
              canvases[i].remove();
            }
          }
          
          // Rimuovi eventuali div con transform o flip
          const allDivs = element.querySelectorAll('div');
          allDivs.forEach((div: Element) => {
            const style = window.getComputedStyle(div);
            if (style.transform && (style.transform.includes('scaleX(-1)') || style.transform.includes('rotate'))) {
              // Rimuovi solo se non contiene il video principale
              if (!div.querySelector('video') && !div.querySelector('canvas')) {
                div.remove();
              }
            }
          });
        }
      }, 500);
    } catch (err: any) {
      // Gestione errori più dettagliata
      let errorMsg = 'Errore nell\'avvio della camera';
      
      if (err?.name === 'NotAllowedError' || err?.message?.includes('permission')) {
        errorMsg = 'Permessi fotocamera negati. Controlla le impostazioni del browser.';
      } else if (err?.name === 'NotFoundError' || err?.message?.includes('camera')) {
        errorMsg = 'Nessuna fotocamera trovata sul dispositivo.';
      } else if (err?.message) {
        errorMsg = err.message;
      }
      
      setError(errorMsg);
      setScanning(false);
      if (onError) onError(errorMsg);
    }
  };

  const stopScan = async () => {
    if (scannerRef.current) {
      try {
        await scannerRef.current.stop();
        scannerRef.current.clear();
      } catch (err) {
        // Ignora errori di stop - potrebbe essere già fermato
        console.debug('Stop scan error (ignored):', err);
      }
      scannerRef.current = null;
    }
    setScanning(false);
    setCameraReady(false);
    
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
          <button onClick={startScan} className="scanner-btn-start">
            <svg className="scanner-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M3 7V5C3 3.89543 3.89543 3 5 3H7M7 21H5C3.89543 21 3 20.1046 3 19V17M21 17V19C21 20.1046 20.1046 21 19 21H17M17 3H19C20.1046 3 21 3.89543 21 5V7M9 12C9 10.3431 10.3431 9 12 9C13.6569 9 15 10.3431 15 12C15 13.6569 13.6569 15 12 15C10.3431 15 9 13.6569 9 12Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
            <span>Avvia Scanner QR</span>
            <svg className="scanner-arrow" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <path d="M5 12H19M19 12L12 5M19 12L12 19" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
            </svg>
          </button>
        ) : (
          <button onClick={stopScan} className="scanner-btn-stop">
            <svg className="scanner-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
              <rect x="6" y="6" width="12" height="12" rx="2" stroke="currentColor" strokeWidth="2"/>
            </svg>
            <span>Ferma Scanner</span>
          </button>
        )}
        
        <div className="scanner-divider">
          <span className="divider-line"></span>
          <span className="divider-text">oppure</span>
          <span className="divider-line"></span>
        </div>
        
        <div className="manual-input-wrapper">
          <svg className="input-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M21 21L15 15M17 10C17 13.866 13.866 17 10 17C6.13401 17 3 13.866 3 10C3 6.13401 6.13401 3 10 3C13.866 3 17 6.13401 17 10Z" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
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
      </div>

      {error && (
        <div className="scanner-error">
          <svg className="error-icon" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="2"/>
            <path d="M12 8V12M12 16H12.01" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/>
          </svg>
          {error}
        </div>
      )}

      {scanning && !error && !cameraReady && (
        <div className="scanner-loading">
          <div className="loading-spinner"></div>
          <p>Avvio fotocamera...</p>
        </div>
      )}

      <div id={scannerId} className="qr-scanner-container"></div>
    </div>
  );
}
