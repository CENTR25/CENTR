/// A single chat message in the 1:1 student↔trainer conversation.
class Message {
  final String id;
  final String athleteId;

  /// Who sent it: 'student' or 'trainer'.
  final String senderRole;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.athleteId,
    required this.senderRole,
    required this.body,
    this.isRead = false,
    required this.createdAt,
  });

  bool get isFromTrainer => senderRole == 'trainer';
  bool get isFromStudent => senderRole == 'student';

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
    );
  }
}
