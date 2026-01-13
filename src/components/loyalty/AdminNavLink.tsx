import { useState, useEffect } from 'react';
import { supabase, isSupabaseConfigured } from '../../lib/supabaseClient';

export default function AdminNavLink() {
  const [showLink, setShowLink] = useState(false);
  const [loading, setLoading] = useState(true);

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
      const { data: { session } } = await supabase.auth.getSession();
      
      if (!session?.user) {
        setShowLink(false);
        setLoading(false);
        return;
      }

      const { data, error } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', session.user.id)
        .single();

      if (!error && data) {
        // Mostra link solo per staff e admin
        setShowLink(['staff', 'admin'].includes(data.role));
      } else {
        setShowLink(false);
      }
    } catch (err) {
      setShowLink(false);
    } finally {
      setLoading(false);
    }
  };

  if (loading || !showLink) {
    return null;
  }

  return (
    <li>
      <a href="/admin" className="nav-link admin-link">
        🔧 Admin
      </a>
    </li>
  );
}
