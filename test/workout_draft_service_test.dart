import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/services/workout_draft_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutDraft _make({
  String routineId = 'r1',
  int dayNumber = 2,
  DateTime? savedAt,
}) =>
    WorkoutDraft(
      routineId: routineId,
      dayNumber: dayNumber,
      startedAt: DateTime(2026, 1, 1, 10).toIso8601String(),
      exerciseCount: 3,
      visitOrder: const [0, 2, 1],
      visitPos: 1,
      currentSet: 2,
      recordedWeights: const {
        0: {1: 50.0, 2: 55.5},
        2: {1: 20.0},
      },
      recordedReps: const {
        0: {1: 10, 2: 8},
        2: {1: 12},
      },
      pendingWeight: '60',
      pendingReps: '6',
      savedAt: savedAt ?? DateTime(2026, 1, 1, 10, 30),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toJson/fromJson round-trips all fields', () {
    final draft = _make();
    final restored = WorkoutDraft.fromJson(draft.toJson());

    expect(restored.routineId, draft.routineId);
    expect(restored.dayNumber, draft.dayNumber);
    expect(restored.startedAt, draft.startedAt);
    expect(restored.exerciseCount, draft.exerciseCount);
    expect(restored.visitOrder, draft.visitOrder);
    expect(restored.visitPos, draft.visitPos);
    expect(restored.currentSet, draft.currentSet);
    expect(restored.recordedWeights, draft.recordedWeights);
    expect(restored.recordedReps, draft.recordedReps);
    expect(restored.pendingWeight, draft.pendingWeight);
    expect(restored.pendingReps, draft.pendingReps);
    expect(restored.savedAt, draft.savedAt);
  });

  test('save then load returns an equivalent draft', () async {
    final service = WorkoutDraftService();
    await service.save(_make());

    final loaded = await service.load('r1', 2);
    expect(loaded, isNotNull);
    expect(loaded!.recordedWeights[0]![2], 55.5);
    expect(loaded.recordedReps[2]![1], 12);
    expect(loaded.visitOrder, [0, 2, 1]);
  });

  test('load is keyed by routine + day — no cross-bleed', () async {
    final service = WorkoutDraftService();
    await service.save(_make(routineId: 'r1', dayNumber: 2));

    expect(await service.load('r1', 3), isNull);
    expect(await service.load('r2', 2), isNull);
    expect(await service.load('r1', 2), isNotNull);
  });

  test('clear removes only its own key', () async {
    final service = WorkoutDraftService();
    await service.save(_make(routineId: 'r1', dayNumber: 1));
    await service.save(_make(routineId: 'r1', dayNumber: 2));

    await service.clear('r1', 1);
    expect(await service.load('r1', 1), isNull);
    expect(await service.load('r1', 2), isNotNull);
  });

  test('clearAll wipes every draft', () async {
    final service = WorkoutDraftService();
    await service.save(_make(routineId: 'r1', dayNumber: 1));
    await service.save(_make(routineId: 'r2', dayNumber: 5));

    await service.clearAll();
    expect(await service.load('r1', 1), isNull);
    expect(await service.load('r2', 5), isNull);
  });
}
