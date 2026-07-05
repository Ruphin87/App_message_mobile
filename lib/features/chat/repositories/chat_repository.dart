import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/services/local_database_service.dart';
import '../../../models/attachment_model.dart';
import '../../../models/conversation_model.dart';
import '../../../models/message_model.dart';
import '../../../models/message_reaction_model.dart';
import '../../../models/user_model.dart';

class ChatRepository {
  ChatRepository();

  final _client = SupabaseService.client;
  final _localDb = LocalDatabaseService.instance;
  static const _attachmentsBucket = 'message-attachments';

  String? get _ownerId => SupabaseService.currentUserId;

  // ==================== CONVERSATIONS ====================

  /// Récupère ou crée la conversation entre l'utilisateur courant et [otherUserId].
  /// Toujours fait directement contre Supabase (pas de version "locale" pour
  /// la création, qui doit être garantie unique côté serveur).
  Future<ConversationModel> getOrCreateConversation(String otherUserId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) throw Exception('Utilisateur non connecté');

    // On normalise l'ordre (user1 < user2) pour respecter la contrainte unique.
    final ids = [currentUserId, otherUserId]..sort();
    final user1 = ids[0];
    final user2 = ids[1];

    final existing = await _client
        .from('conversations')
        .select()
        .eq('user1', user1)
        .eq('user2', user2)
        .maybeSingle();

    if (existing != null) {
      return ConversationModel.fromJson(existing);
    }

    final created = await _client
        .from('conversations')
        .insert({'user1': user1, 'user2': user2})
        .select()
        .single();

    return ConversationModel.fromJson(created);
  }

  /// Lecture INSTANTANÉE depuis le cache local (SQLite) : à appeler en
  /// premier pour afficher quelque chose immédiatement à l'ouverture de
  /// l'écran Messages, avant même que la requête réseau Supabase ne réponde.
  Future<List<ConversationModel>> getLocalConversations() async {
    final ownerId = _ownerId;
    if (ownerId == null) return [];

    final rows = await _localDb.getConversations(ownerId);
    if (rows.isEmpty) return [];

    // Jointure locale avec les profils déjà mis en cache dans local_users.
    final enriched = await Future.wait(rows.map((dbRow) async {
      final conv = ConversationModel.fromLocalDb(dbRow);
      final otherUserId = dbRow['other_user_id'] as String?;
      if (otherUserId == null) return conv;
      final userRow = await _localDb.getUser(ownerId, otherUserId);
      return conv.copyWith(otherUser: userRow != null ? UserModel.fromLocalDb(userRow) : null);
    }));

    // Une conversation que l'utilisateur courant a supprimée de sa liste ne
    // doit jamais réapparaître depuis le cache local.
    return enriched.where((c) => !c.isHiddenFor(ownerId)).toList();
  }

  /// Liste des conversations de l'utilisateur courant depuis SUPABASE
  /// (source de vérité), triées par dernier message, avec le profil de
  /// l'autre participant, le dernier message et le nb de non-lus.
  ///
  /// Met aussi à jour le cache local (`local_conversations` + `local_users`)
  /// avec ce qui est reçu, pour que le prochain appel à
  /// `getLocalConversations()` (au prochain démarrage de l'app, ou hors
  /// connexion) soit à jour.
  ///
  /// OPTIMISATION : toutes les conversations sont enrichies EN PARALLÈLE
  /// (Future.wait) au lieu d'un appel séquentiel par conversation.
  Future<List<ConversationModel>> getConversations() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return [];

    final response = await _client
        .from('conversations')
        .select()
        .or('user1.eq.$currentUserId,user2.eq.$currentUserId')
        .order('last_message_at', ascending: false);

    final conversations = (response as List)
        .map((json) => ConversationModel.fromJson(json as Map<String, dynamic>))
        // Une conversation supprimée par l'utilisateur courant ("Supprimer
        // la conversation") ne doit plus apparaître dans sa liste, même si
        // elle existe toujours côté serveur pour l'autre participant.
        .where((c) => !c.isHiddenFor(currentUserId))
        .toList();

    if (conversations.isEmpty) return [];

    final otherUserIds = conversations.map((c) => c.otherUserId(currentUserId)).toList();

    // 1 seul appel pour récupérer tous les profils des autres participants
    final usersResponse = await _client
        .from('users')
        .select()
        .inFilter('id', otherUserIds);

    final usersById = {
      for (final json in (usersResponse as List))
        json['id'] as String: UserModel.fromJson(json as Map<String, dynamic>),
    };

    // Le reste (dernier message + non-lus) est enrichi en parallèle par conversation.
    //
    // IMPORTANT — bug corrigé ici : la version précédente mettait
    // `lastMessageFuture` (qui se termine par `.maybeSingle()`, donc de
    // type `PostgrestTransformBuilder<Map<String, dynamic>?>`) et
    // `unreadFuture` (un filtre simple, de type
    // `PostgrestFilterBuilder<List<Map<String, dynamic>>>`) dans un même
    // `Future.wait<dynamic>([...])`. Ce mélange de deux types de builder
    // différents dans une liste typée `dynamic` provoquait un comportement
    // de cast incorrect : `unreadList` ne contenait jamais les bonnes
    // lignes, ce qui faisait que `unreadCount` valait toujours 0, peu
    // importe le nombre réel de messages non lus — d'où l'absence de gras
    // et de badge sur la liste des conversations.
    //
    // Cette version exécute chaque requête séparément avec un type de
    // retour explicite (List<dynamic> pour le count, Map?<String,dynamic>
    // pour le dernier message), ce qui élimine toute ambiguïté de cast.
    final enriched = await Future.wait(conversations.map((conv) async {
      final otherUserId = conv.otherUserId(currentUserId);

      final List<dynamic> unreadList = await _client
          .from('messages')
          .select('id')
          .eq('conversation_id', conv.id)
          .eq('is_read', false)
          .neq('sender_id', currentUserId);

      final Map<String, dynamic>? lastMessageJson = await _client
          .from('messages')
          .select('message')
          .eq('conversation_id', conv.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return conv.copyWith(
        otherUser: usersById[otherUserId],
        lastMessage: lastMessageJson?['message'] as String?,
        unreadCount: unreadList.length,
      );
    }));

    // Mise à jour du cache local : profils, puis conversations (qui
    // référencent ces profils via other_user_id).
    await _localDb.upsertUsers(
      currentUserId,
      usersById.values.map((u) => u.toLocalDb()).toList(),
    );
    await _localDb.upsertConversations(
      currentUserId,
      enriched.map((c) => c.toLocalDb(currentUserId)).toList(),
    );

    return enriched;
  }

  // ==================== MESSAGES ====================

  /// Lecture INSTANTANÉE depuis le cache local d'une conversation précise.
  /// Tri explicite par date croissante (ancien → récent) en plus du
  /// `ORDER BY created_at ASC` déjà fait côté SQLite, par cohérence avec
  /// `watchMessages()` qui doit faire la même garantie pour contourner un
  /// bug du SDK Supabase (voir commentaire sur `watchMessages`).
  ///
  /// Filtre aussi les messages que CET utilisateur a supprimés "pour moi"
  /// (`isHiddenFor`), et résout l'aperçu du message cité (`replyToPreview`)
  /// pour les réponses, depuis ce même cache local.
  Future<List<MessageModel>> getLocalMessages(String conversationId) async {
    final ownerId = _ownerId;
    if (ownerId == null) return [];

    final rows = await _localDb.getMessages(ownerId, conversationId);
    var messages = rows.map((r) => MessageModel.fromLocalDb(r)).toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    messages = messages.where((m) => !m.isHiddenFor(ownerId)).toList();
    return _attachReplyPreviewsLocal(ownerId, messages);
  }

  /// Reconstitue `replyToPreview` pour chaque message qui répond à un
  /// autre, en cherchant le message cité directement dans la liste déjà
  /// chargée (rapide, pas de requête supplémentaire dans le cas courant où
  /// le message cité fait partie du même historique affiché).
  Future<List<MessageModel>> _attachReplyPreviewsLocal(
    String ownerId,
    List<MessageModel> messages,
  ) async {
    final byId = {for (final m in messages) m.id: m};
    return messages.map((m) {
      if (m.replyToId == null) return m;
      final preview = byId[m.replyToId];
      return preview != null ? m.copyWith(replyToPreview: preview) : m;
    }).toList();
  }

  /// Historique des messages d'une conversation depuis SUPABASE, du plus
  /// ancien au plus récent. Met aussi à jour le cache local.
  /// Tri explicite par sécurité en plus du `.order(ascending: true)` côté
  /// requête, par cohérence avec `watchMessages()` et `getLocalMessages()`.
  ///
  /// Filtre les messages supprimés "pour moi" par l'utilisateur courant, et
  /// résout l'aperçu du message cité pour les réponses.
  Future<List<MessageModel>> getMessages(String conversationId) async {
    final response = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    final messages = (response as List)
        .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final ownerId = _ownerId;
    if (ownerId != null) {
      await _localDb.upsertMessages(ownerId, messages.map((m) => m.toLocalDb()).toList());
    }

    final visible =
        ownerId != null ? messages.where((m) => !m.isHiddenFor(ownerId)).toList() : messages;

    return ownerId != null ? await _attachReplyPreviewsLocal(ownerId, visible) : visible;
  }

  /// Envoie un nouveau message texte dans une conversation.
  ///
  /// Si le destinataire est actuellement en ligne (présent sur le canal de
  /// présence), le message est immédiatement marqué "delivered_at" — ce qui
  /// fera apparaître les 2 coches grises côté expéditeur dès l'envoi, comme
  /// sur WhatsApp quand le contact est connecté.
  ///
  /// [replyToId] : id du message auquel celui-ci répond, si l'utilisateur a
  /// choisi "Répondre" sur un message existant.
  ///
  /// Le message envoyé est aussi écrit immédiatement dans le cache local
  /// (en plus d'arriver via le stream Realtime juste après), pour qu'il
  /// reste visible si l'app est fermée juste après l'envoi.
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String message,
    required String recipientId,
    String? replyToId,
  }) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) throw Exception('Utilisateur non connecté');

    final recipientOnline = PresenceService.instance.isOnline(recipientId);

    final response = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': currentUserId,
          'message': message,
          'is_read': false,
          if (replyToId != null) 'reply_to_id': replyToId,
          if (recipientOnline) 'delivered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final sent = MessageModel.fromJson(response);
    await _localDb.upsertMessages(currentUserId, [sent.toLocalDb()]);
    await _reviveConversationIfHidden(conversationId);

    return sent;
  }

  /// Un nouveau message rend la conversation à nouveau active : si l'un des
  /// deux participants l'avait supprimée de sa liste ("Supprimer la
  /// conversation"), elle doit réapparaître pour lui — exactement comme sur
  /// WhatsApp, où recevoir un message dans une discussion supprimée la fait
  /// revenir dans la liste. On vide simplement `deleted_for` à chaque envoi.
  Future<void> _reviveConversationIfHidden(String conversationId) async {
    try {
      await _client
          .from('conversations')
          .update({'deleted_for': <String>[]})
          .eq('id', conversationId);
    } catch (_) {
      // Best-effort : un échec ici ne doit jamais empêcher l'envoi du
      // message, qui est déjà confirmé à ce stade.
    }
  }

  Future<MessageModel> sendFileAttachment({
    required String conversationId,
    required String recipientId,
    required String fileName,
    required Uint8List bytes,
    required AttachmentType fileType,
    String? contentType,
  }) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) throw Exception('Utilisateur non connecté');

    final safeFileName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final storagePath =
        '$conversationId/${DateTime.now().microsecondsSinceEpoch}_$safeFileName';

    await _client.storage.from(_attachmentsBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType ?? 'application/octet-stream'),
        );

    final fileUrl = _client.storage.from(_attachmentsBucket).getPublicUrl(storagePath);
    final recipientOnline = PresenceService.instance.isOnline(recipientId);

    final messageResponse = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': currentUserId,
          'message': _attachmentMessage(fileType),
          'is_read': false,
          if (recipientOnline) 'delivered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();

    final sent = MessageModel.fromJson(messageResponse);

    await _client.from('attachments').insert({
      'message_id': sent.id,
      'file_url': fileUrl,
      'file_type': fileType.name,
      'file_name': fileName,
      'file_size': bytes.length,
    });

    // Déclenche un UPDATE Realtime après l'insertion de l'attachement : le
    // message arrive souvent dans le stream avant sa ligne `attachments`.
    await _client
        .from('messages')
        .update({'message': sent.message})
        .eq('id', sent.id);

    await _localDb.upsertMessages(currentUserId, [sent.toLocalDb()]);
    await _reviveConversationIfHidden(conversationId);
    return sent;
  }

  String _attachmentMessage(AttachmentType type) {
    switch (type) {
      case AttachmentType.image:
        return '[Photo]';
      case AttachmentType.pdf:
        return '[PDF]';
      case AttachmentType.audio:
        return '[Audio]';
      case AttachmentType.document:
        return '[Fichier]';
    }
  }

  /// Marque comme "livrés" tous les messages reçus pas encore livrés d'une
  /// conversation. À appeler quand on ouvre l'app / l'écran de chat, pour
  /// les messages reçus pendant qu'on était hors ligne.
  Future<void> markMessagesAsDelivered(String conversationId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    final deliveredAt = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('messages')
        .update({'delivered_at': deliveredAt})
        .eq('conversation_id', conversationId)
        .filter('delivered_at', 'is', null)
        .neq('sender_id', currentUserId);

    await _localDb.markMessagesAsDelivered(currentUserId, conversationId, deliveredAt);
  }

  /// Marque comme lus tous les messages reçus (pas envoyés par soi) d'une conversation.
  /// Un message lu est forcément considéré comme livré (cohérence des 2 statuts).
  Future<void> markMessagesAsRead(String conversationId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    final readAt = DateTime.now().toUtc().toIso8601String();
    await _client
        .from('messages')
        .update({
          'is_read': true,
          'delivered_at': readAt,
        })
        .eq('conversation_id', conversationId)
        .eq('is_read', false)
        .neq('sender_id', currentUserId);

    await _localDb.markMessagesAsRead(currentUserId, conversationId, readAt);
  }

  Future<List<AttachmentModel>> getAttachments(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];

    final response = await _client
        .from('attachments')
        .select()
        .inFilter('message_id', messageIds);

    return (response as List)
        .map((json) => AttachmentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  String? _storagePathFromPublicUrl(String fileUrl) {
    final uri = Uri.tryParse(fileUrl);
    if (uri == null) return null;

    final bucketIndex = uri.pathSegments.indexOf(_attachmentsBucket);
    if (bucketIndex == -1 || bucketIndex == uri.pathSegments.length - 1) {
      return null;
    }

    return uri.pathSegments
        .skip(bucketIndex + 1)
        .map(Uri.decodeComponent)
        .join('/');
  }

  Future<void> _deleteAttachmentsForMessage(String messageId) async {
    final response = await _client
        .from('attachments')
        .select('file_url')
        .eq('message_id', messageId);

    final storagePaths = (response as List)
        .map((json) => _storagePathFromPublicUrl(json['file_url'] as String? ?? ''))
        .whereType<String>()
        .toList();

    if (storagePaths.isNotEmpty) {
      await _client.storage.from(_attachmentsBucket).remove(storagePaths);
    }

    await _client
        .from('attachments')
        .delete()
        .eq('message_id', messageId);
  }

  /// Stream temps réel : écoute les nouveaux messages d'une conversation.
  /// Utilise le Realtime de Supabase (postgres_changes) pour recevoir les
  /// messages sans avoir à rafraîchir l'écran. Chaque lot reçu est aussi
  /// écrit dans le cache local, pour que la conversation reste disponible
  /// hors connexion la prochaine fois qu'on l'ouvre.
  ///
  /// IMPORTANT — bug corrigé ici :
  /// `.order('created_at')` SANS préciser `ascending` utilise `false` par
  /// défaut dans le SDK Supabase (`order(column, {ascending = false})`),
  /// donc le flux renvoyait les messages du PLUS RÉCENT au PLUS ANCIEN.
  /// C'est ce qui faisait "remonter" le dernier message en haut de la
  /// conversation dès que le stream Realtime émettait son premier lot
  /// (l'ordre semblait correct au départ car `getMessages()` charge
  /// l'historique initial avec `ascending: true`, mais le stream prenait
  /// ensuite le relais avec l'ordre inverse).
  ///
  /// En plus de corriger `ascending: true` explicitement, on retrie aussi
  /// la liste côté Dart par sécurité : le SDK Supabase a un bug connu où le
  /// tri d'un stream peut devenir instable après un UPDATE sur une ligne
  /// déjà reçue (ex: `markMessagesAsRead`/`markMessagesAsDelivered`, qui
  /// font justement un UPDATE à chaque ouverture de conversation). Ce tri
  /// explicite garantit l'ordre quel que soit le comportement du SDK.
  Stream<List<MessageModel>> watchMessages(String conversationId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((row) => MessageModel.fromJson(row)).toList())
        .asyncMap((messages) async {
      // Tri explicite par date croissante (ancien → récent), indépendant du
      // tri renvoyé par le SDK — garantit que le dernier message est
      // toujours en dernière position de la liste, donc en bas de l'écran.
      final sorted = [...messages]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final ownerId = _ownerId;
      if (ownerId == null) return sorted;

      if (sorted.isNotEmpty) {
        _localDb.upsertMessages(ownerId, sorted.map((m) => m.toLocalDb()).toList());
      }

      final visible = sorted.where((m) => !m.isHiddenFor(ownerId)).toList();
      return _attachReplyPreviewsLocal(ownerId, visible);
    });
  }

  // ==================== SUPPRESSION DE MESSAGE ====================

  /// "Supprimer pour moi" : ajoute l'utilisateur courant au tableau
  /// `deleted_for` du message. Le message reste visible pour l'autre
  /// participant ; ce client le filtre dès la prochaine lecture (et le
  /// retire immédiatement du cache local pour un effet instantané).
  ///
  /// Peut être appelé par N'IMPORTE QUEL participant de la conversation,
  /// sur N'IMPORTE QUEL message (y compris ceux reçus) — exactement comme
  /// WhatsApp : "supprimer pour moi" n'efface que sa propre vue.
  Future<void> deleteMessageForMe(String messageId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    // On lit la valeur actuelle de deleted_for pour y ajouter notre id,
    // plutôt que d'utiliser un opérateur SQL d'ajout de tableau, pour
    // rester compatible avec une lecture simple côté client.
    final current = await _client
        .from('messages')
        .select('deleted_for')
        .eq('id', messageId)
        .single();

    final deletedFor = ((current['deleted_for'] as List?) ?? [])
        .map((e) => e as String)
        .toSet();
    deletedFor.add(currentUserId);

    await _client
        .from('messages')
        .update({'deleted_for': deletedFor.toList()})
        .eq('id', messageId);

    await _localDb.deleteMessage(currentUserId, messageId);
  }

  /// "Supprimer pour tout le monde" : vide le texte et marque le message
  /// comme supprimé pour tous les participants. Réservé à l'expéditeur du
  /// message — cette restriction est appliquée ici via `.eq('sender_id',
  /// currentUserId)`, qui fait échouer silencieusement l'update (0 ligne
  /// affectée) si quelqu'un d'autre tentait de l'appeler sur un message
  /// qui n'est pas le sien.
  Future<void> deleteMessageForEveryone(String messageId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    final message = await _client
        .from('messages')
        .select('sender_id')
        .eq('id', messageId)
        .maybeSingle();

    if (message == null || message['sender_id'] != currentUserId) return;

    // Les photos, audios et vocaux sont des messages avec une ligne
    // `attachments`. On nettoie ces fichiers avant de transformer la bulle
    // en placeholder supprimé. Si le nettoyage échoue (ancienne policy RLS
    // pas encore appliquée, fichier déjà absent), la suppression du message
    // reste prioritaire et l'UI masquera quand même les pièces jointes.
    try {
      await _deleteAttachmentsForMessage(messageId);
    } catch (_) {}

    await _client
        .from('messages')
        .update({
          'message': '',
          'is_deleted_for_everyone': true,
        })
        .eq('id', messageId)
        .eq('sender_id', currentUserId);
  }

  // ==================== SUPPRESSION DE CONVERSATION ====================

  /// Supprime la conversation entière avec [otherUser] de la liste de
  /// l'utilisateur courant ("Supprimer la conversation") — distinct de la
  /// suppression d'un simple message : ici c'est toute la discussion entre
  /// moi et cette personne qui disparaît de mon écran Messages.
  ///
  /// Même principe que `deleteMessageForMe` : on ajoute l'id de l'utilisateur
  /// courant au tableau `deleted_for` de la ligne `conversations`, sans rien
  /// supprimer côté serveur — l'autre participant garde donc sa conversation
  /// et son historique de messages intacts. Si une nouvelle conversation
  /// est recréée plus tard avec la même personne, l'ancienne ligne est
  /// réutilisée par `getOrCreateConversation` mais n'est plus filtrée
  /// puisqu'un nouveau message la fera réapparaître comme une conversation
  /// normale au prochain chargement.
  Future<void> deleteConversation(String conversationId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    final current = await _client
        .from('conversations')
        .select('deleted_for')
        .eq('id', conversationId)
        .single();

    final deletedFor = ((current['deleted_for'] as List?) ?? [])
        .map((e) => e as String)
        .toSet();
    deletedFor.add(currentUserId);

    await _client
        .from('conversations')
        .update({'deleted_for': deletedFor.toList()})
        .eq('id', conversationId);

    await _localDb.deleteConversation(currentUserId, conversationId);
  }

  // ==================== RÉACTIONS EMOJI ====================

  /// Ajoute ou remplace la réaction de l'utilisateur courant sur un message
  /// (un seul emoji actif par utilisateur et par message — retaper un autre
  /// emoji remplace le précédent, comme sur WhatsApp/Messenger).
  Future<void> setReaction({required String messageId, required String emoji}) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    await _client.from('message_reactions').upsert(
      {
        'message_id': messageId,
        'user_id': currentUserId,
        'emoji': emoji,
      },
      onConflict: 'message_id,user_id',
    );
  }

  /// Retire la réaction de l'utilisateur courant sur un message (ex: il
  /// retape le même emoji déjà actif, pour l'annuler).
  Future<void> removeReaction(String messageId) async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    await _client
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', currentUserId);

    await _localDb.deleteReaction(currentUserId, messageId, currentUserId);
  }

  /// Récupère toutes les réactions des messages d'une conversation (pour
  /// affichage groupé sous chaque bulle). Met aussi à jour le cache local.
  Future<List<MessageReactionModel>> getReactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return [];

    final response = await _client
        .from('message_reactions')
        .select()
        .inFilter('message_id', messageIds);

    final reactions = (response as List)
        .map((json) => MessageReactionModel.fromJson(json as Map<String, dynamic>))
        .toList();

    final ownerId = _ownerId;
    if (ownerId != null) {
      await _localDb.upsertReactions(ownerId, reactions.map((r) => r.toLocalDb()).toList());
    }

    return reactions;
  }

  /// Lecture instantanée des réactions depuis le cache local.
  Future<List<MessageReactionModel>> getLocalReactions(List<String> messageIds) async {
    final ownerId = _ownerId;
    if (ownerId == null) return [];

    final rows = await _localDb.getReactionsForMessages(ownerId, messageIds);
    return rows.map((r) => MessageReactionModel.fromLocalDb(r)).toList();
  }

  /// Stream temps réel GLOBAL des réactions — même principe que
  /// `watchAnyMessageChange()` : sert uniquement de signal pour relancer
  /// `getReactions()`, sans filtrage serveur par utilisateur.
  Stream<void> watchAnyReactionChange() {
    return _client
        .from('message_reactions')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }

  /// Stream temps réel GLOBAL : émet un événement chaque fois qu'un message
  /// est inséré ou mis à jour (lu/livré) sur N'IMPORTE QUELLE conversation,
  /// peu importe laquelle.
  ///
  /// Sert uniquement de "signal" pour déclencher un rechargement de la liste
  /// des conversations (ChatListNotifier) — il ne filtre pas par utilisateur
  /// côté serveur (le `.stream()` de Supabase ne permet pas de filtre OR sur
  /// deux colonnes), donc TOUS les messages de TOUS les utilisateurs
  /// transitent par ce canal. C'est acceptable ici car on ne lit aucune
  /// donnée sensible depuis ce flux : on l'utilise juste comme déclencheur
  /// pour relancer `getConversations()`, qui lui reste protégé par les RLS.
  Stream<void> watchAnyMessageChange() {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }
}
