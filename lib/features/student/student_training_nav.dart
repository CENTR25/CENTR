import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/active_workout_service.dart';
import '../../services/student_service.dart';
import 'student_routine_screen.dart';
import 'workout_session_screen.dart';

/// Shared "Entrenar" tap behaviour for the student bottom nav and the
/// "Entrenamiento en curso" home card.
///
/// If a workout is in progress, resume it straight into [WorkoutSessionScreen]
/// (the athlete's sets are restored from the local draft). Otherwise open the
/// routine list so they can pick a day. Previously the nav button always went
/// to the routine list, so mid-workout it appeared to "do nothing".
Future<void> openTraining(BuildContext context, WidgetRef ref) async {
  final active = ref.read(activeWorkoutProvider);
  if (active != null) {
    final resumed = await _resumeActiveWorkout(context, ref, active);
    if (resumed) return;
  }
  if (!context.mounted) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const StudentRoutineScreen()),
  );
}

/// Pushes the in-progress session. Returns false (and clears the stale marker)
/// if the routine/day backing the marker no longer exists, so the caller can
/// fall back to the routine list.
Future<bool> _resumeActiveWorkout(
  BuildContext context,
  WidgetRef ref,
  ActiveWorkout active,
) async {
  final routine = await ref.read(activeRoutineProvider.future);
  final matches =
      routine != null && routine['id'].toString() == active.routineId;

  final dayExercises = matches
      ? (((routine['routine_exercises'] as List?) ?? const [])
          .where((e) => (e['day_number'] as num?)?.toInt() == active.dayNumber)
          .cast<Map<String, dynamic>>()
          .toList()
        ..sort((a, b) => ((a['order_index'] as num?)?.toInt() ?? 0)
            .compareTo((b['order_index'] as num?)?.toInt() ?? 0)))
      : <Map<String, dynamic>>[];

  if (!context.mounted) return false;

  // Routine changed or day no longer exists — the marker is stale.
  if (dayExercises.isEmpty) {
    ref.read(activeWorkoutProvider.notifier).finish();
    return false;
  }

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => WorkoutSessionScreen(
        routine: routine!,
        exercises: dayExercises,
        dayNumber: active.dayNumber,
      ),
    ),
  );
  return true;
}
