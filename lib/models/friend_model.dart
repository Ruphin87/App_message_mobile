import 'user_model.dart';

enum FriendStatus {
  pending,
  accepted,
  rejected;

  static FriendStatus fromString(String value) {
    return FriendStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => FriendStatus.pending,
    );
  }
}

class FriendModel {
  const FriendModel({
    required this.id,
    required this.userId,
    required this.friendId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.friendProfile,
  });

  final String id;
  final String userId;
  final String friendId;
  final FriendStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// Profil de l'autre utilisateur (rempli côté repository via une jointure,
  /// pas forcément présent dans le JSON brut de la table `friends`).
  final UserModel? friendProfile;

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    return FriendModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      friendId: json['friend_id'] as String,
      status: FriendStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      friendProfile: json['friend_profile'] != null
          ? UserModel.fromJson(json['friend_profile'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Lecture depuis une ligne `local_friends`. Comme pour les conversations,
  /// [friendProfile] n'est pas reconstruit ici — il vient d'une jointure
  /// séparée avec `local_users` faite par le repository.
  factory FriendModel.fromLocalDb(Map<String, dynamic> row) {
    return FriendModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      friendId: row['friend_id'] as String,
      status: FriendStatus.fromString(row['status'] as String),
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  /// Conversion vers une ligne insérable dans `local_friends`.
  /// [friendProfileId] est l'id du profil affiché (calculé par le repository
  /// selon qu'on regarde la relation en tant que demandeur ou destinataire).
  Map<String, dynamic> toLocalDb({String? friendProfileId}) {
    return {
      'id': id,
      'user_id': userId,
      'friend_id': friendId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'friend_profile_id': friendProfileId ?? friendProfile?.id,
    };
  }

  FriendModel copyWith({
    String? id,
    String? userId,
    String? friendId,
    FriendStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserModel? friendProfile,
  }) {
    return FriendModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      friendId: friendId ?? this.friendId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      friendProfile: friendProfile ?? this.friendProfile,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FriendModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}