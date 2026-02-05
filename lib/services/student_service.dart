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

  /// Get streak for current student
  Future<Map<String, dynamic>?> getMyStreak() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return null;

    final response = await _client
        .from('streaks')
        .select()
        .eq('athlete_id', athleteId)
        .maybeSingle();

    if (response == null) return {'current_streak': 0, 'last_workout_date': null};

    // Live calculation to check if streak is still valid
    final lastWorkoutStr = response['last_workout_date'] as String?;
    if (lastWorkoutStr == null) return response;

    final lastWorkoutDate = DateTime.parse(lastWorkoutStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(lastWorkoutDate.year, lastWorkoutDate.month, lastWorkoutDate.day);

    if (workoutDate.isBefore(yesterday) && workoutDate != today) {
      // Streak lost in real-time display
      return {
        ...response,
        'current_streak': 0,
      };
    }

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
    
    // We also count check-ins as activity for streaks
    final athleteId = await _getAthleteId();
    if (athleteId != null) {
      await _updateStreak(athleteId);
    }
  }

  /// Internal method to update streak
  Future<void> _updateStreak(String athleteId) async {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T')[0];
    
    // 1. Get current streak record
    final currentRecord = await _client
        .from('streaks')
        .select()
        .eq('athlete_id', athleteId)
        .maybeSingle();
    
    int newStreak = 1;
    
    if (currentRecord != null) {
      final lastWorkoutStr = currentRecord['last_workout_date'] as String?;
      if (lastWorkoutStr == todayStr) {
        // Already updated today
        return;
      }
      
      if (lastWorkoutStr != null) {
        final lastWorkoutDate = DateTime.parse(lastWorkoutStr);
        final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        final workoutDay = DateTime(lastWorkoutDate.year, lastWorkoutDate.month, lastWorkoutDate.day);
        
        if (workoutDay == yesterday) {
          // Continuous streak
          newStreak = (currentRecord['current_streak'] as int? ?? 0) + 1;
        } else {
          // Skipped one or more days, start over
          newStreak = 1;
        }
      }
    }
    
    // 2. Upsert
    await _client.from('streaks').upsert({
      'athlete_id': athleteId,
      'current_streak': newStreak,
      'last_workout_date': todayStr,
      'updated_at': now.toIso8601String(),
    }, onConflict: 'athlete_id');
    
    debugPrint('🔥 Streak updated for $athleteId: $newStreak (last: $todayStr)');
  }

  /// Save workout session log
  Future<void> saveWorkoutSession(Map<String, dynamic> logData) async {
    debugPrint('📊 Saving workout session log: $logData');
    
    try {
      await _client.from('workout_sessions').insert({
        'athlete_id': await _getAthleteId(),
        'routine_id': logData['routine_id'],
        'day_number': logData['day_number'],
        'started_at': logData['started_at'],
        'duration_seconds': logData['duration_seconds'],
        'sets_completed': logData['sets_completed'],
        'is_completed': logData['is_completed'],
        'set_logs': logData['set_logs'], // Stores the recorded weights per exercise/set
        'reps_logs': logData['reps_logs'], // Stores the recorded reps per exercise/set
      });
      debugPrint('✅ Workout session log saved successfully');
      
      // Update Streak on successful completion
      if (logData['is_completed'] == true) {
        final athleteId = await _getAthleteId();
        if (athleteId != null) {
          await _updateStreak(athleteId);
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving workout session: $e');
      // Rethrow if needed, or handle gracefully
    }
  }

  /// Get the last completed workout session for a routine, specific to a day
  Future<Map<String, dynamic>?> getLastWorkoutSession(String routineId, int dayNumber) async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return null;

    final response = await _client
        .from('workout_sessions')
        .select()
        .eq('athlete_id', athleteId)
        .eq('routine_id', routineId)
        .eq('day_number', dayNumber)
        .eq('is_completed', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response;
  }

  // ==================== SUPPLEMENTS ====================

  /// Get my assigned supplements (configuration)
  Future<Map<String, String>> getMySupplements() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return {'daily': '', 'chemical': ''};

    final response = await _client
        .from('athletes')
        .select('daily_supplements, chemical_supplements')
        .eq('id', athleteId)
        .maybeSingle();
    
    if (response == null) return {'daily': '', 'chemical': ''};

    return {
      'daily': response['daily_supplements'] as String? ?? '',
      'chemical': response['chemical_supplements'] as String? ?? '',
    };
  }

  /// Get my cardio configuration
  Future<Map<String, dynamic>> getMyCardio() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return {'description': '', 'days': <int>[]};

    final response = await _client
        .from('athletes')
        .select('cardio_description, cardio_days')
        .eq('id', athleteId)
        .maybeSingle();
    
    if (response == null) return {'description': '', 'days': <int>[]};

    List<int> days = [];
    if (response['cardio_days'] != null) {
      days = List<int>.from(response['cardio_days'] as List);
    }

    return {
      'description': response['cardio_description'] as String? ?? '',
      'days': days,
    };
  }

  /// Get today's supplement log to check status
  Future<Map<String, dynamic>?> getTodaySupplementLog() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return null;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final response = await _client
        .from('supplement_logs')
        .select()
        .eq('athlete_id', athleteId)
        .eq('date', todayStr)
        .maybeSingle();
    
    return response;
  }

  /// Log or toggle supplement intake for today
  Future<void> logSupplementIntake({bool? dailyTaken, bool? chemicalTaken}) async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Upsert needs key columns to match uniqueness constraint (athlete_id, date)
    final data = <String, dynamic>{
      'athlete_id': athleteId,
      'date': todayStr,
      if (dailyTaken != null) 'daily_taken': dailyTaken,
      if (chemicalTaken != null) 'chemical_taken': chemicalTaken,
    };

    // We use upsert to handle both insert (first check of day) and update (toggling)
    await _client.from('supplement_logs').upsert(data, onConflict: 'athlete_id, date');
  }

  /// Log detailed ticked items for supplements
  Future<void> logSupplements({required List<String> tickedItems}) async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final data = <String, dynamic>{
      'athlete_id': athleteId,
      'date': todayStr,
      'ticked_items': tickedItems,
    };

    await _client.from('supplement_logs').upsert(data, onConflict: 'athlete_id, date');
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

/// Provider for student's streak
final streakProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getMyStreak();
});

/// Provider for student's supplements configuration
final mySupplementsProvider = FutureProvider<Map<String, String>>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getMySupplements();
});

/// Provider for student's cardio configuration
final myCardioProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getMyCardio();
});

/// Provider for today's supplement log (Status)
final todaySupplementLogProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getTodaySupplementLog();
});

/// Provider for last workout session for a specific day
final lastSessionProvider = FutureProvider.family<Map<String, dynamic>?, ({String routineId, int dayNumber})>((ref, arg) async {
  final service = ref.read(studentServiceProvider);
  return service.getLastWorkoutSession(arg.routineId, arg.dayNumber);
});
