import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';
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
    // 1. Create auth user via the admin-auth Edge Function — the service
    //    role key lives server-side; auth.admin.* cannot run on the client.
    final created = await _invokeAdminAuth({
      'action': 'create_trainer',
      'email': email,
      'name': name,
    });

    final userId = created['user_id'] as String;
    final tempPassword = created['temp_password'] as String;

    // 2. Create profile
    await _client.from('profiles').insert({
      'id': userId,
      'email': email,
      'role': 'trainer',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 3. Create trainer record (name/photo live on trainers, not profiles)
    final trainerResponse = await _client.from('trainers').insert({
      'user_id': userId,
      'name': name,
      'specialty': specialty,
      'profile_photo': photoUrl,
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

    // Update trainer table (name/photo live on trainers, not profiles)
    final trainerUpdates = <String, dynamic>{};
    if (name != null) trainerUpdates['name'] = name;
    if (specialty != null) trainerUpdates['specialty'] = specialty;
    if (photoUrl != null) trainerUpdates['profile_photo'] = photoUrl;

    if (trainerUpdates.isNotEmpty) {
      await _client.from('trainers').update(trainerUpdates).eq('id', trainerId);
    }

    // Update profile table
    final profileUpdates = <String, dynamic>{};
    if (isActive != null) profileUpdates['is_active'] = isActive;

    if (profileUpdates.isNotEmpty) {
      await _client.from('profiles').update(profileUpdates).eq('id', userId);
    }
  }

  /// Deactivate trainer (soft delete) — active flag lives on profiles
  Future<void> deactivateTrainer(String trainerId) async {
    final trainer = await _client
        .from('trainers')
        .select('user_id')
        .eq('id', trainerId)
        .single();
    await _client
        .from('profiles')
        .update({'is_active': false})
        .eq('id', trainer['user_id'] as String);
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

    // Delete auth user (server-side, service role)
    await _invokeAdminAuth({'action': 'delete_user', 'user_id': userId});
  }

  // ==================== GLOBAL EXERCISES ====================

  /// Columns needed for the admin exercise list — never select('*').
  static const _exerciseColumns =
      'id, name, muscle_group, category, equipment, is_hidden, source, created_at';

  /// Global exercises (created_by_trainer IS NULL): seed + admin-created.
  /// Admins see hidden rows too (RLS). Ordered by name.
  Future<List<Map<String, dynamic>>> getGlobalExercises() async {
    final response = await _client
        .from('exercises')
        .select(_exerciseColumns)
        .isFilter('created_by_trainer', null)
        .order('name');

    return List<Map<String, dynamic>>.from(response);
  }

  /// Create a new global exercise visible to every trainer/athlete.
  Future<Map<String, dynamic>> createGlobalExercise({
    required String name,
    required String muscleGroup,
    String? category,
    List<String>? equipment,
  }) async {
    final response = await _client
        .from('exercises')
        .insert({
          'name': name,
          'muscle_group': muscleGroup,
          if (category != null && category.isNotEmpty) 'category': category,
          if (equipment != null && equipment.isNotEmpty) 'equipment': equipment,
          'created_by_trainer': null,
          'is_public': true,
          'is_hidden': false,
          'source': 'global',
          'created_at': DateTime.now().toIso8601String(),
        })
        .select(_exerciseColumns)
        .single();

    return response;
  }

  /// Hide or unhide a global exercise.
  Future<void> setGlobalExerciseHidden(String exerciseId, bool hidden) async {
    await _client
        .from('exercises')
        .update({'is_hidden': hidden})
        .eq('id', exerciseId);
  }

  /// Update the editable fields of a global exercise.
  Future<void> updateGlobalExercise(
    String exerciseId, {
    required String name,
    required String muscleGroup,
    String? category,
    List<String>? equipment,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'muscle_group': muscleGroup,
      'category': (category != null && category.isNotEmpty) ? category : null,
      if (equipment != null) 'equipment': equipment,
    };
    await _client.from('exercises').update(updates).eq('id', exerciseId);
  }

  /// Permanently delete a global exercise. RLS restricts this to admin.
  Future<void> deleteGlobalExercise(String exerciseId) async {
    await _client.from('exercises').delete().eq('id', exerciseId);
  }

  // ==================== INVITATIONS ====================

  /// Generate invitation token (cryptographically random — it is the sole
  /// credential for setting the trainer's password on first login)
  Future<String> _generateInvitationToken(String userId) async {
    final rand = Random.secure();
    final token = List.generate(
      32,
      (_) => rand.nextInt(16).toRadixString(16),
    ).join();

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
    
    final inviteLink = '${AppConstants.firstLoginBaseUrl}?token=$token';
    
    debugPrint('📧 Invitation Email:');
    debugPrint('To: $email');
    debugPrint('Subject: Invitación a CENTR');
    debugPrint('Link: $inviteLink');
    debugPrint('Temp Password: $tempPassword');
    
    // In production, send via Supabase:
    // await _client.auth.admin.inviteUserByEmail(email);
  }

  /// Verify invitation token and complete first login.
  /// Runs entirely in the admin-auth Edge Function: the caller is not
  /// authenticated yet (the token is the credential) and both the token
  /// lookup (admin-only RLS) and the password update need the service role.
  Future<bool> completeFirstLogin({
    required String token,
    required String newPassword,
  }) async {
    await _invokeAdminAuth({
      'action': 'complete_first_login',
      'token': token,
      'new_password': newPassword,
    });
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
    final activeTrainers = trainers
        .where((t) => t['profiles']?['is_active'] == true)
        .length;
    final pendingLogin = trainers
        .where((t) => t['profiles']?['first_login_at'] == null)
        .length;

    return {
      'total_trainers': trainers.length,
      'active_trainers': activeTrainers,
      'pending_login': pendingLogin,
      'inactive_trainers': trainers.length - activeTrainers,
    };
  }

  // ==================== HELPERS ====================

  /// Calls the admin-auth Edge Function and unwraps its error payload.
  Future<Map<String, dynamic>> _invokeAdminAuth(
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await _client.functions.invoke('admin-auth', body: body);
      return Map<String, dynamic>.from(res.data as Map);
    } on FunctionException catch (e) {
      final details = e.details;
      final message = details is Map ? details['error']?.toString() : null;
      throw Exception(message ?? 'Operación fallida (${e.status})');
    }
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

/// Provider for subscription plans
final subscriptionPlansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getSubscriptionPlans();
});

/// Provider for global exercises (admin management)
final globalExercisesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getGlobalExercises();
});
