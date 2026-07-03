enum CallMediaType {
  audio,
  video;

  static CallMediaType fromString(String value) {
    return value == 'video' ? CallMediaType.video : CallMediaType.audio;
  }

  String get value => switch (this) {
        CallMediaType.audio => 'audio',
        CallMediaType.video => 'video',
      };
}

enum CallStatus {
  ringing,
  accepted,
  declined,
  ended,
  missed,
  failed;

  static CallStatus fromString(String value) {
    return CallStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => CallStatus.ringing,
    );
  }
}

class CallModel {
  const CallModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.mediaType,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
    this.failureReason,
  });

  final String id;
  final String callerId;
  final String receiverId;
  final CallMediaType mediaType;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;
  final String? failureReason;

  factory CallModel.fromJson(Map<String, dynamic> json) {
    return CallModel(
      id: json['id'] as String,
      callerId: json['caller_id'] as String,
      receiverId: json['receiver_id'] as String,
      mediaType: CallMediaType.fromString(json['media_type'] as String),
      status: CallStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at'] as String) : null,
      failureReason: json['failure_reason'] as String?,
    );
  }

  bool isParticipant(String userId) {
    return callerId == userId || receiverId == userId;
  }
}

class CallEventModel {
  const CallEventModel({
    required this.id,
    required this.callId,
    required this.senderId,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String callId;
  final String senderId;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory CallEventModel.fromJson(Map<String, dynamic> json) {
    return CallEventModel(
      id: json['id'] as String,
      callId: json['call_id'] as String,
      senderId: json['sender_id'] as String,
      eventType: json['event_type'] as String,
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CallRouteArgs {
  const CallRouteArgs({
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    required this.mediaType,
    required this.isCaller,
  });

  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final CallMediaType mediaType;
  final bool isCaller;
}
