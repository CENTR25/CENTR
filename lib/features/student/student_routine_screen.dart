import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import 'workout_session_screen.dart';
import 'exercise_detail_screen.dart';

class StudentRoutineScreen extends ConsumerStatefulWidget {
  const StudentRoutineScreen({super.key});

  @override
  ConsumerState<StudentRoutineScreen> createState() =>
      _StudentRoutineScreenState();
}

class _StudentRoutineScreenState extends ConsumerState<StudentRoutineScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(activeRoutineProvider);
    final cardioAsync = ref.watch(myCardioProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Rutina')),
      body: routineAsync.when(
        data: (routine) {
          if (routine == null) {
            return const Center(child: Text('No tienes rutina activa'));
          }

          final exercises = (routine['routine_exercises'] as List?) ?? [];
          // Support up to 7 days
          final days = 7;

          // Calculate today's workout day (1=Mon, 7=Sun)
          final todayIndex = DateTime.now().weekday - 1;

          // Initialize tab controller if needed or changed
          if (_tabController == null || _tabController!.length != days) {
            _tabController?.dispose();
            _tabController = TabController(
              length: days,
              vsync: this,
              initialIndex: todayIndex.clamp(0, days - 1),
            );
          }

          return Column(
            children: [
              // Tabs
              Container(
                alignment: Alignment.center,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: List.generate(days, (i) {
                    final weekDays = [
                      'Lunes',
                      'Martes',
                      'Miércoles',
                      'Jueves',
                      'Viernes',
                      'Sábado',
                      'Domingo',
                    ];
                    final label = i < weekDays.length
                        ? weekDays[i]
                        : 'Día ${i + 1}';

                    // Check if this day has cardio
                    // Check if this day has cardio
                    final dayNum = i + 1;

                    // UNIFIED LOGIC: Use Student Specific Cardio if available, otherwise fallback to routine
                    final cardioValue = cardioAsync.valueOrNull;
                    bool hasCardio = false;

                    if (cardioValue != null &&
                        (cardioValue['days'] as List).isNotEmpty) {
                      // If student has specific cardio config, use ONLY that (matches Dashboard & Banner)
                      final sDays = (cardioValue['days'] as List).cast<int>();
                      hasCardio = sDays.contains(dayNum);
                    } else {
                      // Only fallback to routine if student has NO specific config derived yet
                      // (Or if we want to show suggestions when student config is empty)
                      // User Request: "Unify logic". Dashboard shows nothing if empty.
                      // So if we have loaded student data and it's empty, we should probably show nothing?
                      // However, if we assume an empty student config means "Default to Routine", then:
                      // But the user had [1,2,4] and saw [5] from routine.
                      // So if we use student config [1,2,4], we check [1,2,4]. contains 5 -> false. Correct.

                      // What if cardioValue is null (loading)?
                      // We might fallback to routine just to show something, or wait.
                      if (cardioValue == null) {
                        final List<int> managedCardioDays = List<int>.from(
                          routine?['cardio_days'] ?? [],
                        );
                        hasCardio = managedCardioDays.contains(dayNum);
                      }
                    }

                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label),
                          if (hasCardio) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.directions_run,
                              size: 16,
                              color: AppColors.accent,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(days, (dayIndex) {
                    final dayNum = dayIndex + 1;
                    final dayExercises = exercises
                        .where((e) => e['day_number'] == dayNum)
                        .toList();

                    // Sort by order_index
                    dayExercises.sort(
                      (a, b) => (a['order_index'] as int).compareTo(
                        b['order_index'] as int,
                      ),
                    );

                    final currentWeekday = DateTime.now().weekday; // 1=Mon
                    final isToday = dayNum == currentWeekday;

                    return Consumer(
                      builder: (context, ref, _) {
                        final cardioAsync = ref.watch(myCardioProvider);
                        final lastSessionAsync = ref.watch(
                          lastSessionProvider((
                            routineId: routine['id'],
                            dayNumber: dayNum,
                          )),
                        );

                        return Column(
                          children: [
                            // Cardio Banner
                            cardioAsync.when(
                              data: (cardio) {
                                final days =
                                    (cardio['days'] as List?)?.cast<int>() ??
                                    [];
                                final description =
                                    cardio['description'] as String? ?? '';

                                if (days.contains(dayNum)) {
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.fromLTRB(
                                      16,
                                      16,
                                      16,
                                      0,
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFFF8F00),
                                          Color(0xFFFFD740),
                                        ], // Striking Orange-Yellow
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFFF8F00,
                                          ).withValues(alpha: 0.4),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.directions_run_rounded,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '¡DÍA DE CARDIO!',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                description.isNotEmpty
                                                    ? description
                                                    : 'Consulta a tu entrenador',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),

                            if (dayExercises.isEmpty)
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 40,
                                        color: Colors.grey.shade300,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Día de descanso',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: dayExercises.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    return _ExerciseCard(
                                      exerciseData: dayExercises[index],
                                      index: index,
                                      lastSession: lastSessionAsync.valueOrNull,
                                    );
                                  },
                                ),
                              ),

                            // Start workout button
                            if (dayExercises.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: isToday
                                        ? () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    WorkoutSessionScreen(
                                                      routine: routine,
                                                      exercises: dayExercises
                                                          .cast<
                                                            Map<String, dynamic>
                                                          >(),
                                                      dayNumber: dayNum,
                                                    ),
                                              ),
                                            );
                                          }
                                        : null,
                                    icon: isToday
                                        ? const Icon(Icons.play_arrow, size: 20)
                                        : const Icon(
                                            Icons.lock_clock,
                                            size: 20,
                                          ),
                                    label: Text(
                                      isToday
                                          ? 'Empezar Entrenamiento'
                                          : 'Disponible el día correspondiente',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isToday
                                          ? AppColors.success
                                          : Colors.grey,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exerciseData;
  final int index;
  final Map<String, dynamic>? lastSession;

  const _ExerciseCard({
    required this.exerciseData,
    this.index = 0,
    this.lastSession,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = exerciseData['exercises'] as Map<String, dynamic>;
    final name = exercise['name'] ?? 'Ejercicio';
    final sets = exerciseData['sets'] ?? 3;
    final repsRaw = exerciseData['reps_target']?.toString() ?? '10';
    final rest = exerciseData['rest_seconds'] ?? 60;
    final notes = exerciseData['comment'];
    final muscleGroup = exercise['muscle_group'] ?? '';

    // Note: History is now displayed via _ExerciseHistorySection widget

    // Process reps: show range if different values, single value if all same
    final repsList = repsRaw.contains('|')
        ? repsRaw.split('|').map((e) => e.trim()).toList()
        : [repsRaw];
    String displayReps;
    if (repsList.length > 1) {
      // Try to parse numeric values; if any contain '-' (like "10-12"), just show that
      final hasRange = repsList.any((r) => r.contains('-'));
      if (hasRange) {
        // Already contains ranges, just show first one or extract min-max
        displayReps = repsList.first;
      } else {
        final numericReps = repsList
            .map((r) => int.tryParse(r))
            .whereType<int>()
            .toList();
        if (numericReps.isNotEmpty) {
          final minRep = numericReps.reduce((a, b) => a < b ? a : b);
          final maxRep = numericReps.reduce((a, b) => a > b ? a : b);
          displayReps = minRep == maxRep ? '$minRep' : '$minRep-$maxRep';
        } else {
          displayReps = repsRaw; // Fallback to original
        }
      }
    } else {
      displayReps = repsRaw;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.surface.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative gradient blob
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Number badge - more prominent
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Exercise info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            if (muscleGroup.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  muscleGroup,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Stats row - horizontal with big values
                  Row(
                    children: [
                      _PremiumStatItem(
                        value: '$sets',
                        label: 'Series',
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 12),
                      _PremiumStatItem(
                        value: displayReps,
                        label: 'Reps',
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 12),
                      _PremiumStatItem(
                        value: '${rest}s',
                        label: 'Descanso',
                        color: AppColors.warning,
                      ),
                    ],
                  ),

                  if (lastSession != null) ...[
                    const SizedBox(height: 12),
                    _ExerciseHistorySection(
                      setLogs:
                          lastSession!['set_logs'] as Map<String, dynamic>?,
                      repsLogs:
                          lastSession!['reps_logs'] as Map<String, dynamic>?,
                      exerciseIndex: index,
                      targetReps:
                          int.tryParse(repsList.first.split('-').first) ?? 10,
                    ),
                  ],

                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: AppColors.warning.withOpacity(0.8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              notes,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.7),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // "Ver Video/Instrucciones" button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ExerciseDetailScreen(
                              exerciseData: exerciseData,
                              coachComment: notes,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 18,
                      ),
                      label: const Text('Ver Video / Instrucciones'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        side: BorderSide(
                          color: AppColors.primaryLight.withValues(alpha: 0.4),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumStatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _PremiumStatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget showing detailed history for each set of an exercise
class _ExerciseHistorySection extends StatelessWidget {
  final Map<String, dynamic>? setLogs;
  final Map<String, dynamic>? repsLogs;
  final int exerciseIndex;
  final int targetReps;

  const _ExerciseHistorySection({
    required this.setLogs,
    required this.repsLogs,
    required this.exerciseIndex,
    required this.targetReps,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseSetLogs =
        setLogs?[exerciseIndex.toString()] as Map<String, dynamic>?;
    final exerciseRepsLogs =
        repsLogs?[exerciseIndex.toString()] as Map<String, dynamic>?;

    if (exerciseSetLogs == null || exerciseSetLogs.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort sets by index
    final sortedSets = exerciseSetLogs.keys.toList()
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.05),
            Colors.white.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                size: 16,
                color: AppColors.accent.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'Última sesión',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Set rows
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sortedSets.map((setIndex) {
              final weight = exerciseSetLogs[setIndex];
              final reps = exerciseRepsLogs?[setIndex];
              final w = weight is int
                  ? weight.toDouble()
                  : (weight as num?)?.toDouble() ?? 0;
              final r = reps is int ? reps : (reps as num?)?.toInt() ?? 0;

              // Determine status: met target, exceeded, or below
              final bool metTarget = r >= targetReps;
              final Color statusColor = metTarget
                  ? AppColors.success
                  : AppColors.warning;

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'S${int.parse(setIndex) + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${w.toStringAsFixed(0)}kg',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'x$r',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                    if (metTarget) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.check_circle, size: 12, color: statusColor),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.6)),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
