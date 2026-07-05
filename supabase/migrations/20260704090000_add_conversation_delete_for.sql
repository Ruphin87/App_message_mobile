-- ============================================================
-- Suppression de conversation (distincte de la suppression d'un
-- simple message) : ajoute une colonne `deleted_for` à
-- `conversations`, sur le même principe que `deleted_for` sur
-- `messages`.
--
-- Quand un utilisateur choisit "Supprimer la conversation" dans
-- l'app, son id est ajouté à ce tableau : la conversation (et tous
-- ses messages) reste intacte en base et pour l'autre participant,
-- mais disparaît de la liste de celui qui l'a supprimée. Si l'un des
-- deux renvoie un nouveau message plus tard, `deleted_for` est vidé
-- par l'application et la conversation réapparaît normalement.
--
-- À FAIRE : copiez-collez ce fichier dans l'éditeur SQL de votre
-- dashboard Supabase, puis exécutez-le (Run) — comme pour les autres
-- migrations de ce projet.
-- ============================================================

ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS deleted_for text[] NOT NULL DEFAULT '{}';

-- Autorise chaque participant (user1 ou user2) à modifier sa propre
-- ligne de conversation, ce qui est nécessaire pour mettre à jour
-- `deleted_for` depuis l'app. Cette policy ne permet de modifier QUE
-- les conversations dont on fait partie (elle ne donne aucun accès
-- aux conversations d'autres utilisateurs).
DROP POLICY IF EXISTS "conversations_participant_update" ON public.conversations;
CREATE POLICY "conversations_participant_update"
ON public.conversations FOR UPDATE
USING (auth.uid() = user1 OR auth.uid() = user2)
WITH CHECK (auth.uid() = user1 OR auth.uid() = user2);
