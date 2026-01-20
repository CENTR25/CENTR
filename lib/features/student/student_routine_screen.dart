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

class _StudentRoutineScreenState extends ConsumerState<StudentRoutineScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  
  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(activeRoutineProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mi Rutina')),
      body: routineAsync.when(
        data: (routine) {
          if (routine == null) {
            return const Center(child: Text('No tienes rutina activa'));
          }
          
          final exercises = (routine['routine_exercises'] as List?) ?? [];
          final days = (routine['days_per_week'] as int?) ?? 3;
          
          // Calculate today's workout day (Mon=0, Tue=1, etc, skip weekends)
          final weekday = DateTime.now().weekday; // 1=Mon, 7=Sun
          int todayIndex = 0;
          if (weekday >= 1 && weekday <= days) {
            todayIndex = weekday - 1; // Mon=0, Tue=1, etc
          } else if (weekday > days) {
            todayIndex = days - 1; // Show last training day on weekends
          }

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
              // Info Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                   gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine['title'] ?? 'Rutina',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Objetivo: ${routine['objective'] ?? 'General'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
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
                    return Tab(text: label);
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
                    // Assuming Day 1 maps to Monday (weekday 1)
                    final isToday = dayNum == currentWeekday;

                    if (dayExercises.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fitness_center, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('Día de descanso', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: dayExercises.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              return _ExerciseCard(
                                exerciseData: dayExercises[index],
                                index: index,
                              );
                            },
                          ),
                        ),
                        // Start workout button
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
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
                              icon: isToday ? const Icon(Icons.play_arrow) : const Icon(Icons.lock_clock),
                              label: Text(
                                isToday ? 'Empezar Entrenamiento' : 'Disponible el día correspondiente',
                                style: const TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isToday ? AppColors.success : Colors.grey,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  const _ExerciseCard({
    required this.exerciseData,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final exercise = exerciseData['exercises'] as Map<String, dynamic>;
    final name = exercise['name'] ?? 'Ejercicio';
    final sets = exerciseData['sets'] ?? 3;
    final reps = exerciseData['reps_target'] ?? '10';
    final rest = exerciseData['rest_seconds'] ?? 60;
    final notes = exerciseData['comment'];
    final muscleGroup = exercise['muscle_group'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with number badge and exercise name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Number badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (muscleGroup.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 6,
                            color: AppColors.primary.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            muscleGroup,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
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
          
          const SizedBox(height: 16),
          
          // Stats row
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
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
                  height: 36,
                  color: Colors.grey.shade200,
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.repeat_rounded,
                    value: '$reps',
                    label: 'Reps',
                    color: AppColors.accent,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.shade200,
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
          
          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.tips_and_updates_rounded,
                    size: 18,
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(
                        fontSize: 13,
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

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
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
