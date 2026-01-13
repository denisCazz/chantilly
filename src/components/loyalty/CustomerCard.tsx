import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';
import QRCode from 'qrcode';

interface CardData {
  card: {
    id: string;
    public_code: string;
    short_code: string;
    points: number;
    created_at: string;
  };
  ledger: Array<{
    id: number;
    delta: number;
    reason: string;
    created_at: string;
    staff_name: string | null;
  }>;
  redemptions: Array<{
    id: string;
    reward_name: string;
    cost: number;
    created_at: string;
    staff_name: string | null;
  }>;
}

interface Reward {
  id: string;
  name: string;
  cost_points: number;
}

export default function CustomerCard() {
  const [cardData, setCardData] = useState<CardData | null>(null);
  const [qrCodeUrl, setQrCodeUrl] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [selectedReward, setSelectedReward] = useState<string>('');
  const [redeeming, setRedeeming] = useState(false);
  const [redemptionMessage, setRedemptionMessage] = useState<{reward: string; date: string} | null>(null);

  useEffect(() => {
    loadCardData();
    loadRewards();
  }, []);


  const loadCardData = async () => {
    try {
      setLoading(true);
      setError(null);
      
      const { data, error: rpcError } = await supabase.rpc('customer_get_card');

      if (rpcError) {
        // Se l'errore è "Tessera non trovata", prova a ricaricare dopo un attimo
        // (la funzione ora la crea automaticamente, ma potrebbe servire un retry)
        if (rpcError.message.includes('Tessera non trovata')) {
          // Attendi un momento e riprova
          setTimeout(() => {
            loadCardData();
          }, 1000);
          return;
        }
        setError(rpcError.message);
        setLoading(false);
        return;
      }

      if (data) {
        setCardData(data as CardData);
        
        // Genera QR code
        const qrUrl = await QRCode.toDataURL(data.card.public_code, {
          width: 300,
          margin: 2,
          color: {
            dark: '#1a1a1a',
            light: '#ffffff'
          }
        });
        setQrCodeUrl(qrUrl);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Errore nel caricamento');
    } finally {
      setLoading(false);
    }
  };

  const loadRewards = async () => {
    const { data, error } = await supabase
      .from('rewards')
      .select('id, name, cost_points')
      .eq('active', true)
      .order('cost_points', { ascending: true });

    if (!error && data) {
      setRewards(data as Reward[]);
      if (data.length > 0) {
        setSelectedReward(data[0].id);
      }
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('it-IT', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatDateForMessage = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('it-IT', {
      weekday: 'long',
      day: '2-digit',
      month: 'long',
      year: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const handleRedeem = async () => {
    if (!selectedReward) {
      alert('Seleziona un premio');
      return;
    }

    const reward = rewards.find(r => r.id === selectedReward);
    if (!reward) return;

    if (cardData && cardData.card.points < reward.cost_points) {
      alert(`Punti insufficienti! Hai ${cardData.card.points} punti, servono ${reward.cost_points}`);
      return;
    }

    if (!confirm(`Confermi il riscatto di "${reward.name}" per ${reward.cost_points} punti?`)) {
      return;
    }

    setRedeeming(true);
    try {
      const { data, error } = await supabase.rpc('customer_redeem_reward', {
        p_reward_id: selectedReward
      });

      if (error) {
        alert('Errore: ' + error.message);
        setRedeeming(false);
        return;
      }

      if (data) {
        // Mostra messaggio con data/ora
        const now = new Date();
        setRedemptionMessage({
          reward: reward.name,
          date: formatDateForMessage(now.toISOString())
        });

        // Ricarica i dati della card
        await loadCardData();
      }
    } catch (err) {
      alert('Errore durante il riscatto: ' + (err instanceof Error ? err.message : 'Errore sconosciuto'));
    } finally {
      setRedeeming(false);
    }
  };


  const handleLogout = async () => {
    if (confirm('Sei sicuro di voler uscire?')) {
      await supabase.auth.signOut();
      window.location.href = '/';
    }
  };

  if (loading) {
    return (
      <div className="loyalty-loading">
        <div className="loading-spinner"></div>
        <p>Caricamento tessera...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="loyalty-error">
        <p>❌ {error}</p>
        <button onClick={loadCardData} className="btn btn-primary">Riprova</button>
      </div>
    );
  }

  if (!cardData) {
    return <div className="loyalty-error">Nessun dato disponibile</div>;
  }

  return (
    <div className="customer-card-container">
      <div className="profile-header">
        <h2>Il Tuo Profilo</h2>
        <button onClick={handleLogout} className="btn btn-secondary btn-logout">
          🚪 Esci
        </button>
      </div>

      <div className="loyalty-card">
        <div className="card-header">
          <h3>La Tua Tessera Fedeltà</h3>
          <div className="points-display">
            <span className="points-number">{cardData.card.points}</span>
            <span className="points-label">Punti</span>
          </div>
        </div>

        <div className="qr-section">
          <h4>QR Code Tessera</h4>
          {qrCodeUrl && (
            <div className="qr-code-wrapper">
              <img src={qrCodeUrl} alt="QR Code Tessera" className="qr-code-image" />
            </div>
          )}
          {cardData.card.short_code && (
            <div className="short-code-display">
              <p className="short-code-label">Codice Tessera:</p>
              <p className="short-code-value">{cardData.card.short_code}</p>
              <p className="short-code-hint">Puoi dettare questo codice alla cassa</p>
            </div>
          )}
          <p className="qr-code-text">Mostra questo QR code alla cassa per timbrare</p>
        </div>

        <div className="progress-bar">
          <div 
            className="progress-fill" 
            style={{ width: `${(cardData.card.points % 10) * 10}%` }}
          ></div>
          <span className="progress-text">
            {10 - (cardData.card.points % 10)} punti al prossimo premio
          </span>
        </div>
      </div>

      {rewards.length > 0 && (
        <div className="redeem-section">
          <h3>Riscatta Premio</h3>
          {redemptionMessage ? (
            <div className="redemption-success-message">
              <h4>Grazie! Premio Riscattato</h4>
              <p className="redemption-reward-name">{redemptionMessage.reward}</p>
              <p className="redemption-instruction">
                Mostra questo messaggio in cassa per riscattare il premio:
              </p>
              <div className="redemption-voucher">
                <p className="voucher-text">
                  <strong>Premio Riscattato:</strong> {redemptionMessage.reward}
                </p>
                <p className="voucher-date">
                  <strong>Data e Ora:</strong> {redemptionMessage.date}
                </p>
                {cardData && cardData.card.short_code && (
                  <p className="voucher-code">
                    <strong>Codice Tessera:</strong> {cardData.card.short_code}
                  </p>
                )}
              </div>
              <button 
                onClick={() => setRedemptionMessage(null)} 
                className="btn btn-primary"
              >
                Chiudi
              </button>
            </div>
          ) : (
            <>
              <select
                value={selectedReward}
                onChange={(e) => setSelectedReward(e.target.value)}
                className="reward-select"
                disabled={redeeming}
              >
                {rewards.map((reward) => (
                  <option key={reward.id} value={reward.id}>
                    {reward.name} ({reward.cost_points} punti)
                  </option>
                ))}
              </select>
              <button
                onClick={handleRedeem}
                disabled={redeeming || !cardData || cardData.card.points < (rewards.find(r => r.id === selectedReward)?.cost_points || 0)}
                className="btn btn-primary btn-redeem"
              >
                {redeeming ? 'Riscattando...' : 'Riscatta Premio'}
              </button>
              {cardData && selectedReward && (
                <p className="redeem-hint">
                  {cardData.card.points >= (rewards.find(r => r.id === selectedReward)?.cost_points || 0) 
                    ? 'Hai abbastanza punti per questo premio!' 
                    : `Ti servono ancora ${(rewards.find(r => r.id === selectedReward)?.cost_points || 0) - cardData.card.points} punti`}
                </p>
              )}
            </>
          )}
        </div>
      )}

      <div className="ledger-section">
        <h3>Storico Movimenti</h3>
        <div className="ledger-list">
          {cardData.ledger.length === 0 ? (
            <p className="empty-state">Nessun movimento ancora</p>
          ) : (
            cardData.ledger.map((entry) => (
              <div key={entry.id} className="ledger-entry">
                <div className="ledger-info">
                  <span className="ledger-reason">{entry.reason}</span>
                  <span className="ledger-date">{formatDate(entry.created_at)}</span>
                </div>
                <div className={`ledger-delta ${entry.delta > 0 ? 'positive' : 'negative'}`}>
                  {entry.delta > 0 ? '+' : ''}{entry.delta}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {cardData.redemptions.length > 0 && (
        <div className="redemptions-section">
          <h3>Premi Riscattati</h3>
          <div className="redemptions-list">
            {cardData.redemptions.map((redemption) => (
              <div key={redemption.id} className="redemption-entry">
                <div className="redemption-info">
                  <span className="redemption-name">{redemption.reward_name}</span>
                  <span className="redemption-date">{formatDate(redemption.created_at)}</span>
                </div>
                <span className="redemption-cost">-{redemption.cost} punti</span>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
