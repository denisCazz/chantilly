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

interface Customer {
  id: string;
  email: string;
  full_name: string | null;
  created_at: string;
  card: {
    id: string;
    public_code: string;
    short_code?: string;
    points: number;
  } | null;
}

export default function AdminDashboard() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [recentCustomers, setRecentCustomers] = useState<Customer[]>([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(true);
  const [searching, setSearching] = useState(false);

  useEffect(() => {
    loadDashboard();
  }, []);

  const loadDashboard = async () => {
    try {
      setLoading(true);
      
      // Carica statistiche
      const { data: statsData, error: statsError } = await supabase.rpc('admin_get_stats');
      if (!statsError && statsData) {
        setStats(statsData as Stats);
      }

      // Carica clienti recenti
      const { data: customersData, error: customersError } = await supabase.rpc('admin_get_recent_customers', {
        limit_count: 10
      });
      if (!customersError && customersData) {
        setRecentCustomers(customersData as Customer[]);
      }
    } catch (err) {
      console.error('Errore caricamento dashboard:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleSearch = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!searchTerm.trim()) {
      setSearchResults([]);
      return;
    }

    try {
      setSearching(true);
      const { data, error } = await supabase.rpc('admin_search_customer', {
        search_term: searchTerm.trim()
      });

      if (!error && data) {
        setSearchResults(data as Customer[]);
      }
    } catch (err) {
      console.error('Errore ricerca:', err);
    } finally {
      setSearching(false);
    }
  };

  const formatDate = (dateString: string) => {
    return new Date(dateString).toLocaleDateString('it-IT', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric'
    });
  };

  const handleLogout = async () => {
    try {
      const { error } = await supabase.auth.signOut();
      if (error) {
        console.error('Errore durante il logout:', error);
      }
      // Forza il reload completo per assicurarsi che la sessione sia cancellata
      window.location.replace('/');
    } catch (error) {
      console.error('Errore durante il logout:', error);
      // Anche in caso di errore, prova a reindirizzare
      window.location.replace('/');
    }
  };

  if (loading) {
    return (
      <div className="admin-dashboard-loading">
        <div className="loading-spinner"></div>
        <p>Caricamento dashboard...</p>
      </div>
    );
  }

  return (
    <div className="admin-dashboard">
      <div className="dashboard-header">
        <h2>Dashboard Amministrazione</h2>
        <div className="dashboard-actions">
          <button onClick={loadDashboard} className="btn btn-secondary btn-refresh">
            Aggiorna
          </button>
          <button onClick={handleLogout} className="btn btn-logout">
            Esci
          </button>
        </div>
      </div>

      {/* Statistiche */}
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

      {/* Ricerca Cliente */}
      <div className="dashboard-section">
        <h3>🔍 Cerca Cliente</h3>
        <form onSubmit={handleSearch} className="search-form">
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            placeholder="Cerca per email, nome o codice tessera..."
            className="search-input"
          />
          <button type="submit" disabled={searching} className="btn btn-primary">
            {searching ? 'Cercando...' : 'Cerca'}
          </button>
        </form>

        {searchResults.length > 0 && (
          <div className="search-results">
            <h4>Risultati ({searchResults.length})</h4>
            <div className="customers-list">
              {searchResults.map((customer) => (
                <div key={customer.id} className="customer-item">
                  <div className="customer-info">
                    <div className="customer-name">{customer.full_name || customer.email}</div>
                    <div className="customer-email">{customer.email}</div>
                    {customer.card && (
                      <div className="customer-card-info">
                        <span>Codice: <code>{customer.card.short_code || customer.card.public_code}</code></span>
                        <span>Punti: <strong>{customer.card.points}</strong></span>
                      </div>
                    )}
                  </div>
                  {customer.card && (
                    <button
                      onClick={() => window.location.href = `/admin?code=${customer.card.public_code}`}
                      className="btn btn-small btn-primary"
                    >
                      Gestisci
                    </button>
                  )}
                </div>
              ))}
            </div>
          </div>
        )}
      </div>

      {/* Clienti Recenti */}
      <div className="dashboard-section">
        <h3>👥 Clienti Recenti</h3>
        {recentCustomers.length === 0 ? (
          <p className="empty-state">Nessun cliente ancora</p>
        ) : (
          <div className="customers-list">
            {recentCustomers.map((customer) => (
              <div key={customer.id} className="customer-item">
                <div className="customer-info">
                  <div className="customer-name">{customer.full_name || customer.email}</div>
                  <div className="customer-email">{customer.email}</div>
                  <div className="customer-meta">
                    Registrato: {formatDate(customer.created_at)}
                  </div>
                  {customer.card && (
                    <div className="customer-card-info">
                      <span>Codice: <code>{customer.card.short_code || customer.card.public_code}</code></span>
                      <span>Punti: <strong>{customer.card.points}</strong></span>
                    </div>
                  )}
                </div>
                {customer.card && (
                  <button
                    onClick={() => window.location.href = `/admin?code=${customer.card.short_code || customer.card.public_code}`}
                    className="btn btn-small btn-primary"
                  >
                    Gestisci
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
