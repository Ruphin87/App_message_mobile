import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/admin_service.dart';

// Providers pour les statistiques admin
final adminStatsProvider = FutureProvider<AdminStats>((ref) async {
  return await AdminService.getAdminStats();
});

// Provider pour les messages à expirer (1 mois)
final messagesAboutToExpireProvider = FutureProvider<List<AdminMessage>>((ref) async {
  return await AdminService.getMessagesAboutToExpire();
});

// Provider pour les messages anciens
final oldMessagesProvider = FutureProvider.family<List<AdminMessage>, int>(
  (ref, olderThanDays) async {
    return await AdminService.getMessages(olderThanDays: olderThanDays);
  },
);

// Provider pour les utilisateurs bloqués
final blockedUsersProvider = FutureProvider<List<AdminUser>>((ref) async {
  return await AdminService.getBlockedUsers();
});

// Provider pour les signalements
final reportsProvider = FutureProvider<List<AdminReport>>((ref) async {
  return await AdminService.getReports();
});

// StateNotifier pour les actions admin
class AdminNotifier extends StateNotifier<AdminState> {
  AdminNotifier() : super(const AdminState());

  Future<void> deleteOldMessages(int olderThanDays) async {
    state = state.copyWith(isLoading: true);
    try {
      final count = await AdminService.deleteOldMessages(olderThanDays);
      state = state.copyWith(
        isLoading: false,
        successMessage: '$count messages supprimés',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> blockUser(String userId) async {
    try {
      await AdminService.blockUser(userId);
      state = state.copyWith(successMessage: 'Utilisateur bloqué');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      await AdminService.unblockUser(userId);
      state = state.copyWith(successMessage: 'Utilisateur débloqué');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await AdminService.deleteMessage(messageId);
      state = state.copyWith(successMessage: 'Message supprimé');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> resolveReport(String reportId) async {
    try {
      await AdminService.resolveReport(reportId);
      state = state.copyWith(successMessage: 'Signalement résolu');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      await AdminService.deleteReport(reportId);
      state = state.copyWith(successMessage: 'Signalement supprimé');
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  void clearMessages() {
    state = state.copyWith(
      successMessage: null,
      errorMessage: null,
    );
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier();
});

class AdminState {
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;

  const AdminState({
    this.isLoading = false,
    this.successMessage,
    this.errorMessage,
  });

  AdminState copyWith({
    bool? isLoading,
    String? successMessage,
    String? errorMessage,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage,
      errorMessage: errorMessage,
    );
  }
}
