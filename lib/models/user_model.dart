/// User roles in the app
enum UserRole {
  admin,
  trainer,
  student;
  
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.trainer:
        return 'Entrenador';
      case UserRole.student:
        return 'Alumno';
    }
  }
  
  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value.toLowerCase(),
      orElse: () => UserRole.student,
    );
  }
}

/// User model
class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final UserRole role;
  final String? trainerId; // Only for students - their assigned trainer
  final bool isActive;
  final bool hasCompletedOnboarding;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final DateTime? firstLoginAt;
  
  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.role,
    this.trainerId,
    this.isActive = true,
    this.hasCompletedOnboarding = false,
    required this.createdAt,
    this.lastLoginAt,
    this.firstLoginAt,
  });
  
  /// Check if this is the user's first login
  bool get isFirstLogin => firstLoginAt == null;
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: UserRole.fromString(json['role'] as String? ?? 'student'),
      trainerId: json['trainer_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      hasCompletedOnboarding: json['has_completed_onboarding'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastLoginAt: json['last_login_at'] != null 
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      firstLoginAt: json['first_login_at'] != null 
          ? DateTime.parse(json['first_login_at'] as String)
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'avatar_url': avatarUrl,
      'role': role.name,
      'trainer_id': trainerId,
      'is_active': isActive,
      'has_completed_onboarding': hasCompletedOnboarding,
      'created_at': createdAt.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
      'first_login_at': firstLoginAt?.toIso8601String(),
    };
  }
  
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? avatarUrl,
    UserRole? role,
    String? trainerId,
    bool? isActive,
    bool? hasCompletedOnboarding,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    DateTime? firstLoginAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      trainerId: trainerId ?? this.trainerId,
      isActive: isActive ?? this.isActive,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      firstLoginAt: firstLoginAt ?? this.firstLoginAt,
    );
  }
}
