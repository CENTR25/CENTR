import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A snapshot of an in-progress workout session: the sets/reps the athlete has
/// entered so far, plus enough navigation state to resume exactly where they
/// left off. Persisted locally so that if the OS kills the app mid-workout
/// (memory pressure) the data survives and can be restored on reopen.
///
/// This is intentionally device-local (SharedPreferences): athletes are blocked
/// at the RLS layer from updating `workout_sessions`, so a server-side draft is
/// not an option — and keeping it local also means no half-finished rows ever
/// reach the trainer. The final save on completion/abandon remains a clean
/// INSERT and is the only thing that touches Supabase.
class WorkoutDraft {
  final String routineId;
  final int dayNumber;
  final String? startedAt; // ISO 8601, null if countdown never finished
  final int exerciseCount; // guard: discard if the routine was edited
  final List<int> visitOrder;
  final int visitPos;
  final int currentSet;
  final Map<int, Map<int, double>> recordedWeights; // ex -> {set -> kg}
  final Map<int, Map<int, int>> recordedReps; // ex -> {set -> reps}
  final String pendingWeight; // weight text field at flush time
  final String pendingReps; // reps text field at flush time
  final DateTime savedAt;

  const WorkoutDraft({
    required this.routineId,
    required this.dayNumber,
    required this.startedAt,
    required this.exerciseCount,
    required this.visitOrder,
    required this.visitPos,
    required this.currentSet,
    required this.recordedWeights,
    required this.recordedReps,
    required this.pendingWeight,
    required this.pendingReps,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'routine_id': routineId,
        'day_number': dayNumber,
        'started_at': startedAt,
        'exercise_count': exerciseCount,
        'visit_order': visitOrder,
        'visit_pos': visitPos,
        'current_set': currentSet,
        'recorded_weights': recordedWeights.map((k, v) => MapEntry(
            k.toString(), v.map((k2, v2) => MapEntry(k2.toString(), v2)))),
        'recorded_reps': recordedReps.map((k, v) => MapEntry(
            k.toString(), v.map((k2, v2) => MapEntry(k2.toString(), v2)))),
        'pending_weight': pendingWeight,
        'pending_reps': pendingReps,
        'saved_at': savedAt.toIso8601String(),
      };

  factory WorkoutDraft.fromJson(Map<String, dynamic> j) => WorkoutDraft(
        routineId: j['routine_id'].toString(),
        dayNumber: (j['day_number'] as num).toInt(),
        startedAt: j['started_at'] as String?,
        exerciseCount: (j['exercise_count'] as num).toInt(),
        visitOrder: (j['visit_order'] as List)
            .map((e) => (e as num).toInt())
            .toList(),
        visitPos: (j['visit_pos'] as num).toInt(),
        currentSet: (j['current_set'] as num).toInt(),
        recordedWeights: (j['recorded_weights'] as Map).map((k, v) => MapEntry(
              int.parse(k.toString()),
              (v as Map).map((k2, v2) =>
                  MapEntry(int.parse(k2.toString()), (v2 as num).toDouble())),
            )),
        recordedReps: (j['recorded_reps'] as Map).map((k, v) => MapEntry(
              int.parse(k.toString()),
              (v as Map).map((k2, v2) =>
                  MapEntry(int.parse(k2.toString()), (v2 as num).toInt())),
            )),
        pendingWeight: (j['pending_weight'] as String?) ?? '',
        pendingReps: (j['pending_reps'] as String?) ?? '',
        savedAt: DateTime.parse(j['saved_at'] as String),
      );
}

/// Reads/writes [WorkoutDraft]s to SharedPreferences. Keyed by routine + day so
/// a draft for one workout never bleeds into another. Plain utility — called
/// imperatively from the session screen, no Riverpod provider needed.
class WorkoutDraftService {
  static const _prefix = 'workout_draft_';

  static String _keyFor(String routineId, int dayNumber) =>
      '$_prefix${routineId}_$dayNumber';

  Future<void> save(WorkoutDraft draft) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _keyFor(draft.routineId, draft.dayNumber), jsonEncode(draft.toJson()));
    } catch (e) {
      debugPrint('WorkoutDraftService.save error: $e');
    }
  }

  Future<WorkoutDraft?> load(String routineId, int dayNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(routineId, dayNumber));
      if (raw == null) return null;
      return WorkoutDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('WorkoutDraftService.load error: $e');
      return null;
    }
  }

  Future<void> clear(String routineId, int dayNumber) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(routineId, dayNumber));
    } catch (e) {
      debugPrint('WorkoutDraftService.clear error: $e');
    }
  }

  /// Remove every draft — used at logout so one athlete's drafts can't surface
  /// for whoever logs in next on a shared device.
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (e) {
      debugPrint('WorkoutDraftService.clearAll error: $e');
    }
  }
}
