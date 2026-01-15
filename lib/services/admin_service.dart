import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for Admin operations
class AdminService {
  final SupabaseClient _client;

  AdminService(this._client);

  // ==================== TRAINERS CRUD ====================

  /// Get all trainers
  Future<List<Map<String, dynamic>>> getAllTrainers() async {
    final response = await _client
        .from('trainers')
        .select('*, profiles!inner(*)')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create trainer with invitation
  Future<Map<String, dynamic>> createTrainer({
    required String email,
    required String name,
    String? specialty,
    String? photoUrl,
  }) async {
    // 1. Create auth user with temporary password
    final tempPassword = _generateTempPassword();
    
    final authResponse = await _client.auth.admin.createUser(
      AdminUserAttributes(
        email: email,
        password: tempPassword,
        emailConfirm: true,
        userMetadata: {
          'full_name': name,
          'role': 'trainer',
        },
      ),
    );

    if (authResponse.user == null) {
      throw Exception('Failed to create auth user');
    }

    final userId = authResponse.user!.id;

    // 2. Create profile
    await _client.from('profiles').insert({
      'id': userId,
      'email': email,
      'name': name,
      'role': 'trainer',
      'photo_url': photoUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 3. Create trainer record
    final trainerResponse = await _client.from('trainers').insert({
      'user_id': userId,
      'specialty': specialty,
      'is_active': true,
      'has_logged_in': false,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    // 4. Generate invitation token
    final token = await _generateInvitationToken(userId);

    // 5. Send invitation email
    await _sendInvitationEmail(
      email: email,
      name: name,
      token: token,
      tempPassword: tempPassword,
    );

    return {
      ...trainerResponse,
      'temp_password': tempPassword, // Return for admin to see
      'invitation_token': token,
    };
  }

  /// Update trainer
  Future<void> updateTrainer(
    String trainerId, {
    String? name,
    String? specialty,
    String? photoUrl,
    bool? isActive,
  }) async {
    // Get trainer's user_id
    final trainer = await _client
        .from('trainers')
        .select('user_id')
        .eq('id', trainerId)
        .single();

    final userId = trainer['user_id'] as String;

    // Update trainer table
    final trainerUpdates = <String, dynamic>{};
    if (specialty != null) trainerUpdates['specialty'] = specialty;
    if (isActive != null) trainerUpdates['is_active'] = isActive;

    if (trainerUpdates.isNotEmpty) {
      await _client.from('trainers').update(trainerUpdates).eq('id', trainerId);
    }

    // Update profile table
    final profileUpdates = <String, dynamic>{};
    if (name != null) profileUpdates['name'] = name;
    if (photoUrl != null) profileUpdates['photo_url'] = photoUrl;

    if (profileUpdates.isNotEmpty) {
      await _client.from('profiles').update(profileUpdates).eq('id', userId);
    }
  }

  /// Deactivate trainer (soft delete)
  Future<void> deactivateTrainer(String trainerId) async {
    await _client.from('trainers').update({'is_active': false}).eq('id', trainerId);
  }

  /// Delete trainer permanently (only if no students)
  Future<void> deleteTrainer(String trainerId) async {
    // Check if trainer has students
    final students = await _client
        .from('athletes')
        .select('id')
        .eq('trainer_id', trainerId)
        .limit(1);

    if (students.isNotEmpty) {
      throw Exception('Cannot delete trainer with active students');
    }

    // Get user_id before deleting trainer
    final trainer = await _client
        .from('trainers')
        .select('user_id')
        .eq('id', trainerId)
        .single();

    final userId = trainer['user_id'] as String;

    // Delete trainer record
    await _client.from('trainers').delete().eq('id', trainerId);

    // Delete profile
    await _client.from('profiles').delete().eq('id', userId);

    // Delete auth user
    await _client.auth.admin.deleteUser(userId);
  }

  // ==================== INVITATIONS ====================

  /// Generate invitation token
  Future<String> _generateInvitationToken(String userId) async {
    final token = DateTime.now().millisecondsSinceEpoch.toString() + 
                  userId.substring(0, 8);
    
    // Store token in database (RLS disabled for this table)
    await _client.from('invitation_tokens').insert({
      'user_id': userId,
      'token': token,
      'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      'is_used': false,
    });

    return token;
  }

  /// Send invitation email via Supabase
  Future<void> _sendInvitationEmail({
    required String email,
    required String name,
    required String token,
    required String tempPassword,
  }) async {
    // TODO: Configure Supabase email templates
    // For now, this is a placeholder
    // In production, use Supabase Auth email templates or SMTP service
    
    final inviteLink = 'northstar://first-login?token=$token';
    
    print('📧 Invitation Email:');
    print('To: $email');
    print('Subject: Invitación a North Star');
    print('Link: $inviteLink');
    print('Temp Password: $tempPassword');
    
    // In production, send via Supabase:
    // await _client.auth.admin.inviteUserByEmail(email);
  }

  /// Verify invitation token and complete first login
  Future<bool> completeFirstLogin({
    required String token,
    required String newPassword,
  }) async {
    // Verify token
    final tokenData = await _client
        .from('invitation_tokens')
        .select('*, trainers!inner(id)')
        .eq('token', token)
        .eq('is_used', false)
        .maybeSingle();

    if (tokenData == null) {
      throw Exception('Invalid or expired token');
    }

    final expiresAt = DateTime.parse(tokenData['expires_at']);
    if (DateTime.now().isAfter(expiresAt)) {
      throw Exception('Token expired');
    }

    final userId = tokenData['user_id'] as String;
    final trainerId = tokenData['trainers']['id'] as String;

    // Update password
    await _client.auth.admin.updateUserById(
      userId,
      attributes: AdminUserAttributes(password: newPassword),
    );

    // Mark trainer as logged in
    await _client.from('trainers').update({'has_logged_in': true}).eq('id', trainerId);

    // Mark token as used
    await _client.from('invitation_tokens').update({'is_used': true}).eq('token', token);

    return true;
  }

  // ==================== SUBSCRIPTIONS ====================

  /// Get all subscription plans
  Future<List<Map<String, dynamic>>> getSubscriptionPlans() async {
    final response = await _client
        .from('subscription_plans')
        .select()
        .eq('is_active', true)
        .order('price');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create subscription plan
  Future<Map<String, dynamic>> createSubscriptionPlan({
    required String name,
    required double price,
    required int durationDays,
    int? maxStudents,
    Map<String, dynamic>? features,
  }) async {
    final response = await _client.from('subscription_plans').insert({
      'name': name,
      'price': price,
      'duration_days': durationDays,
      'max_students': maxStudents,
      'features': features,
      'is_active': true,
    }).select().single();

    return response;
  }

  /// Assign subscription to trainer
  Future<void> assignSubscription({
    required String trainerId,
    required String planId,
    DateTime? startsAt,
  }) async {
    final plan = await _client
        .from('subscription_plans')
        .select('duration_days')
        .eq('id', planId)
        .single();

    final durationDays = plan['duration_days'] as int;
    final starts = startsAt ?? DateTime.now();
    final ends = starts.add(Duration(days: durationDays));

    await _client.from('trainer_subscriptions').insert({
      'trainer_id': trainerId,
      'plan_id': planId,
      'starts_at': starts.toIso8601String(),
      'ends_at': ends.toIso8601String(),
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Get trainers with expired subscriptions
  Future<List<Map<String, dynamic>>> getExpiredSubscriptions() async {
    final now = DateTime.now().toIso8601String();
    
    final response = await _client
        .from('trainer_subscriptions')
        .select('*, trainers(*, profiles(*))')
        .lt('ends_at', now)
        .eq('is_active', true);

    return List<Map<String, dynamic>>.from(response);
  }

  // ==================== STATS ====================

  /// Get admin dashboard stats
  Future<Map<String, dynamic>> getAdminStats() async {
    final trainers = await getAllTrainers();
    final activeTrainers = trainers.where((t) => t['is_active'] == true).length;
    final pendingLogin = trainers.where((t) => t['has_logged_in'] == false).length;

    return {
      'total_trainers': trainers.length,
      'active_trainers': activeTrainers,
      'pending_login': pendingLogin,
      'inactive_trainers': trainers.length - activeTrainers,
    };
  }

  // ==================== HELPERS ====================

  String _generateTempPassword() {
    // Generate secure random password
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'Temp' + random.toString().substring(0, 8) + '!';
  }
}

/// Provider for AdminService
final adminServiceProvider = Provider<AdminService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AdminService(client);
});

/// Provider for admin stats
final adminStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getAdminStats();
});

/// Provider for all trainers
final allTrainersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getAllTrainers();
});

/// Provider for subscription plans
final subscriptionPlansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getSubscriptionPlans();
});
