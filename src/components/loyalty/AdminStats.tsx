import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabaseClient';

interface Stats {
  total_customers: number;
  total_cards: number;
  total_points_distributed: number;
  total_points_redeemed: number;
  total_redemptions: number;
  active_cards: number;
  cards_with_10_plus_points: number;
  recent_registrations: number;
  recent_transactions: number;
}

export default function AdminStats() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadStats();
  }, []);

  const loadStats = async () => {
    try {
      setLoading(true);
      
      const { data: statsData, error: statsError } = await supabase.rpc('admin_get_stats');
      if (!statsError && statsData) {
        setStats(statsData as Stats);
      } else if (statsError) {
        console.error('Errore caricamento statistiche:', statsError);
      }
    } catch (err) {
      console.error('Errore caricamento statistiche:', err);
    } finally {
      setLoading(false);
    }
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

  if (loading) {
    return (
      <div className="admin-stats-loading">
        <div className="loading-spinner"></div>
        <p>Caricamento statistiche...</p>
      </div>
    );
  }

  return (
    <div className="admin-stats">
      <div className="stats-header">
        <h2>Statistiche Sistema</h2>
        <div className="stats-actions">
          <button onClick={loadStats} className="btn btn-secondary btn-refresh">
            Aggiorna
          </button>
          <a href="/admin" className="btn btn-secondary">
            Torna alla Dashboard
          </a>
          <button onClick={handleLogout} className="btn btn-logout">
            Esci
          </button>
        </div>
      </div>

      {stats && (
        <div className="stats-grid">
          <div className="stat-card">
            <div className="stat-icon">👥</div>
            <div className="stat-content">
              <div className="stat-value">{stats.total_customers}</div>
              <div className="stat-label">Clienti Totali</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">💳</div>
            <div className="stat-content">
              <div className="stat-value">{stats.total_cards}</div>
              <div className="stat-label">Tessere Attive</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">⭐</div>
            <div className="stat-content">
              <div className="stat-value">{stats.total_points_distributed}</div>
              <div className="stat-label">Punti Distribuiti</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">🎁</div>
            <div className="stat-content">
              <div className="stat-value">{stats.total_redemptions}</div>
              <div className="stat-label">Premi Riscattati</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">🔥</div>
            <div className="stat-content">
              <div className="stat-value">{stats.active_cards}</div>
              <div className="stat-label">Tessere con Punti</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">🏆</div>
            <div className="stat-content">
              <div className="stat-value">{stats.cards_with_10_plus_points}</div>
              <div className="stat-label">Pronti per Premio</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">📈</div>
            <div className="stat-content">
              <div className="stat-value">{stats.recent_registrations}</div>
              <div className="stat-label">Nuovi (7 giorni)</div>
            </div>
          </div>

          <div className="stat-card">
            <div className="stat-icon">📊</div>
            <div className="stat-content">
              <div className="stat-value">{stats.recent_transactions}</div>
              <div className="stat-label">Transazioni (7 giorni)</div>
            </div>
          </div>
        </div>
      )}

      {!stats && !loading && (
        <div className="empty-state">
          <p>Nessuna statistica disponibile</p>
        </div>
      )}
    </div>
  );
}
