import { useState, useEffect } from 'react';
import { supabase, isSupabaseConfigured } from '../../lib/supabaseClient';

export default function ProfileNavLink() {
  const [userRole, setUserRole] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  useEffect(() => {
    checkUserRole();
    
    // Ascolta cambiamenti auth
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange(() => {
      checkUserRole();
    });

    return () => subscription.unsubscribe();
  }, []);

  const checkUserRole = async () => {
    if (!isSupabaseConfigured()) {
      setLoading(false);
      return;
    }

    try {
      const { data: { session }, error: sessionError } = await supabase.auth.getSession();
      
      if (sessionError) {
        console.error('Errore sessione:', sessionError);
        setIsAuthenticated(false);
        setUserRole(null);
        setLoading(false);
        return;
      }
      
      if (!session?.user) {
        setIsAuthenticated(false);
        setUserRole(null);
        setLoading(false);
        return;
      }

      setIsAuthenticated(true);

      // Prova a leggere il ruolo con retry
      let retries = 3;
      let data = null;
      let error = null;

      while (retries > 0) {
        const result = await supabase
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle(); // Usa maybeSingle invece di single per evitare errori se non esiste

        data = result.data;
        error = result.error;

        if (!error && data && data.role) {
          break;
        }

        // Se errore e ci sono ancora retry, aspetta un po' e riprova
        if (error && retries > 1) {
          console.log(`Tentativo ${4 - retries} fallito, riprovo...`, error);
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
        retries--;
      }

      if (!error && data && data.role) {
        setUserRole(data.role);
        console.log('✅ Ruolo letto correttamente:', data.role);
      } else {
        console.error('❌ Errore lettura ruolo:', error);
        console.log('Dati ricevuti:', data);
        // Se il profile non esiste ancora, aspetta che venga creato dal trigger
        // Oppure imposta come customer di default
        if (error?.code === 'PGRST116') {
          // Profile non trovato - potrebbe essere appena creato
          console.log('Profile non trovato, potrebbe essere in creazione...');
          setUserRole('customer'); // Default temporaneo
        } else {
          setUserRole(null);
        }
      }
    } catch (err) {
      console.error('Errore checkUserRole:', err);
      setUserRole(null);
    } finally {
      setLoading(false);
    }
  };

  // Determina l'URL in base al ruolo
  const getProfileUrl = () => {
    if (userRole === 'staff' || userRole === 'admin') {
      return '/admin';
    }
    return '/account';
  };

  // Determina la classe CSS in base al ruolo
  const getLinkClassName = () => {
    if (userRole === 'staff' || userRole === 'admin') {
      return 'nav-link admin-link';
    }
    return 'nav-link';
  };

  // Mostra sempre "Profilo", ma con href dinamico
  // Se non autenticato, mostra comunque il link (andrà a /account che mostrerà login)
  // Durante il loading, mostra comunque il link (evita flash)
  const displayText = 'Profilo';
  const href = isAuthenticated && userRole ? getProfileUrl() : '/account';
  const className = isAuthenticated && userRole ? getLinkClassName() : 'nav-link';

  return (
    <li>
      <a 
        href={href} 
        className={className}
      >
        {displayText}
      </a>
    </li>
  );
}
