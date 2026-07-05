import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/attachment_model.dart';
import '../../../models/conversation_model.dart';
import '../../../models/message_model.dart';
import '../../../models/message_reaction_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../repositories/chat_repository.dart';

// ==================== LISTE DES CONVERSATIONS ====================

class ChatListState {
  const ChatListState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ConversationModel> conversations;
  final bool isLoading;
  final String? error;

  ChatListState copyWith({
    List<ConversationModel>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ChatListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ChatListNotifier extends StateNotifier<ChatListState> {
  ChatListNotifier(this._repository) : super(const ChatListState()) {
    _loadInitial();
    _listenForChanges();
  }

  final ChatRepository _repository;
  StreamSubscription<void>? _changesSubscription;
  Timer? _debounceTimer;

  /// Démarrage "offline-first" : on affiche D'ABORD le cache local
  /// (instantané, même hors connexion), puis on lance la synchronisation
  /// réseau en arrière-plan qui mettra à jour l'écran dès qu'elle répond.
  Future<void> _loadInitial() async {
    try {
      final localConversations = await _repository.getLocalConversations();
      if (!mounted) return;
      if (localConversations.isNotEmpty) {
        state = state.copyWith(conversations: localConversations, isLoading: false);
      } else {
        state = state.copyWith(isLoading: true);
      }
    } catch (_) {
      // Le cache local est best-effort : une erreur ici ne doit jamais
      // bloquer le chargement réseau qui suit.
    }

    if (!mounted) return;
    await loadConversations();
  }

  /// Synchronisation réseau (source de vérité) : interroge Supabase et
  /// met à jour l'état + le cache local (fait par le repository).
  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversations = await _repository.getConversations();
      if (!mounted) return;
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      // En cas d'erreur réseau, on garde ce qui est déjà affiché (le cache
      // local le cas échéant) plutôt que de vider l'écran.
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors du chargement des conversations',
      );
    }
  }

  /// Écoute en temps réel tout changement sur la table `messages` (nouveau
  /// message, marquage lu/livré) et relance automatiquement le chargement
  /// de la liste — c'est ce qui fait apparaître/actualiser une conversation
  /// dès qu'un message est reçu, sans avoir à rouvrir l'écran manuellement.
  ///
  /// Un debounce de 300 ms évite de relancer une requête réseau pour chaque
  /// ligne si plusieurs messages arrivent d'un coup (ex: rattrapage après
  /// reconnexion).
  void _listenForChanges() {
    _changesSubscription = _repository.watchAnyMessageChange().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        loadConversations();
      });
    });
  }

  /// Supprime toute la conversation avec cette personne de MA liste
  /// (optimiste : elle disparaît immédiatement de l'écran), sans toucher à
  /// ses messages ni à la conversation de l'autre participant.
  Future<void> deleteConversation(String conversationId) async {
    final previous = state.conversations;
    state = state.copyWith(
      conversations: previous.where((c) => c.id != conversationId).toList(),
    );
    try {
      await _repository.deleteConversation(conversationId);
    } catch (e) {
      if (!mounted) return;
      // Échec réseau : on restaure la conversation dans la liste plutôt que
      // de laisser croire à l'utilisateur qu'elle a bien été supprimée.
      state = state.copyWith(
        conversations: previous,
        error: 'Erreur lors de la suppression de la conversation',
      );
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _changesSubscription?.cancel();
    super.dispose();
  }
}

// ==================== ÉCRAN DE CHAT (1 conversation) ====================

class ChatState {
  const ChatState({
    this.conversationId,
    this.recipientId,
    this.messages = const [],
    this.attachmentsByMessageId = const {},
    this.reactionsByMessageId = const {},
    this.replyingTo,
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  final String? conversationId;
  final String? recipientId;
  final List<MessageModel> messages;
  final Map<String, List<AttachmentModel>> attachmentsByMessageId;

  /// Réactions groupées par id de message, pour un accès rapide depuis l'UI.
  final Map<String, List<MessageReactionModel>> reactionsByMessageId;

  /// Message auquel l'utilisateur est en train de répondre (affiché dans la
  /// barre au-dessus du champ de saisie), ou null si aucune réponse en cours.
  final MessageModel? replyingTo;

  final bool isLoading;
  final bool isSending;
  final String? error;

  ChatState copyWith({
    String? conversationId,
    String? recipientId,
    List<MessageModel>? messages,
    Map<String, List<AttachmentModel>>? attachmentsByMessageId,
    Map<String, List<MessageReactionModel>>? reactionsByMessageId,
    MessageModel? replyingTo,
    bool clearReplyingTo = false,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      recipientId: recipientId ?? this.recipientId,
      messages: messages ?? this.messages,
      attachmentsByMessageId: attachmentsByMessageId ?? this.attachmentsByMessageId,
      reactionsByMessageId: reactionsByMessageId ?? this.reactionsByMessageId,
      replyingTo: clearReplyingTo ? null : (replyingTo ?? this.replyingTo),
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier(this._repository) : super(const ChatState());

  final ChatRepository _repository;
  StreamSubscription<List<MessageModel>>? _messageStreamSubscription;
  StreamSubscription<void>? _reactionsSubscription;
  Timer? _reactionsDebounce;

  /// Initialise (ou récupère) la conversation avec [otherUserId] et démarre
  /// l'écoute temps réel des messages.
  ///
  /// Offline-first : dès que l'id de conversation est connu, on affiche
  /// immédiatement les messages déjà en cache local, puis on lance la
  /// requête réseau qui rafraîchira l'écran avec les données à jour.
  Future<void> openConversationWith(String otherUserId) async {
    state = state.copyWith(isLoading: true, error: null, recipientId: otherUserId);

    try {
      final conversation = await _repository.getOrCreateConversation(otherUserId);
      if (!mounted) return;
      state = state.copyWith(conversationId: conversation.id);

      final localHistory = await _repository.getLocalMessages(conversation.id);
      if (!mounted) return;
      if (localHistory.isNotEmpty) {
        state = state.copyWith(messages: localHistory, isLoading: false);
        await _loadReactions(localHistory, useLocal: true);
        if (!mounted) return;
      }

      // Marque comme livrés les messages reçus pendant qu'on était absent,
      // puis comme lus puisqu'on ouvre l'écran maintenant.
      await _repository.markMessagesAsDelivered(conversation.id);
      await _repository.markMessagesAsRead(conversation.id);
      if (!mounted) return;

      final history = await _repository.getMessages(conversation.id);
      if (!mounted) return;
      state = state.copyWith(messages: history, isLoading: false);
      await _loadAttachments(history);
      await _loadReactions(history);
      if (!mounted) return;

      // IMPORTANT — bug corrigé ici : l'abonnement à ce stream n'était
      // jamais conservé ni annulé dans dispose(). `chatProvider` est
      // `autoDispose` : dès qu'on quitte l'écran de chat, ce notifier est
      // détruit, mais le listener du stream restait actif et tentait
      // d'écrire dans `state` après coup → l'assertion interne de
      // StateNotifier ('_lifecycleState != defunct') levait une exception
      // FATALE qui plantait toute l'app et coupait la connexion Realtime
      // — ce qui expliquait que le badge "non lu" ne se mettait à jour
      // que pour le premier message d'une conversation, puis plus jamais
      // après (le crash cassait le stream de ChatListNotifier aussi).
      _messageStreamSubscription?.cancel();
      _messageStreamSubscription = _repository.watchMessages(conversation.id).listen((messages) {
        if (!mounted) return;
        state = state.copyWith(messages: messages);
        _repository.markMessagesAsDelivered(conversation.id);
        _repository.markMessagesAsRead(conversation.id);
        _loadAttachments(messages);
        _loadReactions(messages);
      });

      _listenForReactionChanges();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors de l\'ouverture de la conversation',
      );
    }
  }

  Future<void> _loadReactions(List<MessageModel> messages, {bool useLocal = false}) async {
    if (messages.isEmpty) return;
    final ids = messages.map((m) => m.id).toList();

    final reactions = useLocal
        ? await _repository.getLocalReactions(ids)
        : await _repository.getReactions(ids);

    // Le notifier (et donc son `state`) peut avoir été détruit pendant que
    // cette requête réseau était en cours (écran de chat fermé entre temps)
    // — sans cette vérification, l'écriture ci-dessous plante l'app.
    if (!mounted) return;

    final grouped = <String, List<MessageReactionModel>>{};
    for (final r in reactions) {
      grouped.putIfAbsent(r.messageId, () => []).add(r);
    }
    state = state.copyWith(reactionsByMessageId: grouped);
  }

  Future<void> _loadAttachments(List<MessageModel> messages) async {
    if (messages.isEmpty) return;
    final ids = messages.map((m) => m.id).toList();

    try {
      final attachments = await _repository.getAttachments(ids);
      if (!mounted) return;

      final grouped = <String, List<AttachmentModel>>{};
      for (final attachment in attachments) {
        grouped.putIfAbsent(attachment.messageId, () => []).add(attachment);
      }
      state = state.copyWith(attachmentsByMessageId: grouped);
    } catch (_) {
      // L'historique texte doit rester lisible même si les métadonnées de
      // fichiers ne sont pas encore disponibles (réseau, migration absente).
    }
  }

  /// Écoute en temps réel les changements de réactions (debounce 300ms), et
  /// relance le chargement groupé pour les messages actuellement affichés.
  void _listenForReactionChanges() {
    _reactionsSubscription = _repository.watchAnyReactionChange().listen((_) {
      _reactionsDebounce?.cancel();
      _reactionsDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) _loadReactions(state.messages);
      });
    });
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.conversationId == null || state.recipientId == null) {
      return;
    }

    state = state.copyWith(isSending: true, error: null);

    try {
      await _repository.sendMessage(
        conversationId: state.conversationId!,
        message: text.trim(),
        recipientId: state.recipientId!,
        replyToId: state.replyingTo?.id,
      );
      if (!mounted) return;
      state = state.copyWith(isSending: false, clearReplyingTo: true);
      // Pas besoin de mettre à jour `messages` manuellement :
      // le stream temps réel (`watchMessages`) reçoit automatiquement
      // le nouveau message inséré.
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isSending: false, error: 'Erreur lors de l\'envoi');
    }
  }

  Future<void> sendAttachment({
    required String fileName,
    required Uint8List bytes,
    required AttachmentType fileType,
    String? contentType,
  }) async {
    if (state.conversationId == null || state.recipientId == null || bytes.isEmpty) {
      return;
    }

    state = state.copyWith(isSending: true, error: null);

    try {
      await _repository.sendFileAttachment(
        conversationId: state.conversationId!,
        recipientId: state.recipientId!,
        fileName: fileName,
        bytes: bytes,
        fileType: fileType,
        contentType: contentType,
      );
      if (!mounted) return;
      state = state.copyWith(isSending: false);
      await _loadAttachments(state.messages);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isSending: false, error: 'Erreur lors de l\'envoi du fichier');
    }
  }

  /// Prépare une réponse à [message] : affiche son aperçu dans la barre au
  /// dessus du champ de saisie, jusqu'à l'envoi ou l'annulation.
  void startReplyingTo(MessageModel message) {
    state = state.copyWith(replyingTo: message);
  }

  void cancelReply() {
    state = state.copyWith(clearReplyingTo: true);
  }

  /// "Supprimer pour moi" — retire le message immédiatement de l'écran
  /// (mise à jour optimiste), sans attendre la confirmation serveur.
  Future<void> deleteMessageForMe(String messageId) async {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
    try {
      await _repository.deleteMessageForMe(messageId);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: 'Erreur lors de la suppression');
    }
  }

  /// "Supprimer pour tout le monde" — réservé à l'expéditeur (vérifié côté
  /// UI avant d'appeler cette méthode, et de toute façon ignoré côté
  /// serveur si l'utilisateur n'est pas l'expéditeur).
  Future<void> deleteMessageForEveryone(String messageId) async {
    try {
      await _repository.deleteMessageForEveryone(messageId);
      // Pas de mise à jour manuelle de l'état : le stream temps réel
      // (`watchMessages`) recevra l'UPDATE et rafraîchira la bulle avec le
      // placeholder "Ce message a été supprimé".
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: 'Erreur lors de la suppression');
    }
  }

  /// Réagit à un message avec [emoji]. Si l'utilisateur avait déjà ce même
  /// emoji actif sur ce message, on le retire (toggle) ; sinon on
  /// ajoute/remplace sa réaction.
  Future<void> toggleReaction({
    required String messageId,
    required String emoji,
    required String currentUserId,
  }) async {
    // .where(...).firstOrNull est natif Dart 3 (dart:core via dart:collection),
    // aucune dépendance supplémentaire nécessaire.
    final existing = state.reactionsByMessageId[messageId]
        ?.where((r) => r.userId == currentUserId)
        .firstOrNull;

    try {
      if (existing != null && existing.emoji == emoji) {
        await _repository.removeReaction(messageId);
      } else {
        await _repository.setReaction(messageId: messageId, emoji: emoji);
      }
      if (!mounted) return;
      await _loadReactions(state.messages);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: 'Erreur lors de la réaction');
    }
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    _reactionsDebounce?.cancel();
    _reactionsSubscription?.cancel();
    super.dispose();
  }
}

// ==================== PROVIDERS ====================

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final chatListProvider = StateNotifierProvider<ChatListNotifier, ChatListState>((ref) {
  return ChatListNotifier(ref.watch(chatRepositoryProvider));
});

/// Provider "autoDispose" : une nouvelle instance de ChatNotifier est créée
/// chaque fois qu'on ouvre un écran de conversation, et elle est détruite
/// quand on le quitte (ferme le stream temps réel automatiquement).
final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref.watch(chatRepositoryProvider));
});

/// Id de l'utilisateur courant, pratique pour savoir si un message est "mien"
/// dans les écrans de chat.
///
/// IMPORTANT : ce provider est branché sur `authProvider` (via `ref.watch`)
/// au lieu de lire `SupabaseService.currentUserId` directement. Un simple
/// `Provider` sans dépendance réactive calcule sa valeur UNE SEULE FOIS et
/// la garde en cache : si la session n'était pas encore prête à ce moment,
/// la valeur restait figée (souvent à `null`), ce qui faussait totalement
/// le calcul "isMine" et donc l'alignement gauche/droite des bulles de chat
/// (tous les messages semblaient toujours du même côté, peu importe qui
/// était réellement connecté). En passant par `authProvider`, ce provider se
/// recalcule chaque fois que l'état d'authentification change.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).user?.id;
});
