-- ============================================
-- FIX: Permetti NULL in staff_id per redemptions
-- Per distinguere riscatti fatti dallo staff da quelli fatti dall'utente
-- ============================================

-- 1. Rimuovi il vincolo NOT NULL da staff_id
ALTER TABLE public.redemptions 
ALTER COLUMN staff_id DROP NOT NULL;

-- 2. Modifica il riferimento per permettere NULL
-- (Il riferimento esiste già, ma dobbiamo assicurarci che funzioni con NULL)
-- Se necessario, ricrea il constraint con ON DELETE SET NULL
ALTER TABLE public.redemptions
DROP CONSTRAINT IF EXISTS redemptions_staff_id_fkey;

ALTER TABLE public.redemptions
ADD CONSTRAINT redemptions_staff_id_fkey 
FOREIGN KEY (staff_id) 
REFERENCES public.profiles(id) 
ON DELETE SET NULL;

-- 3. Verifica la modifica
SELECT 
    column_name,
    is_nullable,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public' 
    AND table_name = 'redemptions'
    AND column_name = 'staff_id';
