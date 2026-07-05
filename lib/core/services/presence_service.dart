import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Gère la présence en ligne de l'utilisateur courant et permet d'observer
/// la présence des autres utilisateurs, via un canal Supabase Realtime
/// Presence unique et partagé pour toute l'application ("online-users").
///
/// Principe : chaque client connecté "track" sa propre présence sur le canal.
/// Supabase diffuse alors à tous les clients abonnés la liste à jour des
/// utilisateurs présents. Pas besoin de table SQL : c'est un état éphémère
/// géré en mémoire par Supabase Realtime (le statut disparaît automatiquement
/// si l'utilisateur perd la connexion ou ferme l'app).
class PresenceService {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  static const String _channelName = 'online-users';

  RealtimeChannel? _channel;
  final _onlineUserIds = <String>{};
  final _onlineController = StreamController<Set<String>>.broadcast();

  /// Stream émettant l'ensemble des ids d'utilisateurs actuellement en ligne.
  Stream<Set<String>> get onlineUserIdsStream => _onlineController.stream;

  Set<String> get currentOnlineUserIds => Set.unmodifiable(_onlineUserIds);

  bool isOnline(String userId) => _onlineUserIds.contains(userId);

  /// À appeler une fois après la connexion de l'utilisateur (ex: dans main.dart
  /// ou juste après authentification réussie).
  Future<void> initialize() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null || _channel != null) return;

    final channel = SupabaseService.client.channel(_channelName);

    channel.onPresenceSync((payload) {
      _syncOnlineUsers(channel);
    }).onPresenceJoin((payload) {
      _syncOnlineUsers(channel);
    }).onPresenceLeave((payload) {
      _syncOnlineUsers(channel);
    });

    channel.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await channel.track({
          'user_id': userId,
          'online_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    });

    _channel = channel;
  }

  void _syncOnlineUsers(RealtimeChannel channel) {
    final presences = channel.presenceState();
    final ids = <String>{};
    for (final entry in presences) {
      for (final p in entry.presences) {
        final userId = p.payload['user_id'] as String?;
        if (userId != null) ids.add(userId);
      }
    }
    _onlineUserIds
      ..clear()
      ..addAll(ids);
    _onlineController.add(Set.unmodifiable(_onlineUserIds));
  }

  /// À appeler à la déconnexion (logout) pour quitter proprement le canal.
  Future<void> dispose() async {
    if (_channel != null) {
      await _channel!.untrack();
      await SupabaseService.client.removeChannel(_channel!);
      _channel = null;
    }
    _onlineUserIds.clear();
  }
}
