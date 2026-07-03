import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/presence_service.dart';

/// Stream provider : émet l'ensemble des ids d'utilisateurs en ligne,
/// mis à jour en temps réel par le canal de présence Supabase.
final onlineUsersProvider = StreamProvider<Set<String>>((ref) {
  return PresenceService.instance.onlineUserIdsStream;
});

/// Provider pratique : "cet utilisateur précis est-il en ligne ?"
/// Se recalcule automatiquement à chaque mise à jour de [onlineUsersProvider].
final isUserOnlineProvider = Provider.family<bool, String>((ref, userId) {
  final onlineUsers = ref.watch(onlineUsersProvider).value ?? {};
  return onlineUsers.contains(userId);
});
