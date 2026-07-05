-- ==================== PHASE 8 - SÉCURITÉ ====================
-- Ajouter les champs de sécurité et admin à la table users

ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_blocked boolean DEFAULT false;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS blocked_at timestamp with time zone;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS block_reason text;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_admin boolean DEFAULT false;

-- Créer un index pour la recherche des utilisateurs bloqués
CREATE INDEX IF NOT EXISTS idx_users_is_blocked ON public.users(is_blocked);

-- ==================== PHASE 9 - ADMINISTRATION ====================
-- Table pour les signalements (reports)

CREATE TABLE IF NOT EXISTS public.reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    reporter_id uuid NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
    reported_user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
    reason text NOT NULL,
    description text,
    status text DEFAULT 'pending' CHECK (status IN ('pending', 'resolved', 'dismissed')),
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    admin_notes text,
    admin_id uuid REFERENCES public.users(id) ON DELETE SET NULL
);

-- Créer un index pour les signalements
CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_created_at ON public.reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_reports_reported_user_id ON public.reports(reported_user_id);

-- ==================== GESTION DES APPELS ====================
-- Ajouter les colonnes manquantes à la table calls

ALTER TABLE public.calls ADD COLUMN IF NOT EXISTS failure_reason text;
ALTER TABLE public.calls ADD COLUMN IF NOT EXISTS duration_seconds integer;

-- Créer un index pour les appels échoués
CREATE INDEX IF NOT EXISTS idx_calls_status ON public.calls(status);

-- ==================== GESTION DES MESSAGES ====================
-- Ajouter des colonnes pour mieux gérer les pièces jointes et l'expiration

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_type text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS attachment_url text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS expires_at timestamp with time zone;

-- Créer un index pour les messages à expirer
CREATE INDEX IF NOT EXISTS idx_messages_expires_at ON public.messages(expires_at);
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON public.messages(created_at DESC);

-- ==================== FONCTION POUR AUTO-SUPPRIMER LES MESSAGES ====================
-- Fonction pour nettoyer automatiquement les messages expirés (> 30 jours)

CREATE OR REPLACE FUNCTION public.cleanup_expired_messages()
RETURNS void AS $$
BEGIN
    -- Supprimer les pièces jointes du stockage (simulé, dépend du provider)
    DELETE FROM public.messages
    WHERE created_at < now() - INTERVAL '30 days'
    AND attachment_url IS NOT NULL;
    
    -- Vider le contenu des vieux messages (garder les métadonnées)
    UPDATE public.messages
    SET message = '[Message supprimé automatiquement]',
        attachment_url = NULL,
        updated_at = now()
    WHERE created_at < now() - INTERVAL '30 days'
    AND message != '[Message supprimé automatiquement]';
    
    RAISE NOTICE 'Cleanup de messages expirés effectué';
END;
$$ LANGUAGE plpgsql;

-- ==================== ROW LEVEL SECURITY (RLS) ====================
-- Activer RLS sur les tables critiques

ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Policy: Les utilisateurs peuvent voir leurs propres appels
CREATE POLICY IF NOT EXISTS "calls_own_calls"
ON public.calls FOR SELECT
USING (caller_id = auth.uid() OR receiver_id = auth.uid());

-- Policy: Les utilisateurs peuvent créer des signalements
CREATE POLICY IF NOT EXISTS "reports_own_reports"
ON public.reports FOR SELECT
USING (reporter_id = auth.uid() OR admin_id = auth.uid());

-- Policy: Admin peut voir tous les signalements
CREATE POLICY IF NOT EXISTS "reports_admin_access"
ON public.reports FOR SELECT
USING (EXISTS(SELECT 1 FROM public.users WHERE id = auth.uid() AND is_admin = true));

-- ==================== AUDIT LOG ====================
-- Table pour l'audit des actions admin

CREATE TABLE IF NOT EXISTS public.admin_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    admin_id uuid NOT NULL REFERENCES public.users(id) ON DELETE SET NULL,
    action text NOT NULL,
    resource_type text NOT NULL,
    resource_id text NOT NULL,
    details jsonb,
    created_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at ON public.admin_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id ON public.admin_logs(admin_id);

-- ==================== FONCTION POUR L'AUDIT ====================

CREATE OR REPLACE FUNCTION public.log_admin_action(
    p_admin_id uuid,
    p_action text,
    p_resource_type text,
    p_resource_id text,
    p_details jsonb DEFAULT NULL
)
RETURNS uuid AS $$
DECLARE
    v_log_id uuid;
BEGIN
    INSERT INTO public.admin_logs (admin_id, action, resource_type, resource_id, details)
    VALUES (p_admin_id, p_action, p_resource_type, p_resource_id, p_details)
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql;

-- ==================== EXTENSION CRYPTO (si nécessaire) ====================
-- Pour le chiffrement côté base de données (optionnel)

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Fonction pour hasher les données sensibles
CREATE OR REPLACE FUNCTION public.hash_sensitive_data(p_data text)
RETURNS text AS $$
BEGIN
    RETURN crypt(p_data, gen_salt('bf', 4));
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

-- ==================== PERMISSIONS SUPABASE ====================
-- Permettre à anon et authenticated de lire/créer des signalements

GRANT SELECT, INSERT ON public.reports TO anon;
GRANT SELECT, INSERT ON public.reports TO authenticated;
GRANT SELECT ON public.admin_logs TO authenticated;
GRANT EXECUTE ON FUNCTION public.log_admin_action TO authenticated;
GRANT EXECUTE ON FUNCTION public.cleanup_expired_messages TO authenticated;

-- ==================== NOTE ====================
-- Les migrations suivantes doivent être effectuées:
-- 1. Ajouter les colonnes manquantes aux tables existantes
-- 2. Créer les tables d'administration (reports, admin_logs)
-- 3. Activer les extensions nécessaires (pgcrypto)
-- 4. Configurer les RLS policies
-- 5. Mettre en place un CRON job pour nettoyer les messages expirés
