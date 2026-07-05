class MessageReactionModel {
  const MessageReactionModel({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;

  factory MessageReactionModel.fromJson(Map<String, dynamic> json) {
    return MessageReactionModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      userId: json['user_id'] as String,
      emoji: json['emoji'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory MessageReactionModel.fromLocalDb(Map<String, dynamic> row) {
    return MessageReactionModel(
      id: row['id'] as String,
      messageId: row['message_id'] as String,
      userId: row['user_id'] as String,
      emoji: row['emoji'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toLocalDb() {
    return {
      'id': id,
      'message_id': messageId,
      'user_id': userId,
      'emoji': emoji,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageReactionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Liste fixe des emojis proposés pour réagir à un message, façon WhatsApp.
const List<String> kQuickReactionEmojis = ['❤️', '😂', '😮', '😢', '🙏'];
