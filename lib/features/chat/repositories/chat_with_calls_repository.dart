import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/call_model.dart';
import '../../../models/message_model.dart';

/// Élément combiné pour afficher dans le chat (message OU appel)
abstract class ChatItem {
  DateTime get dateTime;
}

/// Élément de message
class ChatMessageItem implements ChatItem {
  final MessageModel message;

  ChatMessageItem(this.message);

  @override
  DateTime get dateTime => message.createdAt;
}

/// Élément d'appel
class ChatCallItem implements ChatItem {
  final CallModel call;

  ChatCallItem(this.call);

  @override
  DateTime get dateTime => call.createdAt;
}

/// Service pour charger les messages et appels combinés
class ChatWithCallsRepository {
  /// Obtient les messages et appels pour une conversation, mélangés et triés par date
  static Future<List<ChatItem>> getChatItemsForConversation(
    String userId,
    String otherUserId,
  ) async {
    final items = <ChatItem>[];

    // Charger les messages
    // Note: La méthode exacte dépend de l'implémentation de ChatRepository
    // Adapter selon les méthodes disponibles (ex: getMessages, getConversation, etc.)
    // final messages = await chatRepository.getMessagesForConversation(userId, otherUserId);
    // items.addAll(messages.map((msg) => ChatMessageItem(msg)));

    // Charger les appels (messages privés entre ces deux utilisateurs)
    // Dans une vraie app, on aurait besoin d'une table de jointure ou une requête spécifique
    // Pour maintenant, on laisse le système de messages gérer les appels aussi

    // Trier par date décroissante
    items.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return items;
  }
}

/// Provider pour les appels récents dans une conversation
final chatCallsProvider = FutureProvider.family<List<CallModel>, String>(
  (ref, conversationId) async {
    // Récupérer les appels de la conversation
    // Cela nécessite une implémentation côté repository
    return [];
  },
);
