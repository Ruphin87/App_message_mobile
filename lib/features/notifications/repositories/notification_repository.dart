import '../../../core/services/supabase_service.dart';
import '../../../models/notification_model.dart';

class NotificationRepository {
  NotificationRepository();

  final _client = SupabaseService.client;

  /// Historique des notifications de l'utilisateur courant, les plus
  /// récentes en premier.
  Future<List<NotificationModel>> getNotifications() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', currentUserId)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Nombre de notifications non lues — utilisé pour le badge sur l'icône
  /// de la bottom nav bar.
  Future<int> getUnreadCount() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', currentUserId)
        .eq('is_read', false);

    return (response as List).length;
  }

  Future<void> markAsRead(String notificationId) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', currentUserId)
        .eq('is_read', false);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _client.from('notifications').delete().eq('id', notificationId);
  }

  /// Stream temps réel GLOBAL : émet un événement à chaque changement sur
  /// la table `notifications`, pour rafraîchir l'historique et le badge de
  /// compteur dès qu'une nouvelle notification arrive (sans devoir rouvrir
  /// l'écran). Comme pour les autres streams "any change" de l'app, ce flux
  /// n'est pas filtré par utilisateur côté serveur — il sert uniquement de
  /// déclencheur, les RLS protègent les vraies lectures.
  Stream<void> watchAnyNotificationChange() {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .map((_) {});
  }
}
