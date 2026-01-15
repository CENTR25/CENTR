/// Notification type
enum NotificationType {
  firstLogin,
  newStudent,
  paymentReceived,
  subscriptionExpiring,
  streakAchievement,
  general;
  
  String get displayName {
    switch (this) {
      case NotificationType.firstLogin:
        return 'Primer Ingreso';
      case NotificationType.newStudent:
        return 'Nuevo Alumno';
      case NotificationType.paymentReceived:
        return 'Pago Recibido';
      case NotificationType.subscriptionExpiring:
        return 'Suscripción por Vencer';
      case NotificationType.streakAchievement:
        return 'Logro de Racha';
      case NotificationType.general:
        return 'General';
    }
  }
}

/// Notification model
class NotificationModel {
  final String id;
  final String userId; // Recipient
  final NotificationType type;
  final String title;
  final String message;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;
  
  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });
  
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => NotificationType.general,
      ),
      title: json['title'] as String,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type.name,
      'title': title,
      'message': message,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
