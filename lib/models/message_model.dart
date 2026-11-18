/// A single chat message in the 1:1 student↔trainer conversation.
class Message {
  final String id;
  final String athleteId;

  /// Who sent it: 'student' or 'trainer'.
  final String senderRole;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  /// 'image' | 'audio' | null. The file lives in the private chat-media
  /// bucket at [attachmentPath] (shown via a signed URL).
  final String? attachmentType;
  final String? attachmentPath;
  final int? attachmentDurationMs;

  Message({
    required this.id,
    required this.athleteId,
    required this.senderRole,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.attachmentType,
    this.attachmentPath,
    this.attachmentDurationMs,
  });

  bool get isFromTrainer => senderRole == 'trainer';
  bool get isFromStudent => senderRole == 'student';
  bool get isImage => attachmentType == 'image' && attachmentPath != null;
  bool get isAudio => attachmentType == 'audio' && attachmentPath != null;

  /// One-line text for inbox rows / notifications.
  static String preview(String? body, String? attachmentType) {
    final text = (body ?? '').trim();
    if (text.isNotEmpty) return text;
    return switch (attachmentType) {
      'image' => '📷 Foto',
      'audio' => '🎤 Nota de voz',
      _ => '',
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    String? asStr(Object? v) =>
        v == null ? null : (v is String ? v : v.toString());

    return Message(
      id: json['id']?.toString() ?? '',
      athleteId: asStr(json['athlete_id']) ?? '',
      senderRole: asStr(json['sender_role']) ?? 'student',
      body: asStr(json['body']) ?? '',
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      attachmentType: asStr(json['attachment_type']),
      attachmentPath: asStr(json['attachment_path']),
      attachmentDurationMs: (json['attachment_duration_ms'] as num?)?.toInt(),
    );
  }
}
