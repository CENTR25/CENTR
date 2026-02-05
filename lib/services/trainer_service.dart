import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'storage_service.dart';

/// Service for trainer-specific operations
class TrainerService {
  final SupabaseClient _client;
  
  TrainerService(this._client);
  
  String? get currentUserId => _client.auth.currentUser?.id;
  
  /// Get trainer ID from trainers table (not user_id)
  Future<String?> _getTrainerId() async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('🔴 _getTrainerId: No user logged in');
      return null;
    }
    
    debugPrint('🔍 _getTrainerId: Buscando trainer para user_id: $userId');
    
    final result = await _client
        .from('trainers')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    
    final trainerId = result?['id'] as String?;
    debugPrint('🔍 _getTrainerId: trainer_id encontrado: $trainerId');
    
    return trainerId;
  }
  
  // ==================== STUDENTS ====================
  
  /// Get all students for current trainer
  Future<List<Map<String, dynamic>>> getMyStudents() async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) {
      debugPrint('🔴 getMyStudents: No trainer_id, returning empty list');
      return [];
    }
    
    debugPrint('🔍 getMyStudents: Buscando alumnos para trainer_id: $trainerId');
    
    // Use left join instead of inner to see all athletes
    final response = await _client
        .from('athletes')
        .select('*, profiles(*), streaks(*)')
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    
    debugPrint('📦 getMyStudents RAW response: $response');
    debugPrint('✅ getMyStudents: Encontrados ${response.length} alumnos');
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get student count for current trainer
  Future<int> getStudentCount() async {
    final students = await getMyStudents();
    return students.length;
  }
  
  /// Get unique invite link for current trainer
  /// This link can be shared via WhatsApp, email, or any medium
  Future<String> getMyInviteLink() async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) throw Exception('No trainer record found');
    
    // Generate a shareable link with trainer ID encoded
    // In production, this should be a deep link or web URL
    return 'https://northstar.app/register?trainer=$trainerId';
  }
  
  /// Get student details with progress
  Future<Map<String, dynamic>?> getStudentDetails(String studentId) async {
    final response = await _client
        .from('athletes')
        .select('''
          *,
          profiles(*),
          athlete_routines(*, routines(*)),
          athlete_meal_plans(*, meal_plans(*)),
          workout_logs(*, routine_exercises(*, exercises(*))),
          body_progress(*),
          streaks(*),
          daily_steps(*)
        ''')
        .eq('id', studentId)
        .maybeSingle();
    
    return response;
  }
  
  /// Update athlete supplements
  Future<void> updateAthleteSupplements(String athleteId, String daily, String chemical) async {
    await _client.from('athletes').update({
      'daily_supplements': daily,
      'chemical_supplements': chemical,
    }).eq('id', athleteId);
  }

  /// Update athlete cardio configuration
  Future<void> updateAthleteCardio(String athleteId, String description, List<int> days) async {
    debugPrint('🏃 updateAthleteCardio: $athleteId, desc: $description, days: $days');
    
    try {
      await _client.from('athletes').update({
        'cardio_description': description,
        'cardio_days': days,
      }).eq('id', athleteId);
      debugPrint('✅ updateAthleteCardio success');
    } catch (e) {
      debugPrint('⚠️ updateAthleteCardio failed with standard list: $e');
      debugPrint('🔄 Retrying with Postgres array string format...');
      
      // Fallback: Try sending as Postgres array string format "{1,2,3}"
      // This is sometimes needed if the column is strict integer[] and JSON parsing fails
      final pgArrayString = '{${days.join(',')}}';
      
      try {
        await _client.from('athletes').update({
          'cardio_description': description,
          'cardio_days': pgArrayString,
        }).eq('id', athleteId);
        debugPrint('✅ updateAthleteCardio success with PG string');
      } catch (retryError) {
        debugPrint('❌ updateAthleteCardio retry failed: $retryError');
        rethrow;
      }
    }
  }
  
  // ==================== EXERCISES ====================
  
  /// Get all exercises (global library)
  Future<List<Map<String, dynamic>>> getExercises({String? category, String? muscleGroup}) async {
    var query = _client.from('exercises').select();
    
    if (category != null) {
      query = query.eq('category', category);
    }
    if (muscleGroup != null) {
      query = query.eq('muscle_group', muscleGroup);
    }
    
    final response = await query.order('name');
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get exercise categories
  Future<List<String>> getExerciseCategories() async {
    final response = await _client
        .from('exercises')
        .select('category')
        .not('category', 'is', null);
    
    final categories = response
        .map((e) => e['category'] as String?)
        .where((c) => c != null)
        .cast<String>()
        .toSet()
        .toList();
    
    return categories;
  }
  
  /// Get muscle groups
  Future<List<String>> getMuscleGroups() async {
    final response = await _client
        .from('exercises')
        .select('muscle_group')
        .not('muscle_group', 'is', null);
    
    final groups = response
        .map((e) => e['muscle_group'] as String?)
        .where((g) => g != null)
        .cast<String>()
        .toSet()
        .toList();
    
    return groups;
  }
  
  /// Create custom exercise
  Future<Map<String, dynamic>> createExercise({
    required String name,
    required String muscleGroup,
    String? instructions,
  }) async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) throw Exception('No trainer record found');

    final response = await _client.from('exercises').insert({
      'name': name,
      'muscle_group': muscleGroup,
      'instructions': instructions,
      'created_by_trainer': trainerId,
      'is_public': false,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return response;
  }
  
  /// Update exercise media URLs after upload
  Future<void> updateExerciseMedia(
    String exerciseId, {
    String? videoUrl,
    List<String>? imageUrls,
  }) async {
    final updates = <String, dynamic>{};
    
    if (videoUrl != null) {
      updates['video_url'] = videoUrl;
    }
    
    if (imageUrls != null && imageUrls.isNotEmpty) {
      updates['image_urls'] = imageUrls;
    }
    
    if (updates.isNotEmpty) {
      await _client.from('exercises').update(updates).eq('id', exerciseId);
    }
  }
  
  /// Update exercise basic info
  Future<void> updateExercise(
    String exerciseId, {
    String? name,
    String? muscleGroup,
    String? instructions,
  }) async {
    final updates = <String, dynamic>{};
    
    if (name != null) {
      updates['name'] = name;
    }
    
    if (muscleGroup != null) {
      updates['muscle_group'] = muscleGroup;
    }
    
    if (instructions != null) {
      updates['instructions'] = instructions;
    }
    
    if (updates.isNotEmpty) {
      await _client.from('exercises').update(updates).eq('id', exerciseId);
    }
  }
  
  
  
  // ==================== ROUTINES ====================
  
  /// Get all routines created by current trainer
  Future<List<Map<String, dynamic>>> getMyRoutines() async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) return [];
    
    final response = await _client
        .from('routines')
        .select('*, routine_exercises(*, exercises(*))')
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get routine by ID
  Future<Map<String, dynamic>?> getRoutine(String routineId) async {
    final response = await _client
        .from('routines')
        .select('*, routine_exercises(*, exercises(*))')
        .eq('id', routineId)
        .maybeSingle();
    
    return response;
  }
  
  /// Create a new routine
  Future<Map<String, dynamic>> createRoutine({
    required String name,
    String? description,
    String? objective,
    String level = 'beginner',
    int daysPerWeek = 3,
    File? imageFile,
    String? imageUrl, // NEW: Allow passing URL directly
    required StorageService storageService,
  }) async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) throw Exception('No trainer record found for this user');
    
    String? finalImageUrl = imageUrl; // Use the provided imageUrl if available
    
    if (imageFile != null) { // If an image file is provided, upload it
      final userId = currentUserId;
      if (userId != null) {
        final uploadedUrl = await storageService.uploadRoutineImage(imageFile, userId); // Corrected typo
        finalImageUrl = uploadedUrl; // Update finalImageUrl with the uploaded URL
      }
    }
    
    // Schema uses 'title' not 'name'
    final data = <String, dynamic>{
      'trainer_id': trainerId,
      'title': name,  // Column is 'title' in schema
      'objective': objective,
      'level': level,
      'days_per_week': daysPerWeek,
      'created_at': DateTime.now().toIso8601String(),
      if (finalImageUrl != null) 'image_url': finalImageUrl,
    };
    
    final response = await _client.from('routines').insert(data).select().single();
    
    return response;
  }
  
  /// Update routine
  Future<void> updateRoutine(String routineId, Map<String, dynamic> updates) async {
    await _client.from('routines').update(updates).eq('id', routineId);
  }
  
  /// Delete routine
  Future<void> deleteRoutine(String routineId) async {
    await _client.from('routines').delete().eq('id', routineId);
  }
  
  /// Add exercise to routine
  Future<void> addExerciseToRoutine({
    required String routineId,
    required String exerciseId,
    required int dayNumber,
    int sets = 3,
    String? reps,
    String? restTime,
    int orderIndex = 0,
    String? notes,
  }) async {
    // Parse rest time to seconds
    int restSeconds = 60;
    if (restTime != null) {
      restSeconds = int.tryParse(restTime.replaceAll('s', '')) ?? 60;
    }

    await _client.from('routine_exercises').insert({
      'routine_id': routineId,
      'exercise_id': exerciseId,
      'day_number': dayNumber,
      'sets': sets,
      'reps_target': reps ?? '10-12',  // Schema uses reps_target
      'rest_seconds': restSeconds,      // Schema uses rest_seconds (integer)
      'order_index': orderIndex,
      'comment': notes,                 // Schema uses comment, not notes
    });
  }
  
  /// Remove exercise from routine
  Future<void> removeExerciseFromRoutine(String routineExerciseId) async {
    await _client.from('routine_exercises').delete().eq('id', routineExerciseId);
  }

  /// Update routine exercise details (sets, reps, order, comment)
  Future<void> updateRoutineExercise(String routineExerciseId, Map<String, dynamic> updates) async {
    await _client.from('routine_exercises').update(updates).eq('id', routineExerciseId);
  }
  
  /// Check if routine name exists
  Future<bool> checkRoutineNameExists(String name) async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) return false;

    final response = await _client
        .from('routines')
        .select('id')
        .eq('trainer_id', trainerId)
        .eq('title', name)
        .maybeSingle();

    return response != null;
  }

  /// Assign routine to student (CLONE STRATEGY)
  /// Creates a copy of the routine specifically for the student
  Future<void> assignRoutineToStudent({
    required String athleteId,
    required String routineId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final trainerId = currentUserId;
    if (trainerId == null) throw Exception('No authenticated user');

    // 1. Get original routine details with exercises
    final originalRoutine = await getRoutine(routineId);
    if (originalRoutine == null) throw Exception('Routine not found');

    // 2. Get student details for naming
    final studentData = await _client
        .from('athletes')
        .select('profiles(name)')
        .eq('id', athleteId)
        .single();
    final studentName = studentData['profiles']['name'] ?? 'Alumno';

    // 3. Create NEW routine (Clone)
    // We keep the same structure but mark it maybe with a special flag if needed, 
    // or just rely on it being assigned. 
    // For now, we'll append the student name to distinguish it in lists if visible,
    // or we could keep the same name. Let's append for clarity.
    final newRoutineData = {
      'trainer_id': originalRoutine['trainer_id'],
      'title': '${originalRoutine['title']} ($studentName)',
      'objective': originalRoutine['objective'],
      'level': originalRoutine['level'],
      'days_per_week': originalRoutine['days_per_week'],
      'created_at': DateTime.now().toIso8601String(),
      'image_url': originalRoutine['image_url'],
    };

    final newRoutine = await _client
        .from('routines')
        .insert(newRoutineData)
        .select()
        .single();

    final newRoutineId = newRoutine['id'];

    // 4. Clone exercises
    final originalExercises = (originalRoutine['routine_exercises'] as List? ?? []);
    
    for (var ex in originalExercises) {
        await _client.from('routine_exercises').insert({
          'routine_id': newRoutineId,
          'exercise_id': ex['exercise_id'],
          'day_number': ex['day_number'],
          'sets': ex['sets'],
          'reps_target': ex['reps_target'], 
          'rest_seconds': ex['rest_seconds'],
          'order_index': ex['order_index'],
          'comment': ex['comment'],
        });
    }

    // 5. Deactivate previous active routines for this student
    await _client
        .from('athlete_routines')
        .update({'is_active': false})
        .eq('athlete_id', athleteId)
        .eq('is_active', true);
    
    // 6. Assign the NEW cloned routine
    await _client.from('athlete_routines').insert({
      'athlete_id': athleteId,
      'routine_id': newRoutineId,
      'start_date': (startDate ?? DateTime.now()).toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': true,
    });
  }
  
  /// Assign routine to multiple students (Batch)
  Future<void> assignRoutineToMultipleStudents({
    required List<String> athleteIds,
    required String routineId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    // Run sequentially to avoid overwhelming the DB connection if many students
    for (final athleteId in athleteIds) {
      await assignRoutineToStudent(
        athleteId: athleteId,
        routineId: routineId,
        startDate: startDate,
        endDate: endDate,
      );
    }
  }
  /// Save an existing routine (e.g. from a student) as a new template
  Future<void> saveRoutineAsTemplate({
    required String sourceRoutineId,
    required String newTitle,
  }) async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) throw Exception('No trainer record found');
    
    // 1. Get source routine
    final sourceRoutine = await getRoutine(sourceRoutineId);
    if (sourceRoutine == null) throw Exception('Source routine not found');
    
    // 2. Create new routine as template
    final newRoutineData = {
      'trainer_id': trainerId,
      'title': newTitle,
      'objective': sourceRoutine['objective'],
      'level': sourceRoutine['level'],
      'days_per_week': sourceRoutine['days_per_week'],
      'created_at': DateTime.now().toIso8601String(),
      'image_url': sourceRoutine['image_url'],
      // Ensure it's not linked to any specific athlete implicitly (schema doesn't have an owner field other than trainer_id)
    };
    
    final newRoutine = await _client
        .from('routines')
        .insert(newRoutineData)
        .select()
        .single();
    
    final newRoutineId = newRoutine['id'];
    
    // 3. Copy exercises
    final sourceExercises = (sourceRoutine['routine_exercises'] as List? ?? []);
    
    for (var ex in sourceExercises) {
        await _client.from('routine_exercises').insert({
          'routine_id': newRoutineId,
          'exercise_id': ex['exercise_id'],
          'day_number': ex['day_number'],
          'sets': ex['sets'],
          'reps_target': ex['reps_target'], 
          'rest_seconds': ex['rest_seconds'],
          'order_index': ex['order_index'],
          'comment': ex['comment'],
        });
    }
  }
  
  // ==================== MEAL PLANS ====================
  
  /// Get all meal plans created by current trainer
  Future<List<Map<String, dynamic>>> getMyMealPlans() async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) return [];
    
    final response = await _client
        .from('meal_plans')
        .select('*, meal_plan_items(*)')
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Get meal plan by ID
  Future<Map<String, dynamic>?> getMealPlan(String mealPlanId) async {
    final response = await _client
        .from('meal_plans')
        .select('*, meal_plan_items(*)')
        .eq('id', mealPlanId)
        .maybeSingle();
    
    return response;
  }
  
  /// Create a meal plan
  Future<Map<String, dynamic>> createMealPlan({
    required String title,
    String? description,
    int? targetCalories,
    File? imageFile,
    required StorageService storageService,
  }) async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) throw Exception('No trainer record found');

    String? imageUrl;
    if (imageFile != null) {
      imageUrl = await storageService.uploadMealPlanCover(imageFile, trainerId);
    }
    
    final response = await _client.from('meal_plans').insert({
      'trainer_id': trainerId,
      'title': title,
      'description': description,
      'target_calories': targetCalories,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();
    
    return response;
  }

  /// Update a meal plan
  Future<void> updateMealPlan({
    required String planId,
    required String title,
    String? description,
    int? targetCalories,
    File? imageFile,
    required StorageService storageService,
  }) async {
    final updates = {
      'title': title,
      'description': description,
      'target_calories': targetCalories,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (imageFile != null) {
      final trainerId = await _getTrainerId();
      if (trainerId != null) {
        final imageUrl = await storageService.uploadMealPlanCover(imageFile, trainerId);
        updates['image_url'] = imageUrl;
      }
    }

    await _client.from('meal_plans').update(updates).eq('id', planId);
  }
  

  
  /// Delete meal plan
  Future<void> deleteMealPlan(String mealPlanId) async {
    await _client.from('meal_plans').delete().eq('id', mealPlanId);
  }
  
  /// Add item to meal plan
  Future<void> addMealPlanItem({
    required String mealPlanId,
    required int dayNumber,
    required String timeOfDay, // breakfast, lunch, dinner, snack
    required String name,
    String? description,
    int? calories,
    Map<String, dynamic>? macros, // {protein: 30, carbs: 50, fat: 20}
    File? imageFile,
    required StorageService storageService,
  }) async {
    String? imageUrl;
    
    if (imageFile != null) {
      imageUrl = await storageService.uploadMealImage(imageFile, mealPlanId);
    }

    await _client.from('meal_plan_items').insert({
      'meal_plan_id': mealPlanId,
      'day_number': dayNumber,
      'time_of_day': timeOfDay,
      'meal_title': name,
      'meal_description': description,
      'calories': calories,
      'macros': macros,
      if (imageUrl != null) 'image_url': imageUrl,
    });
  }
  
  /// Remove item from meal plan
  Future<void> removeMealPlanItem(String itemId) async {
    await _client.from('meal_plan_items').delete().eq('id', itemId);
  }
  
  /// Assign meal plan to student
  Future<void> assignMealPlanToStudent({
    required String athleteId,
    required String mealPlanId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final trainerId = currentUserId;
    if (trainerId == null) throw Exception('No authenticated user');
    
    // Deactivate current meal plans
    await _client
        .from('athlete_meal_plans')
        .update({'is_active': false})
        .eq('athlete_id', athleteId)
        .eq('is_active', true);
    
    // Assign new meal plan
    await _client.from('athlete_meal_plans').insert({
      'athlete_id': athleteId,
      'meal_plan_id': mealPlanId,
      'start_date': (startDate ?? DateTime.now()).toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': true,
    });
  }
  
  // ==================== STATS ====================
  
  /// Get trainer stats
  Future<Map<String, dynamic>> getTrainerStats() async {
    final trainerId = await _getTrainerId();
    if (trainerId == null) return {};
    
    final students = await getMyStudents();
    final routines = await getMyRoutines();
    final mealPlans = await getMyMealPlans();
    
    // Count active students (those who logged in this week)
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    int activeStudents = 0;
    for (final student in students) {
      final profile = student['profiles'] as Map<String, dynamic>?;
      if (profile != null && profile['last_login_at'] != null) {
        final lastLogin = DateTime.parse(profile['last_login_at']);
        if (lastLogin.isAfter(oneWeekAgo)) {
          activeStudents++;
        }
      }
    }
    
    return {
      'total_students': students.length,
      'active_students': activeStudents,
      'total_routines': routines.length,
      'total_meal_plans': mealPlans.length,
    };
  }

  /// Get student history (workout logs)
  Future<List<Map<String, dynamic>>> getStudentHistory(String studentId) async {
    final response = await _client
        .from('workout_logs')
        .select('*, routine_exercises(*, routines(*), exercises(*))')
        .eq('athlete_id', studentId)
        .order('created_at', ascending: false);
        
    return List<Map<String, dynamic>>.from(response);
  }

  /// Search food bank (Internal Database)
  Future<List<Map<String, dynamic>>> searchFoodBank(String query) async {
    if (query.length < 2) return [];

    final response = await _client
        .from('default_meals')
        .select()
        .or('meal_title.ilike.%$query%,meal_description.ilike.%$query%')
        .limit(20);
        
    return List<Map<String, dynamic>>.from(response);
  }
}

/// Provider for TrainerService
final trainerServiceProvider = Provider<TrainerService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TrainerService(client);
});

/// Provider for trainer's students
final myStudentsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMyStudents();
});

/// Provider for trainer's routines
final myRoutinesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMyRoutines();
});

/// Provider for trainer's meal plans
final myMealPlansProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMyMealPlans();
});

/// Provider for exercises library
final exercisesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getExercises();
});

/// Provider for trainer stats
final trainerStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getTrainerStats();
});
