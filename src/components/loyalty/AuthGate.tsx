import { useState, useEffect } from 'react';
import { supabase, isSupabaseConfigured } from '../../lib/supabaseClient';
import type { User, Session } from '@supabase/supabase-js';

interface AuthGateProps {
  children: React.ReactNode;
  requireRole?: 'staff' | 'admin';
  redirectTo?: string;
}

export default function AuthGate({ children, requireRole, redirectTo = '/account' }: AuthGateProps) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);
  const [showLogin, setShowLogin] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isRegister, setIsRegister] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [userRole, setUserRole] = useState<string | null>(null);

  useEffect(() => {
    if (!isSupabaseConfigured()) {
      setError('Supabase non configurato. Controlla le variabili d\'ambiente.');
      setLoading(false);
      return;
    }

    // Controlla sessione esistente
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      if (session?.user) {
        checkUserRole(session.user.id);
      }
      setLoading(false);
    }).catch((err) => {
      setError('Errore di connessione a Supabase');
      setLoading(false);
    });

    // Ascolta cambiamenti auth
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setUser(session?.user ?? null);
      if (session?.user) {
        checkUserRole(session.user.id);
      } else {
        setUserRole(null);
      }
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkUserRole = async (userId: string) => {
    const { data, error } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', userId)
      .single();

    if (!error && data) {
      setUserRole(data.role);
      
      // Verifica ruolo richiesto
      if (requireRole) {
        if (requireRole === 'admin' && data.role !== 'admin') {
          setError('Accesso negato: richiesto ruolo admin');
          return;
        }
        if (requireRole === 'staff' && !['staff', 'admin'].includes(data.role)) {
          setError('Accesso negato: richiesto ruolo staff o admin');
          return;
        }
      }
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (isRegister) {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
      });

      if (error) {
        setError(error.message);
        return;
      }

      if (data.user) {
        setError('Registrazione completata! Controlla la tua email per confermare l\'account.');
      }
    } else {
      const { data, error } = await supabase.auth.signInWithPassword({
        email,
        password,
      });

      if (error) {
        setError(error.message);
        return;
      }

      if (data.user) {
        setShowLogin(false);
        setEmail('');
        setPassword('');
      }
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
    window.location.href = '/';
  };

  if (loading) {
    return (
      <div className="auth-loading">
        <div className="loading-spinner"></div>
        <p>Caricamento...</p>
      </div>
    );
  }

  if (!user) {
    return (
      <div className="auth-gate">
        <div className="auth-form-container">
          <h2>{isRegister ? 'Registrati' : 'Accedi'}</h2>
          <p className="auth-subtitle">
            {isRegister 
              ? 'Crea un account per accedere alla tua tessera fedeltà'
              : 'Accedi per visualizzare la tua tessera fedeltà'}
          </p>
          
          {error && <div className="auth-error">{error}</div>}
          
          <form onSubmit={handleLogin} className="auth-form">
            <div className="form-group">
              <label htmlFor="email">Email</label>
              <input
                id="email"
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                placeholder="tua@email.com"
              />
            </div>
            
            <div className="form-group">
              <label htmlFor="password">Password</label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
                placeholder="Minimo 6 caratteri"
                minLength={6}
              />
            </div>
            
            <button type="submit" className="btn btn-primary auth-submit">
              {isRegister ? 'Registrati' : 'Accedi'}
            </button>
          </form>
          
          <p className="auth-switch">
            {isRegister ? (
              <>
                Hai già un account?{' '}
                <button type="button" onClick={() => setIsRegister(false)} className="link-button">
                  Accedi
                </button>
              </>
            ) : (
              <>
                Non hai un account?{' '}
                <button type="button" onClick={() => setIsRegister(true)} className="link-button">
                  Registrati
                </button>
              </>
            )}
          </p>
        </div>
      </div>
    );
  }

  // Verifica ruolo se richiesto
  if (requireRole && userRole) {
    if (requireRole === 'admin' && userRole !== 'admin') {
      return (
        <div className="auth-gate">
          <div className="auth-error">
            <h2>Accesso Negato</h2>
            <p>Questa area è riservata agli amministratori.</p>
            <button onClick={handleLogout} className="btn btn-secondary">Esci</button>
          </div>
        </div>
      );
    }
    
    if (requireRole === 'staff' && !['staff', 'admin'].includes(userRole)) {
      return (
        <div className="auth-gate">
          <div className="auth-error">
            <h2>Accesso Negato</h2>
            <p>Questa area è riservata allo staff.</p>
            <button onClick={handleLogout} className="btn btn-secondary">Esci</button>
          </div>
        </div>
      );
    }
  }

  return <>{children}</>;
}
