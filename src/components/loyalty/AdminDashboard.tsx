import { useState } from 'react';
import { supabase } from '../../lib/supabaseClient';

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
  const [searchTerm, setSearchTerm] = useState('');
  const [searchResults, setSearchResults] = useState<Customer[]>([]);
  const [loading, setLoading] = useState(false);
  const [searching, setSearching] = useState(false);

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

  return (
    <div className="admin-dashboard">
      {/* Bottone Statistiche */}
      <div className="dashboard-section">
        <a href="/admin/stats" className="btn btn-primary btn-large">
          📊 Visualizza Statistiche
        </a>
      </div>

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
    </div>
  );
}
