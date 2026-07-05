-- ============================================================
-- CORRECTIF : récursion infinie sur les policies RLS de "users"
-- ============================================================
-- Erreur observée dans l'app :
-- PostgrestException 42P17 "infinite recursion detected in
-- policy for relation \"users\""
--
-- Cause : les policies "users_admin_select_all" et
-- "users_admin_update_all" (fichier 20260703180000) font un
-- SELECT sur public.users DEPUIS une policy posée sur
-- public.users elle-même. Ce sous-SELECT doit repasser par les
-- mêmes policies -> boucle infinie.
--
-- Solution : déplacer la vérification "is_admin" dans une
-- fonction SECURITY DEFINER, qui s'exécute avec les droits du
-- propriétaire de la fonction et CONTOURNE le RLS. Plus de
-- boucle, car le SELECT interne ne repasse plus par les
-- policies de "users".
-- ============================================================

-- 1) Supprimer les policies fautives (récursives)
DROP POLICY IF EXISTS "users_admin_select_all" ON public.users;
DROP POLICY IF EXISTS "users_admin_update_all" ON public.users;

-- 2) Fonction sûre pour vérifier si l'utilisateur courant est admin
--    SECURITY DEFINER = s'exécute avec les droits du créateur
--    (généralement "postgres"), donc bypass RLS pour cette requête.
--    STABLE = peut être mise en cache dans une même requête.
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT is_admin FROM public.users WHERE id = auth.uid()),
    false
  );
$$;

-- Autoriser les utilisateurs connectés à exécuter la fonction
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- 3) Recréer les policies admin sur "users" en utilisant la fonction
--    (plus de sous-SELECT direct sur users => plus de récursion)
CREATE POLICY "users_admin_select_all"
ON public.users FOR SELECT
USING (public.is_admin());

CREATE POLICY "users_admin_update_all"
ON public.users FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- 4) Bonus : les autres policies admin (reports, messages,
--    conversations) fonctionnaient déjà car elles ne créent pas
--    de boucle (policy sur une AUTRE table que users), mais on
--    les fait pointer vers la même fonction pour rester cohérent
--    et éviter tout souci si RLS est un jour activé différemment.

DROP POLICY IF EXISTS "reports_admin_access" ON public.reports;
CREATE POLICY "reports_admin_access"
ON public.reports FOR SELECT
USING (public.is_admin());

DROP POLICY IF EXISTS "reports_admin_update" ON public.reports;
CREATE POLICY "reports_admin_update"
ON public.reports FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "reports_admin_delete" ON public.reports;
CREATE POLICY "reports_admin_delete"
ON public.reports FOR DELETE
USING (public.is_admin());

DROP POLICY IF EXISTS "messages_admin_select" ON public.messages;
CREATE POLICY "messages_admin_select"
ON public.messages FOR SELECT
USING (public.is_admin());

DROP POLICY IF EXISTS "messages_admin_delete" ON public.messages;
CREATE POLICY "messages_admin_delete"
ON public.messages FOR DELETE
USING (public.is_admin());

DROP POLICY IF EXISTS "conversations_admin_access" ON public.conversations;
CREATE POLICY "conversations_admin_access"
ON public.conversations FOR SELECT
USING (public.is_admin());

-- ============================================================
-- À FAIRE ENSUITE
-- ============================================================
-- 1. Copiez-collez ce fichier dans l'éditeur SQL de votre
--    dashboard Supabase, puis exécutez-le (Run).
-- 2. Vérifiez qu'au moins un compte est admin :
--    UPDATE public.users SET is_admin = true WHERE email = 'votre@email.com';
-- 3. Relancez l'app (flutter run) : "Erreur dans getCurrentUser"
--    doit disparaître et l'app doit passer du login à l'écran
--    principal normalement.
-- ============================================================