import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A workout the athlete has begun but not yet completed. Persisted locally so
/// the "Entrenamiento en curso" home card survives navigating away, abandoning,
/// or the app being killed. Cleared only on completion.
class ActiveWorkout {
  final String routineId;
  final int dayNumber;
  final String routineName;

  const ActiveWorkout({
    required this.routineId,
    required this.dayNumber,
    required this.routineName,
  });

  Map<String, dynamic> toJson() => {
        'routine_id': routineId,
        'day_number': dayNumber,
        'routine_name': routineName,
      };

  factory ActiveWorkout.fromJson(Map<String, dynamic> j) => ActiveWorkout(
        routineId: j['routine_id'] as String,
        dayNumber: (j['day_number'] as num).toInt(),
        routineName: (j['routine_name'] as String?) ?? '',
      );
}

/// Holds the current in-progress workout marker, backed by SharedPreferences.
/// `null` means no workout is in progress.
class ActiveWorkoutNotifier extends StateNotifier<ActiveWorkout?> {
  ActiveWorkoutNotifier() : super(null) {
    _load();
  }

  static const _key = 'active_workout';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      state = ActiveWorkout.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/legacy value — ignore, leave as no active workout.
    }
  }

  /// Mark a workout as begun (called when the session screen opens).
  ///
  /// This is invoked synchronously from `WorkoutSessionScreen.initState`, so the
  /// `state` assignment must NOT happen during that build pass (Riverpod throws
  /// "modified a provider while the widget tree was building"). Awaiting the
  /// prefs instance first yields control, so `state` is set in a later microtask
  /// after the build completes.
  Future<void> start(ActiveWorkout workout) async {
    final prefs = await SharedPreferences.getInstance();
    state = workout;
    await prefs.setString(_key, jsonEncode(workout.toJson()));
  }

  /// Clear the marker (called on completion or when the routine is no longer
  /// resumable).
  Future<void> finish() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutNotifier, ActiveWorkout?>(
  (ref) => ActiveWorkoutNotifier(),
);
