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
  /// `state` is assigned before the first `await` so that `finish()` — if called
  /// during startup (e.g. very fast completion or a test) — always wins: `finish()`
  /// sets `state = null` synchronously, and since `start()` has already set its
  /// value before any async gap, there is no window where `start()` could
  /// overwrite a null set by `finish()`.
  ///
  /// The initial call still arrives in a post-build microtask because
  /// `ref.read(...).start(...)` is invoked from `initState` via an unawaited
  /// future — the await inside the method body is what yields past the build.
  Future<void> start(ActiveWorkout workout) async {
    state = workout;
    final prefs = await SharedPreferences.getInstance();
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
