import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import 'workout_session_screen.dart';


class StudentRoutineScreen extends ConsumerStatefulWidget {
  const StudentRoutineScreen({super.key});

  @override
  ConsumerState<StudentRoutineScreen> createState() => _StudentRoutineScreenState();
}

class _StudentRoutineScreenState extends ConsumerState<StudentRoutineScreen> with TickerProviderStateMixin {
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
              // Premium Routine Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Deep Gradient Background
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark.withValues(alpha: 0.8),
                                const Color(0xFF1E0B2E), // Deep purple finish
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      // Decorative Background Elements (Blobs)
                      Positioned(
                        top: -30,
                        right: -30,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -40,
                        left: 20,
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      
                      // Fitness Icon Watermark
                      Positioned(
                        bottom: -10,
                        right: 10,
                        child: Icon(
                          Icons.fitness_center_rounded,
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),

                      // Content
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: const Text(
                                'PLAN ACTIVO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              routine['title'] ?? 'Rutina Personalizada',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: Text(
                                routine['objective'] ?? 'Objetivo: General',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Glass-morphism border overlay
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

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
                    final weekDays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
                    final label = i < weekDays.length ? weekDays[i] : 'Día ${i + 1}';
                    
                    // Check if this day has cardio
                    // Check if this day has cardio
                    final dayNum = i + 1;
                    
                    // UNIFIED LOGIC: Use Student Specific Cardio if available, otherwise fallback to routine
                    final cardioValue = cardioAsync.valueOrNull;
                    bool hasCardio = false;

                    if (cardioValue != null && (cardioValue['days'] as List).isNotEmpty) {
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
                         final List<int> managedCardioDays = List<int>.from(routine?['cardio_days'] ?? []);
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
                            const Icon(Icons.directions_run, size: 16, color: AppColors.accent),
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
                    final dayExercises = exercises.where((e) => e['day_number'] == dayNum).toList();
                    
                    // Sort by order_index
                    dayExercises.sort((a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));

                    final currentWeekday = DateTime.now().weekday; // 1=Mon
                    final isToday = dayNum == currentWeekday;

                    return Consumer(
                      builder: (context, ref, _) {
                        final cardioAsync = ref.watch(myCardioProvider);
                        final lastSessionAsync = ref.watch(lastSessionProvider((
                          routineId: routine['id'],
                          dayNumber: dayNum,
                        )));
                        
                        return Column(
                          children: [
                            // Cardio Banner
                            cardioAsync.when(
                              data: (cardio) {
                                final days = (cardio['days'] as List?)?.cast<int>() ?? [];
                                final description = cardio['description'] as String? ?? '';
                                
                                if (days.contains(dayNum)) {
                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF8F00), Color(0xFFFFD740)], // Striking Orange-Yellow
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFFF8F00).withValues(alpha: 0.4),
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
                                            color: Colors.white.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.directions_run_rounded, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                                description.isNotEmpty ? description : 'Consulta a tu entrenador',
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
                                      Icon(Icons.fitness_center, size: 40, color: Colors.grey.shade300),
                                      const SizedBox(height: 12),
                                      const Text('Día de descanso', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                    ],
                                  ),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: dayExercises.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                                          onPressed: isToday ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => WorkoutSessionScreen(
                                              routine: routine,
                                              exercises: dayExercises.cast<Map<String, dynamic>>(),
                                              dayNumber: dayNum,
                                            ),
                                          ),
                                        );
                                    } : null,
                                    icon: isToday ? const Icon(Icons.play_arrow, size: 20) : const Icon(Icons.lock_clock, size: 20),
                                    label: Text(
                                      isToday ? 'Empezar Entrenamiento' : 'Disponible el día correspondiente',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isToday ? AppColors.success : Colors.grey,
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
                      }
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

    // Calculate max weight from history
    String? historyText;
    if (lastSession != null) {
      try {
        final setLogs = lastSession!['set_logs'] as Map<String, dynamic>?;
        if (setLogs != null) {
          final exerciseLog = setLogs[index.toString()] as Map<String, dynamic>?;
          if (exerciseLog != null && exerciseLog.isNotEmpty) {
             double maxWeight = 0;
             dynamic associatedReps = 0;
             
             exerciseLog.forEach((setIndex, weight) {
                final w = weight is int ? weight.toDouble() : weight as double;
                if (w > maxWeight) {
                   maxWeight = w;
                   final repsLogs = lastSession!['reps_logs'] as Map<String, dynamic>?;
                   associatedReps = repsLogs?[index.toString()]?[setIndex] ?? 0;
                }
             });
             
             if (maxWeight > 0) {
               historyText = '$maxWeight kg x $associatedReps';
             }
          }
        }
      } catch (e) {
        debugPrint('Error calculating history stats: $e');
      }
    }

    // Process reps: if it's "10|10|10", format it or keep it simple
    final repsList = repsRaw.contains('|') ? repsRaw.split('|') : [repsRaw];
    final isMultiSet = repsList.length > 1;
    final displayReps = isMultiSet ? repsList.join(' · ') : repsRaw;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16), // Slightly smaller radius
        border: Border.all(color: AppColors.primary.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with number badge and exercise name
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Number badge
              Container(
                width: 36, // Smaller badge
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Exercise info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16, // Slightly smaller
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (muscleGroup.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 5,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            muscleGroup,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Stats row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.layers_rounded,
                    value: '$sets',
                    label: 'Series',
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white10,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.repeat_rounded,
                    value: displayReps,
                    label: 'Reps',
                    color: AppColors.accent,
                    isCompact: isMultiSet,
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white10,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.timer_outlined,
                    value: '${rest}s',
                    label: 'Descanso',
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          
          if (historyText != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, size: 14, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text(
                    'Anterior (Max): ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                    ),
                  ),
                  Text(
                    historyText!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    size: 16,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  final bool isCompact;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color), // Smaller icon
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompact ? 13 : 14, // Smaller text
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10, // Smaller label
            color: Colors.white.withOpacity(0.5),
          ),
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
