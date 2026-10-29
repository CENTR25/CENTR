import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';
import 'exercise_detail_screen.dart';
import 'student_meal_plan_screen.dart';
import 'student_workout_history_screen.dart';
import 'widgets/student_bottom_nav.dart';
import 'workout_session_screen.dart';

const _weekdayAbbr = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _weekdayFull = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Student "Entrenar" — PRGS navy/teal redesign (Figma). Weekday pills, one
/// exercise card with numbered rows, amber cardio banner, estimated duration,
/// history button and a "Día de descanso" empty state.
class StudentRoutineScreen extends ConsumerStatefulWidget {
  const StudentRoutineScreen({super.key});

  @override
  ConsumerState<StudentRoutineScreen> createState() =>
      _StudentRoutineScreenState();
}

class _StudentRoutineScreenState extends ConsumerState<StudentRoutineScreen> {
  static const int _daysCount = 7;

  // 1-based day (Mon..Sun). Default to today.
  int _selectedDay = DateTime.now().weekday.clamp(1, _daysCount);

  // Cached for the bottom-nav play FAB, which starts the selected day's
  // workout directly. Kept in sync by _buildBody on every build.
  Map<String, dynamic>? _currentRoutine;
  List<Map<String, dynamic>> _currentDayExercises = const [];

  /// True if the last completed session for this routine/day was today.
  bool _completedToday(Map<String, dynamic>? lastSession) {
    final startedStr =
        (lastSession?['started_at'] ?? lastSession?['created_at']) as String?;
    if (startedStr == null) return false;
    final started = DateTime.parse(startedStr).toLocal();
    final now = DateTime.now();
    return started.year == now.year &&
        started.month == now.month &&
        started.day == now.day;
  }

  Future<bool?> _confirmOtherDay(BuildContext context, int dayNumber) {
    final tapped = _weekdayFull[(dayNumber - 1).clamp(0, 6)];
    final today = _weekdayFull[(DateTime.now().weekday - 1).clamp(0, 6)];

    return showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: Dialog(
          backgroundColor: RedesignColors.primario800,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¿Entrenar el día $tapped?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.secundario300,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario300,
                      fontSize: 15,
                      height: 1.45,
                    ),
                    children: [
                      const TextSpan(text: 'Te toca el día '),
                      TextSpan(
                        text: today,
                        style: const TextStyle(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text:
                            '.\nSi hacés el $tapped ahora, el día $today quedará pendiente.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                // Full-width stacked buttons so the confirm action can never be
                // pushed off-screen by a long day name or larger text scaling.
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RedesignColors.actionPrimary,
                    foregroundColor: RedesignColors.onActionPrimary,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Entrenar $tapped',
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmRetrain(BuildContext context) {
    return _confirmDialog(
      context,
      title: 'Ya entrenaste hoy',
      message:
          'Ya completaste el entrenamiento de hoy. ¿Querés volver a entrar igualmente (por ejemplo, para corregir un registro)?',
      confirmLabel: 'Entrenar de nuevo',
    );
  }

  Future<bool?> _confirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: RedesignColors.primario50,
              fontFamily: 'Metropolis',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: RedesignColors.primario300,
              fontFamily: 'Metropolis',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: RedesignColors.primario300),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: RedesignColors.actionPrimary,
                foregroundColor: RedesignColors.onActionPrimary,
                elevation: 0,
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(activeRoutineProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        extendBody: true,
        bottomNavigationBar: StudentBottomNav(
          active: StudentNavTab.entrenar,
          isOnEntrenarScreen: true,
          onInicioTap: () => Navigator.popUntil(context, (r) => r.isFirst),
          onEntrenarTap: () {
            if (_currentRoutine == null || _currentDayExercises.isEmpty) return;
            _startWorkout(_currentRoutine!, _currentDayExercises);
          },
          onNutricionTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentMealPlanScreen()),
          ),
        ),
        body: routineAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                RedesignColors.actionPrimary,
              ),
            ),
          ),
          error: (e, _) => const _CenteredState(
            icon: Icons.error_outline_rounded,
            label: 'No se pudo cargar tu rutina',
          ),
          data: (routine) => _buildBody(routine),
        ),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic>? routine) {
    final exercises = (routine?['routine_exercises'] as List?) ?? const [];
    final dayExercises =
        exercises
            .where((e) => (e['day_number'] as num?)?.toInt() == _selectedDay)
            .toList()
          ..sort(
            (a, b) => ((a['order_index'] as num?)?.toInt() ?? 0).compareTo(
              (b['order_index'] as num?)?.toInt() ?? 0,
            ),
          );

    // Keep the play FAB in sync with what's shown for the selected day.
    _currentRoutine = routine;
    _currentDayExercises = dayExercises.cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          onHistoryTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentWorkoutHistoryScreen(),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _DayPills(
          count: _daysCount,
          selected: _selectedDay,
          onSelect: (d) => setState(() => _selectedDay = d),
        ),
        const SizedBox(height: 14),
        const Divider(
          height: 1,
          thickness: 1,
          color: RedesignColors.primario700,
          indent: 22,
          endIndent: 22,
        ),
        Expanded(
          child: routine == null
              ? const _CenteredState(
                  icon: Icons.fitness_center_rounded,
                  label: 'No tenés una rutina activa',
                )
              : dayExercises.isEmpty
              ? const _CenteredState(
                  icon: Icons.snooze_rounded,
                  label: 'Día de descanso',
                )
              : _DayContent(
                  routine: routine,
                  dayNumber: _selectedDay,
                  dayExercises: dayExercises.cast<Map<String, dynamic>>(),
                  onStart: () => _startWorkout(
                    routine,
                    dayExercises.cast<Map<String, dynamic>>(),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _startWorkout(
    Map<String, dynamic> routine,
    List<Map<String, dynamic>> dayExercises,
  ) async {
    final isToday = _selectedDay == DateTime.now().weekday;

    if (!isToday) {
      final proceed = await _confirmOtherDay(context, _selectedDay);
      if (proceed != true) return;
    } else {
      final last = ref
          .read(
            lastSessionProvider((
              routineId: routine['id'],
              dayNumber: _selectedDay,
            )),
          )
          .valueOrNull;
      if (_completedToday(last)) {
        final retry = await _confirmRetrain(context);
        if (retry != true) return;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          routine: routine,
          exercises: dayExercises,
          dayNumber: _selectedDay,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — "Entrenar" + history button
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final VoidCallback onHistoryTap;
  const _Header({required this.onHistoryTap});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top.clamp(24.0, 100.0) + 14;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, topInset, 22, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Entrenar',
              style: TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario50,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GestureDetector(
            onTap: onHistoryTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: RedesignColors.primario700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day pills (Lun..Dom)
// ---------------------------------------------------------------------------

class _DayPills extends StatelessWidget {
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;

  const _DayPills({
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final day = i + 1;
          final isActive = day == selected;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: isActive
                    ? RedesignColors.secundario300
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: RedesignColors.secundario300.withValues(
                    alpha: isActive ? 1 : 0.55,
                  ),
                  width: 1.5,
                ),
              ),
              child: Text(
                _weekdayAbbr[i],
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: isActive
                      ? RedesignColors.onActionPrimary
                      : RedesignColors.secundario300,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day content — subtitle, cardio banner, exercise card, start button
// ---------------------------------------------------------------------------

class _DayContent extends ConsumerWidget {
  final Map<String, dynamic> routine;
  final int dayNumber;
  final List<Map<String, dynamic>> dayExercises;
  final VoidCallback onStart;

  const _DayContent({
    required this.routine,
    required this.dayNumber,
    required this.dayExercises,
    required this.onStart,
  });

  int _estimateMinutes() {
    var secs = 0;
    for (final e in dayExercises) {
      final sets = (e['sets'] as num?)?.toInt() ?? 3;
      final rest = (e['rest_seconds'] as num?)?.toInt() ?? 60;
      secs += sets * (rest + 45); // ~45s of work per set
    }
    final mins = (secs / 60).round();
    return (mins / 5).round() * 5; // nearest 5 min
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardioAsync = ref.watch(myCardioProvider);
    final count = dayExercises.length;
    final mins = _estimateMinutes();

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 120),
      children: [
        Text(
          '$count ${count == 1 ? 'ejercicio' : 'ejercicios'} - $mins min',
          style: const TextStyle(
            fontFamily: 'Metropolis',
            color: RedesignColors.primario400,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),

        // Cardio banner (if the selected day has cardio)
        cardioAsync.when(
          data: (cardio) {
            final days = (cardio['days'] as List?)?.cast<int>() ?? const [];
            if (!days.contains(dayNumber)) return const SizedBox.shrink();
            final description = (cardio['description'] as String?)?.trim();
            final note = (cardio['note'] as String?)?.trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _CardioBanner(
                description: description?.isNotEmpty == true
                    ? description!
                    : 'Consultá a tu entrenador',
                note: (note?.isNotEmpty ?? false) ? note : null,
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Exercise card
        Container(
          decoration: BoxDecoration(
            color: RedesignColors.primario700,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              for (var i = 0; i < dayExercises.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: RedesignColors.primario600,
                    indent: 18,
                    endIndent: 18,
                  ),
                _ExerciseRow(number: i + 1, exerciseData: dayExercises[i]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Empezar entrenamiento
        ElevatedButton(
          onPressed: onStart,
          style: ElevatedButton.styleFrom(
            backgroundColor: RedesignColors.actionPrimary,
            foregroundColor: RedesignColors.onActionPrimary,
            minimumSize: const Size(double.infinity, 54),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const Text(
            'Empezar entrenamiento',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Cardio banner (amber)
// ---------------------------------------------------------------------------

class _CardioBanner extends StatelessWidget {
  final String description;
  final String? note;
  const _CardioBanner({required this.description, this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedesignColors.advertencia400,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: RedesignColors.advertencia300, // cardio icon bg
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.directions_run_rounded,
              color: RedesignColors.advertencia900,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cardio a realizar',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario900,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario900,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    note!,
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario900.withValues(alpha: 0.75),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise row (numbered)
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  final int number;
  final Map<String, dynamic> exerciseData;

  const _ExerciseRow({required this.number, required this.exerciseData});

  @override
  Widget build(BuildContext context) {
    final exercise = (exerciseData['exercises'] as Map<String, dynamic>?) ?? {};
    final name = (exercise['name'] as String?) ?? 'Ejercicio';
    final sets = (exerciseData['sets'] as num?)?.toInt() ?? 3;
    final reps = _displayReps(exerciseData['reps_target']?.toString() ?? '10');
    final rest = (exerciseData['rest_seconds'] as num?)?.toInt() ?? 60;
    final muscle = (exercise['muscle_group'] as String?)?.trim() ?? '';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseDetailScreen(
            exerciseData: exerciseData,
            coachComment: exerciseData['comment'] as String?,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 26,
              child: Text(
                number.toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario400,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _StatsLine(
                    sets: sets,
                    reps: reps,
                    rest: rest,
                    muscle: muscle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right_rounded,
              color: RedesignColors.primario300,
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsLine extends StatelessWidget {
  final int sets;
  final String reps;
  final int rest;
  final String muscle;

  const _StatsLine({
    required this.sets,
    required this.reps,
    required this.rest,
    required this.muscle,
  });

  Widget _sep() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 9),
    width: 1,
    height: 13,
    color: RedesignColors.secundario500.withValues(alpha: 0.6),
  );

  @override
  Widget build(BuildContext context) {
    const strong = TextStyle(
      fontFamily: 'Metropolis',
      color: RedesignColors.primario50,
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );
    return Row(
      children: [
        Text('$sets x $reps', style: strong),
        _sep(),
        const Icon(
          Icons.timer_outlined,
          size: 14,
          color: RedesignColors.primario300,
        ),
        const SizedBox(width: 4),
        Text('$rest s', style: strong.copyWith(fontWeight: FontWeight.w500)),
        if (muscle.isNotEmpty) ...[
          _sep(),
          Flexible(
            child: Text(
              muscle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.secundario300,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Centered icon + label (empty / error / rest day)
// ---------------------------------------------------------------------------

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CenteredState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: RedesignColors.primario500),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario400,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reps display helper — collapse "10|12|15" / ranges into a compact label.
// ---------------------------------------------------------------------------

String _displayReps(String repsRaw) {
  final repsList = repsRaw.contains('|')
      ? repsRaw.split('|').map((e) => e.trim()).toList()
      : [repsRaw];
  if (repsList.length <= 1) return repsRaw;
  if (repsList.any((r) => r.contains('-'))) return repsList.first;
  final numeric = repsList
      .map((r) => int.tryParse(r))
      .whereType<int>()
      .toList();
  if (numeric.isEmpty) return repsRaw;
  final minR = numeric.reduce((a, b) => a < b ? a : b);
  final maxR = numeric.reduce((a, b) => a > b ? a : b);
  return minR == maxR ? '$minR' : '$minR-$maxR';
}
