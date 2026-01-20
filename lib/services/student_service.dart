import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:north_star/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

/// Service for student-specific operations
class StudentService {
  final SupabaseClient _client;

  StudentService(this._client);

  String? get currentUserId => _client.auth.currentUser?.id;

  /// Get athlete_id for current user
  Future<String?> _getAthleteId() async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('🔴 _getAthleteId: No userId');
      return null;
    }
    
    debugPrint('🔍 _getAthleteId: Looking for athlete with user_id: $userId');
    
    final athlete = await _client
        .from('athletes')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    
    debugPrint('🔍 _getAthleteId: Result: $athlete');
    
    return athlete?['id'] as String?;
  }

  /// Get active meal plan for current student
  Future<Map<String, dynamic>?> getMyActiveMealPlan() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return null;

    // Get active assignment
    final assignment = await _client
        .from('athlete_meal_plans')
        .select('meal_plan_id')
        .eq('athlete_id', athleteId)
        .eq('is_active', true)
        .maybeSingle();

    if (assignment == null) return null;

    final mealPlanId = assignment['meal_plan_id'];

    // Get full meal plan details
    final response = await _client
        .from('meal_plans')
        .select('*, meal_plan_items(*)')
        .eq('id', mealPlanId)
        .maybeSingle();

    return response;
  }

  /// Get active routine for current student
  Future<Map<String, dynamic>?> getMyActiveRoutine() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return null;

    final assignment = await _client
        .from('athlete_routines')
        .select('routine_id')
        .eq('athlete_id', athleteId)
        .eq('is_active', true)
        .maybeSingle();

    if (assignment == null) return null;

    final routineId = assignment['routine_id'];

    // Get full routine details
    final response = await _client
        .from('routines')
        .select('*, routine_exercises(*, exercises(*))')
        .eq('id', routineId)
        .maybeSingle();

    return response;
  }
  /// Complete onboarding: update profile with metrics and goal
  Future<void> completeOnboarding({
    required double weight,
    required double height,
    String? goal,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    // Update profiles table with all onboarding data
    await _client.from('profiles').update({
      'has_completed_onboarding': true,
      'current_weight': weight,
      'current_height': height,
      if (goal != null) 'goal': goal,
    }).eq('id', userId);
  }

  /// Log weight and height (updates profiles table)
  Future<void> logMetrics({double? weight, double? height}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    final updateData = <String, dynamic>{};
    if (weight != null) updateData['current_weight'] = weight;
    if (height != null) updateData['current_height'] = height;
    
    if (updateData.isNotEmpty) {
      await _client.from('profiles').update(updateData).eq('id', userId);
    }
  }


  /// Update profile info
  Future<void> updateProfile({String? name, String? avatarUrl}) async {
     final userId = currentUserId;
    if (userId == null) return;
    
    await _client.from('profiles').update({
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', userId);
  }

  /// Perform a check-in
  Future<void> performCheckIn({
    required File photo,
    String? comment,
    required StorageService storageService,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');

    // Upload photo
    final photoUrl = await storageService.uploadCheckInPhoto(photo, userId);

    // Insert Check-in
    await _client.from('check_ins').insert({
      'user_id': userId, // or athlete_id depending on schema
      'photo_url': photoUrl,
      'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // Update Streak (optional, logic might be server-side triggers)
  }
}

/// Provider for StudentService
final studentServiceProvider = Provider<StudentService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StudentService(client);
});

final activeMealPlanProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getMyActiveMealPlan();
});

/// Provider for student's active routine
final activeRoutineProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getMyActiveRoutine();
});
