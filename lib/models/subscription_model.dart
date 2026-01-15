/// Subscription plan type
enum SubscriptionPlanType {
  basic5(5, 'Básico', 299),
  standard25(25, 'Estándar', 599),
  pro50(50, 'Profesional', 999),
  enterprise100(100, 'Empresarial', 1499);
  
  final int maxStudents;
  final String displayName;
  final double monthlyPrice; // In MXN
  
  const SubscriptionPlanType(this.maxStudents, this.displayName, this.monthlyPrice);
  
  static SubscriptionPlanType fromMaxStudents(int max) {
    return SubscriptionPlanType.values.firstWhere(
      (plan) => plan.maxStudents == max,
      orElse: () => SubscriptionPlanType.basic5,
    );
  }
}

/// Subscription status
enum SubscriptionStatus {
  active,
  pending,
  expired,
  cancelled;
  
  String get displayName {
    switch (this) {
      case SubscriptionStatus.active:
        return 'Activa';
      case SubscriptionStatus.pending:
        return 'Pendiente';
      case SubscriptionStatus.expired:
        return 'Expirada';
      case SubscriptionStatus.cancelled:
        return 'Cancelada';
    }
  }
}

/// Subscription model for trainers
class SubscriptionModel {
  final String id;
  final String trainerId;
  final SubscriptionPlanType planType;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? nextPaymentDate;
  final String? mercadoPagoSubscriptionId;
  final DateTime createdAt;
  
  const SubscriptionModel({
    required this.id,
    required this.trainerId,
    required this.planType,
    required this.status,
    required this.startDate,
    this.endDate,
    this.nextPaymentDate,
    this.mercadoPagoSubscriptionId,
    required this.createdAt,
  });
  
  /// Check if subscription is valid
  bool get isValid => status == SubscriptionStatus.active;
  
  /// Get days until expiration
  int get daysRemaining {
    if (endDate == null) return 0;
    return endDate!.difference(DateTime.now()).inDays;
  }
  
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      id: json['id'] as String,
      trainerId: json['trainer_id'] as String,
      planType: SubscriptionPlanType.fromMaxStudents(json['max_students'] as int),
      status: SubscriptionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SubscriptionStatus.pending,
      ),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null 
          ? DateTime.parse(json['end_date'] as String) 
          : null,
      nextPaymentDate: json['next_payment_date'] != null 
          ? DateTime.parse(json['next_payment_date'] as String) 
          : null,
      mercadoPagoSubscriptionId: json['mercado_pago_subscription_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trainer_id': trainerId,
      'max_students': planType.maxStudents,
      'status': status.name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'next_payment_date': nextPaymentDate?.toIso8601String(),
      'mercado_pago_subscription_id': mercadoPagoSubscriptionId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
