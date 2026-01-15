import 'user_model.dart';
import 'subscription_model.dart';

/// Trainer model with subscription info
class TrainerModel {
  final String id;
  final UserModel user;
  final String? businessName;
  final String? phone;
  final String? bio;
  final SubscriptionModel? subscription;
  final int currentStudentCount;
  final DateTime createdAt;
  
  const TrainerModel({
    required this.id,
    required this.user,
    this.businessName,
    this.phone,
    this.bio,
    this.subscription,
    this.currentStudentCount = 0,
    required this.createdAt,
  });
  
  /// Check if trainer can add more students
  bool get canAddMoreStudents {
    if (subscription == null || !subscription!.isValid) return false;
    return currentStudentCount < subscription!.planType.maxStudents;
  }
  
  /// Get remaining student slots
  int get remainingStudentSlots {
    if (subscription == null) return 0;
    return subscription!.planType.maxStudents - currentStudentCount;
  }
  
  factory TrainerModel.fromJson(Map<String, dynamic> json, {SubscriptionModel? subscription}) {
    return TrainerModel(
      id: json['id'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      businessName: json['business_name'] as String?,
      phone: json['phone'] as String?,
      bio: json['bio'] as String?,
      subscription: subscription,
      currentStudentCount: json['current_student_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': user.id,
      'business_name': businessName,
      'phone': phone,
      'bio': bio,
      'current_student_count': currentStudentCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
