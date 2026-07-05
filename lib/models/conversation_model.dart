import 'user_model.dart';

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.user1,
    required this.user2,
    required this.createdAt,
    required this.lastMessageAt,
    this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
    this.deletedFor = const [],
  });

  final String id;
  final String user1;
  final String user2;
  final DateTime createdAt;
  final DateTime lastMessageAt;

  /// Profil de l'autre participant (calculé côté repository selon l'utilisateur courant).
  final UserModel? otherUser;

  /// Dernier message de la conversation (pour l'aperçu dans la liste).
  final String? lastMessage;

  /// Nombre de messages non lus pour l'utilisateur courant.
  final int unreadCount;

  /// Ids des utilisateurs ayant choisi de supprimer cette conversation de
  /// leur propre liste ("Supprimer la conversation"). La conversation (et
  /// tous ses messages) reste intacte pour l'autre participant — exactement
  /// comme la suppression "pour moi" d'un message, mais appliquée à toute la
  /// discussion d'un coup.
  final List<String> deletedFor;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      user1: json['user1'] as String,
      user2: json['user2'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      lastMessageAt: DateTime.parse(json['last_message_at'] as String).toLocal(),
      otherUser: json['other_user'] != null
          ? UserModel.fromJson(json['other_user'] as Map<String, dynamic>)
          : null,
      lastMessage: json['last_message'] as String?,
      unreadCount: json['unread_count'] as int? ?? 0,
      deletedFor: (json['deleted_for'] as List?)?.map((e) => e as String).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user1': user1,
      'user2': user2,
      'created_at': createdAt.toUtc().toIso8601String(),
      'last_message_at': lastMessageAt.toUtc().toIso8601String(),
      'deleted_for': deletedFor,
    };
  }

  /// Lecture depuis une ligne `local_conversations`. Le profil de l'autre
  /// utilisateur n'est PAS reconstruit ici (il vient d'une jointure séparée
  /// avec `local_users` faite par le repository), donc [otherUser] reste
  /// `null` à ce stade et doit être renseigné via `copyWith` ensuite.
  factory ConversationModel.fromLocalDb(Map<String, dynamic> row) {
    return ConversationModel(
      id: row['id'] as String,
      user1: row['user1'] as String,
      user2: row['user2'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      lastMessageAt: DateTime.parse(row['last_message_at'] as String).toLocal(),
      lastMessage: row['last_message'] as String?,
      unreadCount: row['unread_count'] as int? ?? 0,
      deletedFor: (row['deleted_for'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  /// Conversion vers une ligne insérable dans `local_conversations`.
  /// On stocke seulement l'id de l'autre utilisateur (`other_user_id`) — son
  /// profil complet est dans `local_users`, récupéré via une jointure faite
  /// par le repository au moment de la lecture.
  Map<String, dynamic> toLocalDb(String currentUserId) {
    return {
      'id': id,
      'user1': user1,
      'user2': user2,
      'created_at': createdAt.toUtc().toIso8601String(),
      'last_message_at': lastMessageAt.toUtc().toIso8601String(),
      'other_user_id': otherUserId(currentUserId),
      'last_message': lastMessage,
      'unread_count': unreadCount,
      'deleted_for': deletedFor.join(','),
    };
  }

  /// Retourne l'id de l'autre utilisateur par rapport à [currentUserId].
  String otherUserId(String currentUserId) {
    return user1 == currentUserId ? user2 : user1;
  }

  /// true si CET utilisateur a supprimé cette conversation de sa liste —
  /// dans ce cas elle doit être totalement masquée pour lui, comme si elle
  /// n'existait pas, sans affecter l'autre participant.
  bool isHiddenFor(String userId) => deletedFor.contains(userId);

  ConversationModel copyWith({
    String? id,
    String? user1,
    String? user2,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    UserModel? otherUser,
    String? lastMessage,
    int? unreadCount,
    List<String>? deletedFor,
  }) {
    return ConversationModel(
      id: id ?? this.id,
      user1: user1 ?? this.user1,
      user2: user2 ?? this.user2,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      otherUser: otherUser ?? this.otherUser,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      deletedFor: deletedFor ?? this.deletedFor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConversationModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}