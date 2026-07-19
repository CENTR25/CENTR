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
    switch (value.trim().toLowerCase()) {
      case 'admin':
      case 'administrator':
      case 'administrador':
        return UserRole.admin;
      case 'trainer':
      case 'coach':
      case 'entrenador':
        return UserRole.trainer;
      case 'student':
      case 'athlete':
      case 'alumno':
      case 'atleta':
        return UserRole.student;
      default:
        return UserRole.student;
    }
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

  /// Name shown in the interface, with a safe fallback for legacy profiles.
  String get displayName =>
      name?.trim().isNotEmpty == true ? name!.trim() : email.split('@').first;

  static String? resolveName(Map<String, dynamic> json) {
    final metadata = json['user_metadata'];
    final metadataMap = metadata is Map
        ? Map<String, dynamic>.from(metadata)
        : const <String, dynamic>{};

    String? firstNonEmpty(Iterable<Object?> values) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final directName = firstNonEmpty([
      json['name'],
      json['full_name'],
      json['display_name'],
      json['preferred_name'],
      metadataMap['name'],
      metadataMap['full_name'],
      metadataMap['display_name'],
    ]);
    if (directName != null) return directName;

    final firstName = firstNonEmpty([
      json['first_name'],
      metadataMap['first_name'],
    ]);
    final lastName = firstNonEmpty([
      json['last_name'],
      metadataMap['last_name'],
    ]);
    final combinedName = [
      firstName,
      lastName,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' ').trim();

    return combinedName.isEmpty ? null : combinedName;
  }

  static DateTime _parseDate(Object? value) {
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final email = (json['email'] as String?)?.trim() ?? '';
    final resolvedName =
        resolveName(json) ??
        (email.contains('@') ? email.split('@').first : null);

    return UserModel(
      id: json['id'] as String,
      email: email,
      name: resolvedName,
      avatarUrl:
          (json['avatar_url'] as String?) ?? (json['photo_url'] as String?),
      role: UserRole.fromString(json['role'] as String? ?? 'student'),
      trainerId: json['trainer_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      hasCompletedOnboarding:
          json['has_completed_onboarding'] as bool? ?? false,
      createdAt: _parseDate(json['created_at']),
      lastLoginAt: json['last_login_at'] != null
          ? _parseDate(json['last_login_at'])
          : null,
      firstLoginAt: json['first_login_at'] != null
          ? _parseDate(json['first_login_at'])
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
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      firstLoginAt: firstLoginAt ?? this.firstLoginAt,
    );
  }
}
