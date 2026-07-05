enum AttachmentType {
  image,
  pdf,
  audio,
  document,
}

class AttachmentModel {
  const AttachmentModel({
    required this.id,
    required this.messageId,
    required this.fileUrl,
    required this.fileType,
    this.fileName,
    this.fileSize,
    required this.createdAt,
  });

  final String id;
  final String messageId;
  final String fileUrl;
  final AttachmentType fileType;
  final String? fileName;
  final int? fileSize;
  final DateTime createdAt;

  factory AttachmentModel.fromJson(Map<String, dynamic> json) {
    return AttachmentModel(
      id: json['id'] as String,
      messageId: json['message_id'] as String,
      fileUrl: json['file_url'] as String,
      fileType: _typeFromValue(json['file_type'] as String?),
      fileName: json['file_name'] as String?,
      fileSize: json['file_size'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message_id': messageId,
      'file_url': fileUrl,
      'file_type': fileType.name,
      'file_name': fileName,
      'file_size': fileSize,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  static AttachmentType _typeFromValue(String? value) {
    return AttachmentType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => AttachmentType.document,
    );
  }
}
