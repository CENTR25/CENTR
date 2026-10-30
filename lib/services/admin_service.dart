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
      'id, name, muscle_group, secondary_muscles, category, equipment, '
      'is_hidden, source, created_at';

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
    List<String>? secondaryMuscles,
    String? category,
    List<String>? equipment,
  }) async {
    final response = await _client
        .from('exercises')
        .insert({
          'name': name,
          'muscle_group': muscleGroup,
          if (secondaryMuscles != null && secondaryMuscles.isNotEmpty)
            'secondary_muscles': secondaryMuscles,
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
    List<String>? secondaryMuscles,
    String? category,
    List<String>? equipment,
  }) async {
    final updates = <String, dynamic>{
      'name': name,
      'muscle_group': muscleGroup,
      'category': (category != null && category.isNotEmpty) ? category : null,
      if (secondaryMuscles != null) 'secondary_muscles': secondaryMuscles,
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
    debugPrint('Subject: Invitación a PRGS');
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
    List<String>? features,
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

  /// Update an existing subscription plan.
  Future<void> updateSubscriptionPlan(
    String planId, {
    String? name,
    double? price,
    int? durationDays,
    int? maxStudents,
    List<String>? features,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (price != null) updates['price'] = price;
    if (durationDays != null) updates['duration_days'] = durationDays;
    if (maxStudents != null) updates['max_students'] = maxStudents;
    if (features != null) updates['features'] = features;
    if (updates.isEmpty) return;
    await _client.from('subscription_plans').update(updates).eq('id', planId);
  }

  /// Deactivate a plan (soft delete — hidden from new assignments).
  Future<void> deactivatePlan(String planId) async {
    await _client
        .from('subscription_plans')
        .update({'is_active': false})
        .eq('id', planId);
  }

  /// Active-trainer count per plan (for the Suscripciones list cards).
  Future<Map<String, int>> getPlanTrainerCounts() async {
    final nowIso = DateTime.now().toIso8601String();
    final subs = await _client
        .from('trainer_subscriptions')
        .select('plan_id')
        .eq('is_active', true)
        .gt('ends_at', nowIso);
    final counts = <String, int>{};
    for (final s in subs as List) {
      final pid = s['plan_id'] as String?;
      if (pid != null) counts[pid] = (counts[pid] ?? 0) + 1;
    }
    return counts;
  }

  /// Trainers currently on [planId] (active, unexpired) with alumnos count +
  /// renewal date, for the plan detail screen.
  Future<List<Map<String, dynamic>>> getTrainersByPlan(String planId) async {
    final nowIso = DateTime.now().toIso8601String();
    final subs = await _client
        .from('trainer_subscriptions')
        .select('trainer_id, ends_at, trainers(id, name, profile_photo)')
        .eq('plan_id', planId)
        .eq('is_active', true)
        .gt('ends_at', nowIso)
        .order('ends_at');
    final counts = await _alumnosCountByTrainer();
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final s in subs as List) {
      final trainer = s['trainers'] as Map<String, dynamic>?;
      final tid = trainer?['id'] as String?;
      if (tid == null || !seen.add(tid)) continue;
      out.add({
        'trainer_id': tid,
        'name': trainer?['name'],
        'profile_photo': trainer?['profile_photo'],
        'alumnos_count': counts[tid] ?? 0,
        'ends_at': s['ends_at'],
      });
    }
    return out;
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

  // ==================== DASHBOARD (Panel PRGS) ====================

  /// Columns needed to render a trainer row/detail — never select('*').
  static const _trainerColumns =
      'id, name, specialty, profile_photo, phone, user_id, created_at, '
      'profiles!inner(email, first_login_at, is_active, created_at)';

  /// Header metrics for the admin Inicio screen (single round-trip RPC).
  /// Returns {ingresos_mes, suscripciones_activas, total_trainers, total_alumnos}.
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    final res = await _client.rpc('admin_dashboard_metrics');
    return Map<String, dynamic>.from(res as Map);
  }

  /// All trainers enriched with their alumnos count and current active
  /// subscription (plan name/max/price + ends_at), for the Entrenadores list.
  /// `subscription` is null when the trainer has no active, unexpired plan.
  Future<List<Map<String, dynamic>>> getTrainersEnriched() async {
    final trainers = await _client
        .from('trainers')
        .select(_trainerColumns)
        .order('created_at', ascending: false);

    final counts = await _alumnosCountByTrainer();
    final subByTrainer = await _activeSubByTrainer();

    return List<Map<String, dynamic>>.from(trainers).map((t) {
      final id = t['id'] as String;
      return {
        ...t,
        'alumnos_count': counts[id] ?? 0,
        'subscription': subByTrainer[id],
      };
    }).toList();
  }

  /// Single trainer enriched for the detail screen.
  Future<Map<String, dynamic>> getTrainerDetail(String trainerId) async {
    final t = await _client
        .from('trainers')
        .select(_trainerColumns)
        .eq('id', trainerId)
        .single();

    final athletes = await _client
        .from('athletes')
        .select('id')
        .eq('trainer_id', trainerId);

    final nowIso = DateTime.now().toIso8601String();
    final subs = await _client
        .from('trainer_subscriptions')
        .select(
          'starts_at, ends_at, is_active, plan_id, '
          'subscription_plans(name, max_students, price)',
        )
        .eq('trainer_id', trainerId)
        .eq('is_active', true)
        .gt('ends_at', nowIso)
        .order('ends_at', ascending: false)
        .limit(1);

    return {
      ...t,
      'alumnos_count': (athletes as List).length,
      'subscription':
          subs.isNotEmpty ? Map<String, dynamic>.from(subs.first) : null,
    };
  }

  /// Trainers without an active, unexpired subscription (Pendientes bucket).
  Future<List<Map<String, dynamic>>> getTrainersWithoutSubscription() async {
    final trainers = await _client
        .from('trainers')
        .select('id, name, profile_photo')
        .order('created_at', ascending: false);
    final subByTrainer = await _activeSubByTrainer();
    return List<Map<String, dynamic>>.from(trainers)
        .where((t) => subByTrainer[t['id']] == null)
        .toList();
  }

  /// Active subscriptions expiring within [withinDays] (Pendientes bucket).
  Future<List<Map<String, dynamic>>> getExpiringSubscriptions({
    int withinDays = 7,
  }) async {
    final now = DateTime.now();
    final until = now.add(Duration(days: withinDays));
    final res = await _client
        .from('trainer_subscriptions')
        .select(
          'id, ends_at, trainer_id, trainers(name), subscription_plans(name)',
        )
        .eq('is_active', true)
        .gt('ends_at', now.toIso8601String())
        .lt('ends_at', until.toIso8601String())
        .order('ends_at');
    return List<Map<String, dynamic>>.from(res);
  }

  /// Pending (unused, unexpired) trainer invitations enriched with name/email.
  Future<List<Map<String, dynamic>>> getPendingInvitations() async {
    final nowIso = DateTime.now().toIso8601String();
    final rows = List<Map<String, dynamic>>.from(
      await _client
          .from('invitation_tokens')
          .select('user_id, expires_at, is_used, created_at')
          .eq('is_used', false)
          .gt('expires_at', nowIso)
          .order('created_at', ascending: false),
    );
    if (rows.isEmpty) return rows;

    final userIds = rows.map((r) => r['user_id'] as String).toList();
    final trainers = await _client
        .from('trainers')
        .select('user_id, name, profiles!inner(email)')
        .inFilter('user_id', userIds);
    final byUser = {
      for (final t in trainers) t['user_id'] as String: t,
    };
    return rows.map((r) {
      final t = byUser[r['user_id']];
      return {
        ...r,
        'name': t?['name'],
        'email': (t?['profiles'] as Map<String, dynamic>?)?['email'],
      };
    }).toList();
  }

  /// Regenerate an invitation token for a trainer who hasn't accepted yet and
  /// (placeholder) re-send the email. Returns the fresh invite link.
  Future<String> resendInvitation(String userId) async {
    final token = await _generateInvitationToken(userId);
    // Email send is still a placeholder (see _sendInvitationEmail); the token
    // is the real credential and is now refreshed with a new 7-day window.
    return '${AppConstants.firstLoginBaseUrl}?token=$token';
  }

  /// alumnos count grouped by trainer_id (one query, grouped client-side).
  Future<Map<String, int>> _alumnosCountByTrainer() async {
    final athletes = await _client.from('athletes').select('trainer_id');
    final counts = <String, int>{};
    for (final a in athletes as List) {
      final tid = a['trainer_id'] as String?;
      if (tid != null) counts[tid] = (counts[tid] ?? 0) + 1;
    }
    return counts;
  }

  /// Latest active, unexpired subscription per trainer (one query).
  Future<Map<String, Map<String, dynamic>>> _activeSubByTrainer() async {
    final nowIso = DateTime.now().toIso8601String();
    final subs = await _client
        .from('trainer_subscriptions')
        .select(
          'trainer_id, ends_at, is_active, '
          'subscription_plans(name, max_students, price)',
        )
        .eq('is_active', true)
        .gt('ends_at', nowIso)
        .order('ends_at', ascending: false);
    final byTrainer = <String, Map<String, dynamic>>{};
    for (final s in subs as List) {
      final tid = s['trainer_id'] as String?;
      if (tid == null) continue;
      byTrainer.putIfAbsent(tid, () => Map<String, dynamic>.from(s));
    }
    return byTrainer;
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

/// Header metrics for the admin Inicio screen.
final adminDashboardMetricsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getDashboardMetrics();
});

/// Enriched trainer list (alumnos count + active subscription) for Entrenadores.
final adminTrainersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getTrainersEnriched();
});

/// Single enriched trainer for the detail screen.
final adminTrainerDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, trainerId) async {
  final service = ref.watch(adminServiceProvider);
  return service.getTrainerDetail(trainerId);
});

/// The three "Pendientes" buckets for the admin Inicio screen.
typedef AdminPendientes = ({
  List<Map<String, dynamic>> withoutSubscription,
  List<Map<String, dynamic>> expiring,
  List<Map<String, dynamic>> invitations,
});

final adminPendientesProvider = FutureProvider<AdminPendientes>((ref) async {
  final service = ref.watch(adminServiceProvider);
  final results = await Future.wait([
    service.getTrainersWithoutSubscription(),
    service.getExpiringSubscriptions(),
    service.getPendingInvitations(),
  ]);
  return (
    withoutSubscription: results[0],
    expiring: results[1],
    invitations: results[2],
  );
});

/// Active-trainer count per plan for the Suscripciones list.
final planTrainerCountsProvider =
    FutureProvider<Map<String, int>>((ref) async {
  final service = ref.watch(adminServiceProvider);
  return service.getPlanTrainerCounts();
});

/// Trainers on a given plan for the plan detail screen.
final trainersByPlanProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, planId) async {
  final service = ref.watch(adminServiceProvider);
  return service.getTrainersByPlan(planId);
});
