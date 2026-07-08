import '../../models/message_model.dart';

/// Résultat du traitement effectué en arrière-plan (dans un isolate séparé)
/// pour une liste de messages :
/// - [forLocalDb] : toutes les lignes prêtes à être écrites dans le cache
///   SQLite (non filtrées : on garde une copie complète en local même des
///   messages supprimés "pour moi", pour rester cohérent avec le comportement
///   existant du repository).
/// - [forDisplay] : la liste filtrée et enrichie (aperçu des réponses),
///   prête à être affichée telle quelle par l'écran de chat.
class ProcessedMessages {
  ProcessedMessages({required this.forLocalDb, required this.forDisplay});

  final List<Map<String, dynamic>> forLocalDb;
  final List<MessageModel> forDisplay;
}

/// Paramètres envoyés à l'isolate. Doit rester composé uniquement de types
/// "sendables" (String, bool, List/Map de types simples) pour pouvoir
/// traverser la frontière entre isolates.
class MessageParseInput {
  MessageParseInput({
    required this.rows,
    required this.fromLocalDb,
    required this.ownerId,
  });

  final List<Map<String, dynamic>> rows;

  /// true si [rows] vient déjà de la base SQLite locale (flags 0/1,
  /// `deleted_for` en CSV) ; false si ça vient de la réponse JSON Supabase.
  final bool fromLocalDb;

  final String? ownerId;
}

/// Fonction "top-level" (obligatoire pour être exécutée dans un isolate
/// séparé via `compute()`) qui regroupe TOUT le travail CPU coûteux sur une
/// liste de messages :
///   1. parsing (JSON Supabase ou lignes SQLite) -> `MessageModel`
///   2. tri chronologique
///   3. conversion vers le format d'écriture du cache local
///   4. filtrage des messages supprimés "pour moi"
///   5. reconstruction de l'aperçu des réponses (`replyToPreview`)
///
/// Comme cette fonction tourne dans un isolate séparé (voir les appels à
/// `compute(processMessages, ...)` dans `ChatRepository`), elle ne bloque
/// JAMAIS le thread UI — même sur une conversation de plusieurs milliers de
/// messages, ou quand le flux temps réel réémet toute l'historique à chaque
/// nouveau message.
ProcessedMessages processMessages(MessageParseInput input) {
  var messages = input.fromLocalDb
      ? input.rows.map(MessageModel.fromLocalDb).toList()
      : input.rows.map(MessageModel.fromJson).toList();

  messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

  final forLocalDb = messages.map((m) => m.toLocalDb()).toList();

  final ownerId = input.ownerId;
  var visible = ownerId != null
      ? messages.where((m) => !m.isHiddenFor(ownerId)).toList()
      : messages;

  // Reconstruction de l'aperçu des réponses (jointure locale en mémoire).
  final byId = {for (final m in visible) m.id: m};
  visible = visible.map((m) {
    if (m.replyToId == null) return m;
    final preview = byId[m.replyToId];
    return preview != null ? m.copyWith(replyToPreview: preview) : m;
  }).toList();

  return ProcessedMessages(forLocalDb: forLocalDb, forDisplay: visible);
}
