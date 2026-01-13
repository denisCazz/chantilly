import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';

interface CustomerInfo {
  id: string;
  email: string;
  name: string;
}

interface CardInfo {
  card_id: string;
  new_balance: number;
  delta: number;
  customer: CustomerInfo;
}

interface Reward {
  id: string;
  name: string;
  cost_points: number;
}

interface AdminActionsProps {
  publicCode: string;
  onReset: () => void;
}

export default function AdminActions({ publicCode, onReset }: AdminActionsProps) {
  const [cardInfo, setCardInfo] = useState<CardInfo | null>(null);
  const [rewards, setRewards] = useState<Reward[]>([]);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [selectedReward, setSelectedReward] = useState<string>('');
  const [shortCode, setShortCode] = useState<string>('');

  useEffect(() => {
    if (publicCode) {
      loadRewards();
      loadShortCode();
    }
  }, [publicCode]);

  const loadShortCode = async () => {
    try {
      // Cerca la tessera per public_code o short_code
      const { data, error } = await supabase
        .from('loyalty_cards')
        .select('short_code, public_code')
        .or(`public_code.eq."${publicCode}",short_code.eq."${publicCode}"`)
        .maybeSingle();

      if (!error && data) {
        // Mostra short_code se disponibile, altrimenti mostra solo le prime 8 cifre del public_code
        if (data.short_code) {
          setShortCode(data.short_code);
        } else {
          // Se non c'è short_code, mostra solo le prime 8 cifre del public_code per brevità
          setShortCode(data.public_code.substring(0, 8) + '...');
        }
      } else {
        // In caso di errore o nessun risultato, mostra il codice fornito (potrebbe essere già short_code)
        setShortCode(publicCode.length <= 8 ? publicCode : publicCode.substring(0, 8) + '...');
      }
    } catch (err) {
      console.error('Errore nel caricamento del codice breve:', err);
      // In caso di errore, mostra il codice fornito
      setShortCode(publicCode.length <= 8 ? publicCode : publicCode.substring(0, 8) + '...');
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

  const showToast = (type: 'success' | 'error', text: string) => {
    setMessage({ type, text });
    setTimeout(() => setMessage(null), 3000);
  };

  const handleAction = async (delta: number, reason: string) => {
    setLoading(true);
    setMessage(null);

    try {
      const { data, error } = await supabase.rpc('staff_add_point', {
        p_code: publicCode,  // Accetta sia public_code che short_code
        p_delta: delta,
        p_reason: reason
      });

      if (error) {
        showToast('error', error.message);
        setLoading(false);
        return;
      }

      if (data) {
        setCardInfo(data as CardInfo);
        showToast('success', `Operazione completata! Nuovo saldo: ${data.new_balance} punti`);
      }
    } catch (err) {
      showToast('error', err instanceof Error ? err.message : 'Errore sconosciuto');
    } finally {
      setLoading(false);
    }
  };

  const handleRedeem = async () => {
    if (!selectedReward) {
      showToast('error', 'Seleziona un premio');
      return;
    }

    setLoading(true);
    setMessage(null);

    try {
      const { data, error } = await supabase.rpc('staff_redeem', {
        p_code: publicCode,  // Accetta sia public_code che short_code
        p_reward_id: selectedReward
      });

      if (error) {
        showToast('error', error.message);
        setLoading(false);
        return;
      }

      if (data) {
        showToast('success', `Premio riscattato: ${data.reward_name}! Nuovo saldo: ${data.new_balance} punti`);
        setCardInfo(null);
        setSelectedReward(rewards[0]?.id || '');
      }
    } catch (err) {
      showToast('error', err instanceof Error ? err.message : 'Errore sconosciuto');
    } finally {
      setLoading(false);
    }
  };

  if (!publicCode) {
    return null;
  }

  return (
    <div className="admin-actions">
      {message && (
        <div className={`toast toast-${message.type}`}>
          {message.type === 'success' ? '✅' : '❌'} {message.text}
        </div>
      )}

      <div className="customer-info-card">
        <h3>Cliente</h3>
        {shortCode && (
          <div className="card-code-display">
            <span className="code-label">Codice Tessera:</span>
            <span className="code-value">{shortCode}</span>
          </div>
        )}
        {cardInfo && (
          <>
            <p className="customer-name">{cardInfo.customer.name || cardInfo.customer.email}</p>
            <p className="customer-email">{cardInfo.customer.email}</p>
            <div className="current-balance">
              <span className="balance-label">Saldo Attuale:</span>
              <span className="balance-value">{cardInfo.new_balance} punti</span>
            </div>
          </>
        )}
      </div>

      <div className="action-buttons">
        <button
          onClick={() => handleAction(1, 'Consumazione')}
          disabled={loading}
          className="btn btn-action btn-add"
        >
          ➕ +1 Punto
        </button>

        <button
          onClick={() => handleAction(-1, 'Correzione')}
          disabled={loading || !cardInfo || cardInfo.new_balance <= 0}
          className="btn btn-action btn-remove"
        >
          ➖ -1 Punto
        </button>
      </div>

      {rewards.length > 0 && (
        <div className="redeem-section">
          <h4>Riscatta Premio</h4>
          <select
            value={selectedReward}
            onChange={(e) => setSelectedReward(e.target.value)}
            className="reward-select"
            disabled={loading}
          >
            {rewards.map((reward) => (
              <option key={reward.id} value={reward.id}>
                {reward.name} ({reward.cost_points} punti)
              </option>
            ))}
          </select>
          <button
            onClick={handleRedeem}
            disabled={loading || !cardInfo || cardInfo.new_balance < (rewards.find(r => r.id === selectedReward)?.cost_points || 0)}
            className="btn btn-action btn-redeem"
          >
            🎁 Riscatta Premio
          </button>
        </div>
      )}

      <button onClick={onReset} className="btn btn-secondary reset-btn">
        🔄 Scansiona Nuova Tessera
      </button>
    </div>
  );
}
