enum MessageStatus {
  sent, // 1 coche grise — le message est en base, pas encore livré
  delivered, // 2 coches grises — arrivé sur l'appareil du destinataire
  read, // 2 coches bleues — lu par le destinataire
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.deliveredAt,
    this.isDeletedForEveryone = false,
    this.deletedFor = const [],
    this.replyToId,
    this.replyToPreview,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  /// true si l'expéditeur a choisi "Supprimer pour tout le monde" — le texte
  /// original est alors déjà vidé côté serveur ; l'UI affiche un placeholder
  /// ("Ce message a été supprimé") à la place de [message].
  final bool isDeletedForEveryone;

  /// Ids des utilisateurs ayant choisi "Supprimer pour moi" sur ce message.
  /// Le message reste normalement visible pour les autres participants.
  final List<String> deletedFor;

  /// Id du message auquel celui-ci répond (reply), s'il y en a un.
  final String? replyToId;

  /// Aperçu du message cité, rempli côté repository via une jointure locale
  /// (pas une colonne réelle de la table `messages`) — évite une requête
  /// séparée à chaque affichage de bulle.
  final MessageModel? replyToPreview;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      // Supabase renvoie les timestamps en UTC ; .parse() les lit comme UTC
      // (le suffixe 'Z' ou l'offset est inclus), .toLocal() les convertit
      // ensuite vers l'heure du téléphone pour un affichage correct.
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String).toLocal()
          : null,
      isDeletedForEveryone: json['is_deleted_for_everyone'] as bool? ?? false,
      deletedFor: (json['deleted_for'] as List?)?.map((e) => e as String).toList() ?? [],
      replyToId: json['reply_to_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message': message,
      'is_read': isRead,
      'created_at': createdAt.toUtc().toIso8601String(),
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'is_deleted_for_everyone': isDeletedForEveryone,
      'deleted_for': deletedFor,
      'reply_to_id': replyToId,
    };
  }

  /// Lecture depuis une ligne de la base locale SQLite (table `local_messages`).
  factory MessageModel.fromLocalDb(Map<String, dynamic> row) {
    return MessageModel(
      id: row['id'] as String,
      conversationId: row['conversation_id'] as String,
      senderId: row['sender_id'] as String,
      message: row['message'] as String,
      isRead: (row['is_read'] as int) == 1,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      deliveredAt: row['delivered_at'] != null
          ? DateTime.parse(row['delivered_at'] as String).toLocal()
          : null,
      isDeletedForEveryone: (row['is_deleted_for_everyone'] as int? ?? 0) == 1,
      deletedFor: (row['deleted_for'] as String? ?? '')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      replyToId: row['reply_to_id'] as String?,
    );
  }

  /// Conversion vers une ligne insérable dans la base locale SQLite.
  /// SQLite n'a pas de type tableau natif : `deletedFor` est stocké comme
  /// une chaîne d'ids séparés par des virgules.
  Map<String, dynamic> toLocalDb() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'message': message,
      'is_read': isRead ? 1 : 0,
      'created_at': createdAt.toUtc().toIso8601String(),
      'delivered_at': deliveredAt?.toUtc().toIso8601String(),
      'is_deleted_for_everyone': isDeletedForEveryone ? 1 : 0,
      'deleted_for': deletedFor.join(','),
      'reply_to_id': replyToId,
    };
  }

  bool isMine(String currentUserId) => senderId == currentUserId;

  /// true si CET utilisateur a choisi "Supprimer pour moi" — dans ce cas,
  /// le message doit être totalement masqué de sa liste, comme s'il
  /// n'existait pas.
  bool isHiddenFor(String userId) => deletedFor.contains(userId);

  /// Texte à afficher réellement dans la bulle : le vrai message, ou un
  /// placeholder si supprimé pour tout le monde.
  String get displayText =>
      isDeletedForEveryone ? 'Ce message a été supprimé' : message;

  MessageStatus get status {
    if (isRead) return MessageStatus.read;
    if (deliveredAt != null) return MessageStatus.delivered;
    return MessageStatus.sent;
  }

  MessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? message,
    bool? isRead,
    DateTime? createdAt,
    DateTime? deliveredAt,
    bool? isDeletedForEveryone,
    List<String>? deletedFor,
    String? replyToId,
    MessageModel? replyToPreview,
  }) {
    return MessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      isDeletedForEveryone: isDeletedForEveryone ?? this.isDeletedForEveryone,
      deletedFor: deletedFor ?? this.deletedFor,
      replyToId: replyToId ?? this.replyToId,
      replyToPreview: replyToPreview ?? this.replyToPreview,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}