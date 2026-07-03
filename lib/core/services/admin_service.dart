import 'package:supabase_flutter/supabase_flutter.dart';
import './security_service.dart';
import '../../../core/services/supabase_service.dart';

/// Service d'administration pour gérer l'application
class AdminService {
  AdminService._();

  static const String _adminPassword = 'twins@2026RP!';
  static final SupabaseClient _client = SupabaseService.client;
  static bool _adminSessionUnlocked = false;

  static bool get isAdminSessionUnlocked => _adminSessionUnlocked;

  static void lockAdminSession() {
    _adminSessionUnlocked = false;
  }

  /// Vérifie si le mot de passe admin est correct
  static bool verifyAdminPassword(String password) {
    final isValid =
        SecurityService.hashPassword(password) == SecurityService.hashPassword(_adminPassword);
    if (isValid) {
      _adminSessionUnlocked = true;
    }
    return isValid;
  }

  /// Obtient les statistiques globales
  static Future<AdminStats> getAdminStats() async {
    try {
      // Nombre d'utilisateurs
      final usersCount = await _client
          .from('users')
          .select()
          .count(CountOption.exact)
          .then((response) => response.count);

      // Nombre de messages
      final messagesCount = await _client
          .from('messages')
          .select()
          .count(CountOption.exact)
          .then((response) => response.count);

      // Nombre d'utilisateurs bloqués
      final blockedCount = await _client
          .from('users')
          .select()
          .eq('is_blocked', true)
          .count(CountOption.exact)
          .then((response) => response.count);

      // Nombre de signalements
      final reportsCount = await _client
          .from('reports')
          .select()
          .count(CountOption.exact)
          .then((response) => response.count);

      return AdminStats(
        totalUsers: usersCount,
        totalMessages: messagesCount,
        blockedUsers: blockedCount,
        totalReports: reportsCount,
      );
    } catch (e) {
      throw Exception('Erreur lors de la récupération des statistiques: $e');
    }
  }

  /// Obtient la liste des messages (avec filtrage par ancienneté)
  static Future<List<AdminMessage>> getMessages({
    int? olderThanDays,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final now = DateTime.now();
      final query = _client.from('messages').select(
            'id, conversation_id, sender_id, message, attachment_type, created_at',
          );

      // Filtrer par ancienneté si spécifié
      if (olderThanDays != null && olderThanDays > 0) {
        final cutoffDate =
            now.subtract(Duration(days: olderThanDays)).toUtc().toIso8601String();
        query.lt('created_at', cutoffDate);
      }

      // Ajouter la pagination et le tri
      query.order('created_at', ascending: false).range(offset, offset + limit - 1);

      final response = await query;

      return (response as List)
          .map((msg) => AdminMessage.fromJson(msg))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des messages: $e');
    }
  }

  /// Supprime un message
  static Future<void> deleteMessage(String messageId) async {
    try {
      // D'abord supprimer les pièces jointes si elles existent
      await _client.storage.from('attachments').remove(['$messageId']);

      // Ensuite supprimer le message
      await _client.from('messages').delete().eq('id', messageId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du message: $e');
    }
  }

  /// Supprime tous les messages plus anciens que N jours
  static Future<int> deleteOldMessages(int olderThanDays) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: olderThanDays)).toUtc().toIso8601String();

      // Récupérer d'abord les messages à supprimer
      final messages = await _client
          .from('messages')
          .select('id')
          .lt('created_at', cutoffDate);

      // Supprimer les pièces jointes
      for (final msg in messages) {
        try {
          await _client.storage.from('attachments').remove([msg['id']]);
        } catch (e) {
          // Ignorer les erreurs si le fichier n'existe pas
        }
      }

      // Supprimer les messages
      await _client
          .from('messages')
          .delete()
          .lt('created_at', cutoffDate);

      return messages.length;
    } catch (e) {
      throw Exception('Erreur lors de la suppression des messages: $e');
    }
  }

  /// Obtient les messages d'1 mois
  static Future<List<AdminMessage>> getMessagesAboutToExpire({
    int expiryDays = 30,
    int limit = 100,
  }) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: expiryDays)).toUtc().toIso8601String();

      final response = await _client
          .from('messages')
          .select(
            'id, conversation_id, sender_id, message, attachment_type, created_at',
          )
          .lt('created_at', cutoffDate)
          .order('created_at', ascending: true)
          .limit(limit);

      return (response as List)
          .map((msg) => AdminMessage.fromJson(msg))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des messages expirant: $e');
    }
  }

  /// Bloque un utilisateur
  static Future<void> blockUser(String userId) async {
    try {
      await _client.from('users').update({'is_blocked': true}).eq('id', userId);
    } catch (e) {
      throw Exception('Erreur lors du blocage de l\'utilisateur: $e');
    }
  }

  /// Débloque un utilisateur
  static Future<void> unblockUser(String userId) async {
    try {
      await _client.from('users').update({'is_blocked': false}).eq('id', userId);
    } catch (e) {
      throw Exception('Erreur lors du déblocage de l\'utilisateur: $e');
    }
  }

  /// Obtient les utilisateurs bloqués
  static Future<List<AdminUser>> getBlockedUsers({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('users')
          .select('id, nom, email, created_at, is_blocked')
          .eq('is_blocked', true)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((user) => AdminUser.fromJson(user))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des utilisateurs bloqués: $e');
    }
  }

  /// Obtient les signalements
  static Future<List<AdminReport>> getReports({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _client
          .from('reports')
          .select('id, reporter_id, reported_user_id, reason, created_at, status')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((report) => AdminReport.fromJson(report))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des signalements: $e');
    }
  }

  /// Marque un signalement comme traité
  static Future<void> resolveReport(String reportId) async {
    try {
      await _client
          .from('reports')
          .update({'status': 'resolved'}).eq('id', reportId);
    } catch (e) {
      throw Exception('Erreur lors de la résolution du signalement: $e');
    }
  }

  /// Supprime un signalement
  static Future<void> deleteReport(String reportId) async {
    try {
      await _client.from('reports').delete().eq('id', reportId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression du signalement: $e');
    }
  }
}

/// Modèle pour les statistiques admin
class AdminStats {
  final int totalUsers;
  final int totalMessages;
  final int blockedUsers;
  final int totalReports;

  AdminStats({
    required this.totalUsers,
    required this.totalMessages,
    required this.blockedUsers,
    required this.totalReports,
  });
}

/// Modèle pour un message admin
class AdminMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String? content;
  final String? attachmentType;
  final DateTime createdAt;

  AdminMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.content,
    this.attachmentType,
    required this.createdAt,
  });

  bool get isOlderThan30Days {
    return DateTime.now().difference(createdAt).inDays >= 30;
  }

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['message'] as String?,
      attachmentType: json['attachment_type'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Modèle pour un utilisateur admin
class AdminUser {
  final String id;
  final String nom;
  final String email;
  final DateTime createdAt;
  final bool isBlocked;

  AdminUser({
    required this.id,
    required this.nom,
    required this.email,
    required this.createdAt,
    required this.isBlocked,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      nom: json['nom'] as String,
      email: json['email'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }
}

/// Modèle pour un signalement
class AdminReport {
  final String id;
  final String reporterId;
  final String reportedUserId;
  final String reason;
  final DateTime createdAt;
  final String status;

  AdminReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.createdAt,
    required this.status,
  });

  factory AdminReport.fromJson(Map<String, dynamic> json) {
    return AdminReport(
      id: json['id'] as String,
      reporterId: json['reporter_id'] as String,
      reportedUserId: json['reported_user_id'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String? ?? 'pending',
    );
  }
}
