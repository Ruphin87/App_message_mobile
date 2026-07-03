import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationsState {
  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  NotificationsNotifier(this._repository) : super(const NotificationsState()) {
    loadAll();
    _listenForChanges();
  }

  final NotificationRepository _repository;
  StreamSubscription<void>? _changesSubscription;
  Timer? _debounceTimer;

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait<dynamic>([
        _repository.getNotifications(),
        _repository.getUnreadCount(),
      ]);
      final notifications = results[0] as List<NotificationModel>;
      final unreadCount = results[1] as int;
      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Erreur lors du chargement des notifications',
      );
    }
  }

  /// Écoute en temps réel tout changement sur `notifications` (nouvelle
  /// notification reçue via push, marquage lu) et relance le chargement —
  /// c'est ce qui met à jour le badge de compteur en direct, par exemple
  /// pendant que l'utilisateur a déjà l'app ouverte sur un autre écran.
  void _listenForChanges() {
    _changesSubscription = _repository.watchAnyNotificationChange().listen((_) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        loadAll();
      });
    });
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors du marquage comme lu');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _repository.markAllAsRead();
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors du marquage global');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _repository.deleteNotification(notificationId);
      await loadAll();
    } catch (e) {
      state = state.copyWith(error: 'Erreur lors de la suppression');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _changesSubscription?.cancel();
    super.dispose();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository();
});

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(notificationRepositoryProvider));
});

/// Provider pratique pour afficher juste le badge de compteur (par exemple
/// sur l'icône de la bottom nav bar), sans avoir à observer tout l'état.
final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(notificationsProvider).unreadCount;
});
