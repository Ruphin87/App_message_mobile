-- ============================================================
-- Corrige la table `calls` : le code de l'application gère un statut
-- 'failed' (appel échoué, ex: réseau) avec une colonne `failure_reason`,
-- mais la table créée initialement ne les avait pas — ce qui provoquait
-- une erreur de contrainte à chaque fois que ce statut était utilisé.
--
-- À FAIRE : copiez-collez ce fichier dans l'éditeur SQL de votre
-- dashboard Supabase, puis exécutez-le (Run).
-- ============================================================

ALTER TABLE public.calls
  ADD COLUMN IF NOT EXISTS failure_reason text;

ALTER TABLE public.calls
  DROP CONSTRAINT IF EXISTS calls_status_check;

ALTER TABLE public.calls
  ADD CONSTRAINT calls_status_check
  CHECK (status IN ('ringing', 'accepted', 'declined', 'ended', 'missed', 'failed'));
