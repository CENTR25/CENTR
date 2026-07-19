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

  /// Get the active check-in form assigned by the student's trainer.
  ///
  /// The student-to-trainer relationship is stored in `athletes.trainer_id`
  /// and points to `trainers.id`. Check-in forms, however, are owned by the
  /// trainer's profile/auth user (`check_in_forms.trainer_id` references
  /// `profiles.id`). Keep that distinction here so the UI does not query a
  /// column that does not exist on `profiles`.
  Future<Map<String, dynamic>?> getActiveCoachCheckInForm() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final athlete = await _client
        .from('athletes')
        .select('trainer_id')
        .eq('user_id', userId)
        .maybeSingle();

    final trainerRecordId = athlete?['trainer_id'] as String?;
    if (trainerRecordId == null) return null;

    // In the current schema athletes.trainer_id is trainers.id. Resolve the
    // trainer's auth/profile id before reading check_in_forms.
    final trainer = await _client
        .from('trainers')
        .select('user_id')
        .eq('id', trainerRecordId)
        .maybeSingle();
    final trainerUserId = trainer?['user_id'] as String? ?? trainerRecordId;

    return _client
        .from('check_in_forms')
        .select()
        .eq('trainer_id', trainerUserId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
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

    if (response == null)
      return {'current_streak': 0, 'last_workout_date': null};

    // Live calculation to check if streak is still valid
    final lastWorkoutStr = response['last_workout_date'] as String?;
    if (lastWorkoutStr == null) return response;

    final lastWorkoutDate = DateTime.parse(lastWorkoutStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final workoutDate = DateTime(
      lastWorkoutDate.year,
      lastWorkoutDate.month,
      lastWorkoutDate.day,
    );

    if (workoutDate.isBefore(yesterday) && workoutDate != today) {
      // Streak lost in real-time display
      return {...response, 'current_streak': 0};
    }

    return response;
  }

  /// Get active routine for current student
  Future<Map<String, dynamic>?> getMyActiveRoutine() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return null;

    final now = DateTime.now();
    final assignments = await _client
        .from('athlete_routines')
        .select('routine_id, start_date, end_date')
        .eq('athlete_id', athleteId)
        .eq('is_active', true)
        .lte('start_date', now.toIso8601String())
        .order('start_date', ascending: false)
        .limit(20);

    // Use the newest assignment that has not expired. The limit/order makes
    // old duplicate rows harmless while the date check prevents future plans
    // from replacing the currently applicable routine.
    final assignment = assignments.cast<Map<String, dynamic>>().firstWhere((
      candidate,
    ) {
      final endDate = DateTime.tryParse(
        candidate['end_date']?.toString() ?? '',
      );
      return endDate == null || !endDate.isBefore(now);
    }, orElse: () => <String, dynamic>{});

    if (assignment.isEmpty) return null;

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
    await _client
        .from('profiles')
        .update({
          'has_completed_onboarding': true,
          'current_weight': weight,
          'current_height': height,
          if (goal != null) 'goal': goal,
        })
        .eq('id', userId);
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

    await _client
        .from('profiles')
        .update({
          if (name != null) 'name': name,
          if (avatarUrl != null) 'avatar_url': avatarUrl,
        })
        .eq('id', userId);
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
      'photo_urls': [photoUrl],
      'comment': comment,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Update athletes.last_check_in_at
    final athleteId = await _getAthleteId();
    if (athleteId != null) {
      await _client
          .from('athletes')
          .update({'last_check_in_at': DateTime.now().toIso8601String()})
          .eq('id', athleteId);
      await _updateStreak(athleteId);
    }
  }

  /// Perform a check-in with multiple photos and optional form responses
  Future<void> performMultiCheckIn({
    required List<File> photos,
    String? comment,
    required StorageService storageService,
    String? formId,
    Map<String, dynamic>? formResponses,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');
    if (photos.isEmpty) throw Exception('Se requiere al menos una foto');

    // Upload all photos
    final photoUrls = <String>[];
    for (final photo in photos) {
      final url = await storageService.uploadCheckInPhoto(photo, userId);
      photoUrls.add(url);
    }

    final athleteId = await _getAthleteId();
    final now = DateTime.now().toIso8601String();

    // Insert check-in with all photos
    final checkInRow = await _client
        .from('check_ins')
        .insert({
          'user_id': userId,
          'photo_url': photoUrls.first, // retrocompat
          'photo_urls': photoUrls,
          'comment': comment,
          'created_at': now,
        })
        .select()
        .single();

    // Update athletes.last_check_in_at
    if (athleteId != null) {
      await _client
          .from('athletes')
          .update({'last_check_in_at': now})
          .eq('id', athleteId);
      await _updateStreak(athleteId);
    }

    // Save form responses if provided
    if (formId != null && formResponses != null && formResponses.isNotEmpty) {
      await _client.from('check_in_form_responses').insert({
        'check_in_id': checkInRow['id'],
        'athlete_id': athleteId,
        'form_id': formId,
        'responses': formResponses,
        'created_at': now,
      });
    }
  }

  /// Perform a check-in with pre-uploaded photo URLs (web-compatible)
  Future<void> performCheckInFromUrls({
    required List<String> photoUrls,
    String? comment,
    String? formId,
    Map<String, dynamic>? formResponses,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('No user logged in');
    if (photoUrls.isEmpty) throw Exception('Se requiere al menos una foto');

    final athleteId = await _getAthleteId();
    final now = DateTime.now().toIso8601String();

    final checkInRow = await _client
        .from('check_ins')
        .insert({
          'user_id': userId,
          'photo_url': photoUrls.first,
          'photo_urls': photoUrls,
          'comment': comment,
          'created_at': now,
        })
        .select()
        .single();

    if (athleteId != null) {
      await _client
          .from('athletes')
          .update({'last_check_in_at': now})
          .eq('id', athleteId);
      await _updateStreak(athleteId);
    }

    if (formId != null && formResponses != null && formResponses.isNotEmpty) {
      await _client.from('check_in_form_responses').insert({
        'check_in_id': checkInRow['id'],
        'athlete_id': athleteId,
        'form_id': formId,
        'responses': formResponses,
        'created_at': now,
      });
    }
  }

  /// Get last check-in date for current user
  Future<DateTime?> getLastCheckInDate() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from('check_ins')
        .select('created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    final created = response['created_at'] as String?;
    if (created == null) return null;
    return DateTime.tryParse(created);
  }

  /// Compute pending check-in status: due date + is pending
  Future<
    ({
      DateTime? lastDate,
      DateTime? dueDate,
      bool isPending,
      bool isFirstCheckIn,
      int daysOverdue,
    })
  >
  getCheckInStatus() async {
    final lastDate = await getLastCheckInDate();
    final now = DateTime.now();
    final isFirstCheckIn = lastDate == null;

    // The first check-in is an onboarding action, not an overdue check-in.
    DateTime? dueDate;
    if (lastDate != null) {
      dueDate = DateTime(
        lastDate.year,
        lastDate.month,
        lastDate.day,
      ).add(const Duration(days: 30));
    }

    final isPending =
        dueDate != null &&
        (now.isAfter(dueDate) || now.isAtSameMomentAs(dueDate));
    final daysOverdue = isPending ? now.difference(dueDate!).inDays : 0;

    return (
      lastDate: lastDate,
      dueDate: dueDate,
      isPending: isPending,
      isFirstCheckIn: isFirstCheckIn,
      daysOverdue: daysOverdue,
    );
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
        final yesterday = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 1));
        final workoutDay = DateTime(
          lastWorkoutDate.year,
          lastWorkoutDate.month,
          lastWorkoutDate.day,
        );

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

    debugPrint(
      '🔥 Streak updated for $athleteId: $newStreak (last: $todayStr)',
    );
  }

  /// Save workout session log
  Future<void> saveWorkoutSession(Map<String, dynamic> logData) async {
    debugPrint('📊 Saving workout session log: $logData');

    try {
      final athleteId = await _getAthleteId();
      await _client.from('workout_sessions').insert({
        'athlete_id': athleteId,
        'routine_id': logData['routine_id'],
        'day_number': logData['day_number'],
        'started_at': logData['started_at'],
        'duration_seconds': logData['duration_seconds'],
        'sets_completed': logData['sets_completed'],
        'is_completed': logData['is_completed'],
        'set_logs':
            logData['set_logs'], // Stores the recorded weights per exercise/set
        'reps_logs':
            logData['reps_logs'], // Stores the recorded reps per exercise/set
      });
      debugPrint('✅ Workout session log saved successfully');

      // Update Streak on successful completion
      if (logData['is_completed'] == true) {
        if (athleteId != null) {
          await _updateStreak(athleteId);

          // Notify trainer about workout completion
          await _notifyTrainerWorkoutCompleted(
            athleteId,
            logData['duration_seconds'] as int?,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving workout session: $e');
      // Rethrow if needed, or handle gracefully
    }
  }

  /// Notify trainer when student completes a workout
  Future<void> _notifyTrainerWorkoutCompleted(
    String athleteId,
    int? durationSeconds,
  ) async {
    try {
      final athlete = await _client
          .from('athletes')
          .select('user_id, trainer_id, profiles(name)')
          .eq('id', athleteId)
          .maybeSingle();
      if (athlete == null) return;

      final trainerRecordId = athlete['trainer_id'] as String?;
      if (trainerRecordId == null) return;

      final trainer = await _client
          .from('trainers')
          .select('user_id')
          .eq('id', trainerRecordId)
          .maybeSingle();
      final trainerUserId = trainer?['user_id'] as String?;
      if (trainerUserId == null) return;

      final profile = athlete['profiles'];
      final studentName = profile is Map
          ? profile['name'] as String? ?? 'Alumno'
          : 'Alumno';
      final studentUserId = athlete['user_id'] as String? ?? athleteId;
      final durationMinutes = durationSeconds != null
          ? (durationSeconds / 60).round()
          : 0;

      // Create notification for trainer
      await _client.from('notifications').insert({
        'user_id': trainerUserId,
        'type': 'workoutCompleted',
        'title': '¡Entrenamiento completado!',
        'message':
            '$studentName completó su entrenamiento${durationMinutes > 0 ? ' en $durationMinutes min' : ''}',
        'data': {'student_id': studentUserId, 'athlete_id': athleteId},
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('📬 Trainer notified of workout completion');
    } catch (e) {
      debugPrint('⚠️ Error notifying trainer: $e');
      // Non-critical, don't throw
    }
  }

  /// Get the last completed workout session for a routine, specific to a day
  Future<Map<String, dynamic>?> getLastWorkoutSession(
    String routineId,
    int dayNumber,
  ) async {
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

  /// Get the last N completed workout sessions for a routine/day
  /// Used for showing recent history in exercise detail screen.
  Future<List<Map<String, dynamic>>> getRecentWorkoutSessions(
    String routineId,
    int dayNumber, {
    int limit = 3,
  }) async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return [];

    final response = await _client
        .from('workout_sessions')
        .select()
        .eq('athlete_id', athleteId)
        .eq('routine_id', routineId)
        .eq('day_number', dayNumber)
        .eq('is_completed', true)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response);
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
  Future<void> logSupplementIntake({
    bool? dailyTaken,
    bool? chemicalTaken,
  }) async {
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
    await _client
        .from('supplement_logs')
        .upsert(data, onConflict: 'athlete_id, date');
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

    await _client
        .from('supplement_logs')
        .upsert(data, onConflict: 'athlete_id, date');
  }

  // ==================== DAILY STEPS ====================

  /// Get today's step count and goal
  Future<Map<String, dynamic>> getDailySteps() async {
    final athleteId = await _getAthleteId();
    if (athleteId == null)
      return {'steps': 0, 'goal': 10000, 'updatedToday': false};

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    final response = await _client
        .from('daily_steps')
        .select()
        .eq('athlete_id', athleteId)
        .eq('date', todayStr)
        .maybeSingle();

    if (response == null) {
      // Get goal from the daily_steps table default or athletes table
      final athlete = await _client
          .from('athletes')
          .select('daily_steps_goal')
          .eq('id', athleteId)
          .maybeSingle();

      final goal = athlete?['daily_steps_goal'] as int? ?? 10000;
      return {'steps': 0, 'goal': goal, 'updatedToday': false};
    }

    return {
      'steps': response['step_count'] as int? ?? 0,
      'goal': response['goal'] as int? ?? 10000,
      'updatedToday': true,
    };
  }

  /// Update today's step count
  Future<void> updateDailySteps(int steps) async {
    final athleteId = await _getAthleteId();
    if (athleteId == null) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Get goal from athletes table
    final athlete = await _client
        .from('athletes')
        .select('daily_steps_goal')
        .eq('id', athleteId)
        .maybeSingle();

    final goal = athlete?['daily_steps_goal'] as int? ?? 10000;

    await _client.from('daily_steps').upsert({
      'athlete_id': athleteId,
      'date': todayStr,
      'step_count': steps,
      'goal': goal,
      'source': 'manual',
      'synced_at': DateTime.now().toIso8601String(),
    }, onConflict: 'athlete_id, date');

    debugPrint('👟 Daily steps updated: $steps / $goal');
  }
}

/// Provider for StudentService
final studentServiceProvider = Provider<StudentService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StudentService(client);
});

final activeMealPlanProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final service = ref.read(studentServiceProvider);
  return service.getMyActiveMealPlan();
});

/// Provider for student's active routine
final activeRoutineProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
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
final todaySupplementLogProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final service = ref.read(studentServiceProvider);
  return service.getTodaySupplementLog();
});

/// Provider for last workout session for a specific day
final lastSessionProvider =
    FutureProvider.family<
      Map<String, dynamic>?,
      ({String routineId, int dayNumber})
    >((ref, arg) async {
      final service = ref.read(studentServiceProvider);
      return service.getLastWorkoutSession(arg.routineId, arg.dayNumber);
    });

/// Provider for daily steps (with auto-refresh capability)
final dailyStepsProvider =
    StateNotifierProvider<DailyStepsNotifier, AsyncValue<Map<String, dynamic>>>(
      (ref) {
        final service = ref.watch(studentServiceProvider);
        return DailyStepsNotifier(service);
      },
    );

class DailyStepsNotifier
    extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final StudentService _service;

  DailyStepsNotifier(this._service) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _service.getDailySteps();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSteps(int steps) async {
    try {
      await _service.updateDailySteps(steps);
      await _load(); // Refresh after update
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void refresh() => _load();
}

/// Provider for check-in status (last date, due date, is pending, days overdue)
/// Aparece como banner/notificación cuando está vencido.
typedef CheckInStatus = ({
  DateTime? lastDate,
  DateTime? dueDate,
  bool isPending,
  bool isFirstCheckIn,
  int daysOverdue,
});

final checkInStatusProvider = FutureProvider<CheckInStatus>((ref) async {
  final service = ref.read(studentServiceProvider);
  return service.getCheckInStatus();
});

/// Provider for last N workout sessions of an athlete for a given routine/day
/// (used to show history in exercise screen - currently last 3)
final recentSessionsProvider =
    FutureProvider.family<
      List<Map<String, dynamic>>,
      ({String routineId, int dayNumber, int limit})
    >((ref, arg) async {
      final service = ref.read(studentServiceProvider);
      return service.getRecentWorkoutSessions(
        arg.routineId,
        arg.dayNumber,
        limit: arg.limit,
      );
    });
