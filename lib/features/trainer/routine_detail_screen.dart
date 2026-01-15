import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trainer_service.dart';

class RoutineDetailScreen extends ConsumerStatefulWidget {
  final String routineId;
  final String routineTitle;

  const RoutineDetailScreen({
    super.key,
    required this.routineId,
    required this.routineTitle,
  });

  @override
  ConsumerState<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends ConsumerState<RoutineDetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _currentDay = 1;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(routineDetailProvider(widget.routineId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // TODO: Edit routine
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              // TODO: Delete routine with confirmation
            },
          ),
        ],
      ),
      body: routineAsync.when(
        data: (routine) {
          if (routine == null) {
            return const Center(child: Text('Rutina no encontrada'));
          }

          final daysPerWeek = routine['days_per_week'] ?? 3;
          
          // Initialize tab controller only once
          if (_tabController == null || _tabController!.length != daysPerWeek) {
            _tabController?.dispose();
            _tabController = TabController(length: daysPerWeek, vsync: this);
            _tabController!.addListener(() {
              setState(() => _currentDay = _tabController!.index + 1);
            });
          }

          final exercises = routine['routine_exercises'] as List? ?? [];

          return Column(
            children: [
              // Routine Info Card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine['objective'] ?? 'Sin objetivo definido',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.trending_up,
                          label: routine['level'] ?? 'beginner',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.calendar_today,
                          label: '$daysPerWeek días/sem',
                          color: AppColors.success,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Day Tabs
              TabBar(
                controller: _tabController!,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: List.generate(
                  daysPerWeek,
                  (index) => Tab(text: 'Día ${index + 1}'),
                ),
              ),

              // Exercises List
              Expanded(
                child: TabBarView(
                  controller: _tabController!,
                  children: List.generate(daysPerWeek, (dayIndex) {
                    final dayNum = dayIndex + 1;
                    final dayExercises = exercises.where((e) => e['day_number'] == dayNum).toList();

                    if (dayExercises.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                              'Sin ejercicios para este día',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddExercise(context, dayNum),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar ejercicio'),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: dayExercises.length,
                      itemBuilder: (context, index) {
                        final exercise = dayExercises[index];
                        return _ExerciseCard(
                          exercise: exercise,
                          onDelete: () => _deleteExercise(exercise['id']),
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
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExercise(context, _currentDay),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddExercise(BuildContext context, int dayNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExerciseSheet(
        routineId: widget.routineId,
        dayNumber: dayNumber,
      ),
    );
  }

  Future<void> _deleteExercise(String exerciseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: const Text('¿Estás seguro de eliminar este ejercicio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(trainerServiceProvider);
        await service.removeExerciseFromRoutine(exerciseId);
        ref.invalidate(routineDetailProvider(widget.routineId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ejercicio eliminado'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

// Info Chip Widget
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Exercise Card Widget
class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onDelete;

  const _ExerciseCard({
    required this.exercise,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseData = exercise['exercises'] as Map<String, dynamic>?;
    final name = exerciseData?['name'] ?? 'Ejercicio';
    final muscleGroup = exerciseData?['muscle_group'] ?? '';
    final sets = exercise['sets'] ?? 3;
    final reps = exercise['reps_target'] ?? '10-12';
    final rest = exercise['rest_seconds'] ?? 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text(
            '${exercise['order_index'] + 1}',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(muscleGroup, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(
              '$sets sets × $reps reps • ${rest}s descanso',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
          onPressed: onDelete,
        ),
        isThreeLine: true,
      ),
    );
  }
}

// Add Exercise Sheet
class _AddExerciseSheet extends ConsumerStatefulWidget {
  final String routineId;
  final int dayNumber;

  const _AddExerciseSheet({
    required this.routineId,
    required this.dayNumber,
  });

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
  String? _selectedExerciseId;
  int _sets = 3;
  String _reps = '10-12';
  int _rest = 60;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    'Agregar ejercicio - Día ${widget.dayNumber}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedExerciseId == null ? null : _saveExercise,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise Selector
                  const Text('Ejercicio', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _ExerciseSelector(
                    selectedExerciseId: _selectedExerciseId,
                    onSelect: (id) => setState(() => _selectedExerciseId = id),
                  ),

                  const SizedBox(height: 24),

                  // Sets
                  const Text('Sets', style: TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: _sets.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_sets sets',
                    onChanged: (v) => setState(() => _sets = v.round()),
                  ),
                  Center(child: Text('$_sets sets')),

                  const SizedBox(height: 16),

                  // Reps
                  const Text('Repeticiones', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _reps,
                    decoration: const InputDecoration(
                      hintText: 'Ej: 10-12 o 15',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => _reps = v,
                  ),

                  const SizedBox(height: 16),

                  // Rest
                  const Text('Descanso (segundos)', style: TextStyle(fontWeight: FontWeight.w600)),
                  Slider(
                    value: _rest.toDouble(),
                    min: 30,
                    max: 180,
                    divisions: 15,
                    label: '${_rest}s',
                    onChanged: (v) => setState(() => _rest = v.round()),
                  ),
                  Center(child: Text('$_rest segundos')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExercise() async {
    if (_selectedExerciseId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(trainerServiceProvider);
      await service.addExerciseToRoutine(
        routineId: widget.routineId,
        exerciseId: _selectedExerciseId!,
        dayNumber: widget.dayNumber,
        sets: _sets,
        reps: _reps,
        restTime: '${_rest}s',
      );

      ref.invalidate(routineDetailProvider(widget.routineId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ejercicio agregado'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// Exercise Selector Widget
class _ExerciseSelector extends ConsumerWidget {
  final String? selectedExerciseId;
  final Function(String) onSelect;

  const _ExerciseSelector({
    required this.selectedExerciseId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return exercisesAsync.when(
      data: (exercises) {
        if (exercises.isEmpty) {
          return const Text('No hay ejercicios disponibles');
        }

        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              final isSelected = selectedExerciseId == exercise['id'];

              return ListTile(
                selected: isSelected,
                selectedTileColor: AppColors.primary.withOpacity(0.1),
                leading: Radio<String>(
                  value: exercise['id'],
                  groupValue: selectedExerciseId,
                  onChanged: (id) => id != null ? onSelect(id) : null,
                ),
                title: Text(exercise['name'] ?? ''),
                subtitle: Text(exercise['muscle_group'] ?? ''),
                onTap: () => onSelect(exercise['id']),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

// Provider for routine detail
final routineDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, routineId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getRoutine(routineId);
});
