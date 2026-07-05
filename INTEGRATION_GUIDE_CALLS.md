// ============================================================================
// GUIDE D'INTÉGRATION - Affichage des appels échoués dans le chat
// ============================================================================
// 
// Ce fichier montre comment intégrer l'affichage des appels dans le chat
// pour que les utilisateurs voient l'historique des appels comme WhatsApp.
//
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ÉTAPE 1: Importer les modèles et services nécessaires
import 'package:message_ko/models/call_model.dart';
import 'package:message_ko/features/chat/widgets/call_event_bubble.dart';
import 'package:message_ko/features/calls/repositories/call_repository.dart';

/// ÉTAPE 2: Créer un provider pour les appels d'une conversation
/// (À ajouter dans chat_controller.dart)
final conversationCallsProvider = StreamProvider.family<List<CallModel>, String>(
  (ref, conversationId) {
    final repository = ref.watch(callRepositoryProvider);
    
    // Récupérer les deux utilisateurs de la conversation
    // Cette implémentation dépend de votre structure de données
    // Pour maintenant, nous supposons que vous avez les IDs des participants
    
    // Exemple (à adapter à votre logique):
    // return repository.watchCallsInConversation(conversationId);
    
    return Stream.value([]);  // À implémenter
  },
);

/// ÉTAPE 3: Mettre à jour la liste des messages pour inclure les appels
/// (À ajouter dans chat_screen.dart)

// Avant: Les messages sont affichés seuls
// Après: Les messages ET les appels sont affichés mélangés

/* 
// Exemple de fusion des messages et appels:

List<ChatHistoryItem> _mergeChatItems(
  List<MessageModel> messages,
  List<CallModel> calls,
) {
  final items = <ChatHistoryItem>[];
  
  // Ajouter les messages
  for (final msg in messages) {
    items.add(ChatHistoryItem.message(msg));
  }
  
  // Ajouter les appels
  for (final call in calls) {
    items.add(ChatHistoryItem.call(call));
  }
  
  // Trier par date (le plus récent d'abord)
  items.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  
  return items;
}

abstract class ChatHistoryItem {
  DateTime get dateTime;
  
  factory ChatHistoryItem.message(MessageModel msg) => _MessageItem(msg);
  factory ChatHistoryItem.call(CallModel call) => _CallItem(call);
}

class _MessageItem implements ChatHistoryItem {
  _MessageItem(this.message);
  final MessageModel message;
  
  @override
  DateTime get dateTime => message.createdAt;
}

class _CallItem implements ChatHistoryItem {
  _CallItem(this.call);
  final CallModel call;
  
  @override
  DateTime get dateTime => call.createdAt;
}
*/

/// ÉTAPE 4: Afficher les appels dans la liste
/// (Mettre à jour dans la méthode _buildMessageList de chat_screen.dart)

/*
// Dans le ListView.builder:

return ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    
    if (item is _MessageItem) {
      // Afficher le message normalement
      return _buildMessageBubble(item.message);
      
    } else if (item is _CallItem) {
      // Afficher l'appel
      final isMine = item.call.callerId == currentUserId;
      return CallEventBubble(
        call: item.call,
        isMine: isMine,
      );
    }
  },
);
*/

/// ÉTAPE 5: Intégrer la gestion des appels échoués
/// (Mettre à jour dans call_controller.dart)

/*
// Dans le contrôleur d'appels:

Future<void> handleCallFailure(String callId, String reason) async {
  try {
    // Marquer l'appel comme échoué
    await _callRepository.failCall(callId, reason);
    
    // Afficher une notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel échoué: $reason'),
        duration: const Duration(seconds: 3),
      ),
    );
  } catch (e) {
    // Gérer l'erreur
  }
}

Future<void> handleMissedCall(String callId) async {
  try {
    // Marquer l'appel comme manqué
    await _callRepository.missedCall(callId);
  } catch (e) {
    // Gérer l'erreur
  }
}
*/

/// ÉTAPE 6: Afficher les notifications pour les appels manqués
/// (Dans le service de notification)

/*
void _handleIncomingCallNotification(CallModel call) {
  // Montrer une notification système
  // Si l'utilisateur ne répond pas après 60 secondes, marquer comme manqué
  
  Timer(const Duration(seconds: 60), () {
    if (call.status == CallStatus.ringing) {
      // L'appel n'a pas été accepté
      _callRepository.missedCall(call.id);
    }
  });
}
*/

/// ÉTAPE 7: Exemples d'utilisation
class ChatScreenIntegrationExample extends ConsumerWidget {
  final String otherUserId;
  const ChatScreenIntegrationExample({required this.otherUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Récupérer les messages
    // final messages = ref.watch(messagesProvider(otherUserId));
    
    // Récupérer les appels
    // final calls = ref.watch(callsProvider(otherUserId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          // Bouton pour appel audio
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Démarrer un appel audio
              // ref.read(callProvider.notifier).startCall(
              //   CallMediaType.audio,
              //   otherUserId,
              // );
            },
          ),
          // Bouton pour appel vidéo
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // Démarrer un appel vidéo
              // ref.read(callProvider.notifier).startCall(
              //   CallMediaType.video,
              //   otherUserId,
              // );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Chat avec historique des appels'),
      ),
    );
  }
}

/// ÉTAPE 8: Statuts possibles pour les appels

/*
enum CallStatus {
  ringing,      // En cours d'appel
  accepted,     // Accepté
  declined,     // Décliné par le destinataire
  ended,        // Terminé normalement
  missed,       // Appel manqué (pas de réponse)
  failed,       // Appel échoué (erreur technique)
}

Les statuts s'affichent comme:
- ended:   "Appel émis" ou "Appel reçu" (vert)
- declined: "Appel décliné" (orange)
- missed:  "Appel manqué" (orange)
- failed:  "Appel échoué" (rouge) + raison de l'erreur
*/

/// ÉTAPE 9: Raisons d'erreur possibles

/*
Erreurs réseau:
- "Réseau indisponible"
- "Mauvaise connexion"
- "Timeout de connexion"

Erreurs logicielles:
- "WebRTC non initialisé"
- "Erreur de codec"
- "Erreur du microphone"
- "Erreur de la caméra"

Erreurs utilisateur:
- "Utilisateur bloqué"
- "Utilisateur hors ligne"
- "Appel rejeté"
*/

// ============================================================================
// RÉSUMÉ DE L'INTÉGRATION
// ============================================================================
//
// 1. ✅ Ajouter les colonnes manquantes à la table "calls" (failure_reason)
// 2. ✅ Mettre à jour CallModel pour inclure failureReason
// 3. ✅ Créer CallEventBubble pour afficher les appels
// 4. ✅ Ajouter les méthodes failCall() et missedCall() au repository
// 5. ❌ Mettre à jour chat_controller pour charger les appels
// 6. ❌ Fusionner les messages et appels dans la liste
// 7. ❌ Afficher CallEventBubble dans le ListView du chat
// 8. ❌ Appeler failCall/missedCall dans le contrôleur d'appels
// 9. ❌ Tester complètement
//
// ============================================================================
