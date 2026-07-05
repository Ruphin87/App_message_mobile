-- ============================================================
-- Active Supabase Realtime sur les tables `calls` et `call_events`.
--
-- Toute la gestion d'appel (détection d'un appel entrant, échange de
-- l'offre/réponse WebRTC, envoi des ICE candidates) repose sur
-- `.stream()` côté Flutter, qui a besoin que ces deux tables soient
-- ajoutées à la publication Realtime de Supabase. Contrairement aux
-- tables `messages`/`conversations`/`notifications` (créées plus tôt
-- et déjà activées, probablement via le dashboard), `calls` et
-- `call_events` ont été ajoutées dans une migration séparée et n'ont
-- visiblement jamais été activées pour le Realtime — ce qui explique
-- que les appels entrants et la connexion audio/vidéo ne
-- fonctionnent pas : l'app n'est simplement jamais notifiée qu'un
-- appel a été créé ou qu'un signal WebRTC est arrivé.
--
-- À FAIRE : copiez-collez ce fichier dans l'éditeur SQL de votre
-- dashboard Supabase, puis exécutez-le (Run). Vous pouvez aussi
-- vérifier ensuite dans Database > Replication que "calls" et
-- "call_events" apparaissent bien coché dans la publication
-- "supabase_realtime".
-- ============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'calls'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'call_events'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.call_events;
  END IF;
END $$;
