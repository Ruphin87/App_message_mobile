-- ============================================================
-- MOT DE PASSE OUBLIÉ : codes de vérification par SMTP (custom)
-- ============================================================
-- Cette table stocke les codes à 6 chiffres envoyés par email lors
-- d'une demande de "mot de passe oublié". Elle est utilisée UNIQUEMENT
-- par les Edge Functions (send-reset-code, verify-reset-code,
-- reset-password), qui s'exécutent avec la clé service_role et
-- contournent donc le RLS. Aucune policy n'est ajoutée : ni "anon" ni
-- "authenticated" ne peuvent lire ou écrire directement dans cette
-- table depuis l'app.

CREATE TABLE IF NOT EXISTS public.password_reset_codes (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  email text NOT NULL,
  code_hash text NOT NULL,              -- SHA-256 du code à 6 chiffres (jamais stocké en clair)
  attempts integer NOT NULL DEFAULT 0,  -- tentatives de code incorrect
  verified boolean NOT NULL DEFAULT false,
  reset_token_hash text,                -- SHA-256 du jeton temporaire (étape 3)
  reset_token_expires_at timestamp with time zone,
  expires_at timestamp with time zone NOT NULL,  -- expiration du code (10 min)
  used boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_password_reset_codes_email
  ON public.password_reset_codes(email);

CREATE INDEX IF NOT EXISTS idx_password_reset_codes_email_active
  ON public.password_reset_codes(email, used);

ALTER TABLE public.password_reset_codes ENABLE ROW LEVEL SECURITY;
-- Volontairement AUCUNE policy : la table est fermée à anon et
-- authenticated, seule la clé service_role (utilisée par les Edge
-- Functions) peut y accéder.

-- Nettoyage : petite fonction optionnelle pour purger les vieux codes
-- (peut être appelée par un cron Supabase si vous en configurez un).
CREATE OR REPLACE FUNCTION public.cleanup_expired_reset_codes()
RETURNS void AS $$
BEGIN
  DELETE FROM public.password_reset_codes
  WHERE expires_at < now() - INTERVAL '1 day';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
