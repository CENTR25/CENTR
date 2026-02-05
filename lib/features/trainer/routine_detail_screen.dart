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
    with TickerProviderStateMixin {
  TabController? _tabController;
  int _currentDay = 1;

  void _handleTabSelection() {
    if (mounted && _tabController != null) {
      setState(() => _currentDay = _tabController!.index + 1);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(routineDetailProvider(widget.routineId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineTitle),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Guardar como Plantilla',
            onPressed: () => _showSaveAsTemplateDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Asignar a alumnos',
            onPressed: () => _showAssignToStudents(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'edit') {
                 _showEditRoutineDetails(routineAsync.value!);
              } else if (value == 'delete') {
                _deleteRoutine();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Editar Detalles'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Eliminar Rutina'),
                    ],
                  ),
                ),
              ];
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
          
          if (_tabController == null || _tabController!.length != daysPerWeek) {
            final oldController = _tabController;
            _tabController = TabController(
              length: daysPerWeek, 
              vsync: this,
              initialIndex: (oldController != null && oldController.index < daysPerWeek) 
                  ? oldController.index 
                  : 0,
            );
            _tabController!.addListener(_handleTabSelection);
            if (oldController != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                oldController.removeListener(_handleTabSelection);
                oldController.dispose();
              });
            }
          }

          final exercises = routine['routine_exercises'] as List? ?? [];

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine['objective'] ?? 'Sin objetivo definido',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.trending_up_rounded,
                          label: routine['level'] ?? 'beginner',
                          color: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                        const SizedBox(width: 10),
                        _InfoChip(
                          icon: Icons.calendar_today_rounded,
                          label: '$daysPerWeek días/sem',
                          color: Colors.white,
                          backgroundColor: Colors.white.withOpacity(0.2),
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
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.accent,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.accent,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                tabs: List.generate(
                  daysPerWeek,
                  (index) {
                    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
                    return Tab(text: index < days.length ? days[index] : 'Día ${index + 1}');
                  },
                ),
              ),

              // Exercises List
              Expanded(
                child: TabBarView(
                  controller: _tabController!,
                  children: List.generate(daysPerWeek, (dayIndex) {
                    final dayNum = dayIndex + 1;
                    final dayExercises = exercises.where((e) => e['day_number'] == dayNum).cast<Map<String, dynamic>>().toList();
                    // Sort by order_index just in case
                    dayExercises.sort((a, b) => (a['order_index'] as int? ?? 0).compareTo(b['order_index'] as int? ?? 0));

                    final List<int> cardioDays = List<int>.from(routine['cardio_days'] ?? []);
                    final isCardioDay = cardioDays.contains(dayNum);

                    return Column(
                      children: [
                        // Cardio Switch
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isCardioDay ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.directions_run_rounded,
                                    color: isCardioDay ? AppColors.accent : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cardio para este día',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        isCardioDay ? 'Marcado como día con cardio' : 'Sin cardio marcado',
                                        style: TextStyle(
                                          color: AppColors.textLight,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: isCardioDay,
                                  onChanged: (val) => _toggleCardio(routine, dayNum, val),
                                  activeColor: AppColors.accent,
                                  activeTrackColor: AppColors.accent.withOpacity(0.4),
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (dayExercises.isEmpty)
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.fitness_center_rounded, size: 80, color: Colors.white.withOpacity(0.1)),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Sin ejercicios para este día',
                                    style: TextStyle(color: AppColors.textLight, fontSize: 16),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: () => _showAddExercise(context, dayNum),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Agregar ejercicio'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: ReorderableListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: dayExercises.length,
                              onReorder: (oldIndex, newIndex) => _onReorder(dayExercises, oldIndex, newIndex),
                              itemBuilder: (context, index) {
                                final exercise = dayExercises[index];
                                return _ExerciseCard(
                                  key: ValueKey(exercise['id']),
                                  exercise: exercise,
                                  onDelete: () => _deleteExercise(exercise['id']),
                                  onEdit: () => _showEditExercise(exercise),
                                );
                              },
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
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExercise(context, _currentDay),
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.primaryDark,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  void _showAssignToStudents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignToStudentsSheet(routineId: widget.routineId),
    );
  }

  void _onReorder(List<Map<String, dynamic>> exercises, int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = exercises.removeAt(oldIndex);
    exercises.insert(newIndex, item);
    
    try {
        final service = ref.read(trainerServiceProvider);
        for (int i = 0; i < exercises.length; i++) {
           final ex = exercises[i];
           if (ex['order_index'] != i) {
             await service.updateRoutineExercise(ex['id'], {'order_index': i});
           }
        }
        ref.invalidate(routineDetailProvider(widget.routineId));
    } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al reordenar: $e')));
    }
  }

  Future<void> _toggleCardio(Map<String, dynamic> routine, int dayNum, bool isActive) async {
    final List<int> cardioDays = List<int>.from(routine['cardio_days'] ?? []);
    
    if (isActive) {
      if (!cardioDays.contains(dayNum)) {
        cardioDays.add(dayNum);
      }
    } else {
      cardioDays.remove(dayNum);
    }

    try {
      final service = ref.read(trainerServiceProvider);
      await service.updateRoutine(widget.routineId, {
        'cardio_days': cardioDays,
      });
      ref.invalidate(routineDetailProvider(widget.routineId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar cardio: $e'), backgroundColor: AppColors.error),
        );
      }
    }
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


  void _showEditExercise(Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddExerciseSheet(
        routineId: widget.routineId,
        dayNumber: exercise['day_number'],
        existingExercise: exercise,
      ),
    );
  }

  void _showEditRoutineDetails(Map<String, dynamic> routine) {
    final titleController = TextEditingController(text: routine['title']);
    final objectiveController = TextEditingController(text: routine['objective']);
    String selectedLevel = routine['level'] ?? 'beginner';
    int selectedDays = routine['days_per_week'] ?? 3;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Editar Detalles de Rutina'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la rutina',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: objectiveController,
                  decoration: const InputDecoration(
                    labelText: 'Objetivo',
                    prefixIcon: Icon(Icons.track_changes),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedLevel,
                  decoration: const InputDecoration(
                    labelText: 'Nivel',
                    prefixIcon: Icon(Icons.trending_up),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'beginner', child: Text('Principiante')),
                    DropdownMenuItem(value: 'intermediate', child: Text('Intermedio')),
                    DropdownMenuItem(value: 'advanced', child: Text('Avanzado')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedLevel = val);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: selectedDays,
                  decoration: const InputDecoration(
                    labelText: 'Días por semana',
                    prefixIcon: Icon(Icons.calendar_month),
                  ),
                  items: List.generate(7, (index) => index + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d días')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDays = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty) return;

                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  final service = ref.read(trainerServiceProvider);
                  await service.updateRoutine(widget.routineId, {
                    'title': titleController.text.trim(),
                    'objective': objectiveController.text.trim(),
                    'level': selectedLevel,
                    'days_per_week': selectedDays,
                  });
                  
                  ref.invalidate(routineDetailProvider(widget.routineId));
                  ref.invalidate(myRoutinesProvider);

                  if (mounted) {
                    navigator.pop();
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Rutina actualizada con éxito'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSaveAsTemplateDialog(BuildContext context) {
    if (!widget.routineTitle.contains('(')) {
      // Just a heuristic: Usually student routines have the name in parenthesis or appended.
      // But trainers might want to clone their own templates too.
    }
    
    final controller = TextEditingController(text: '${widget.routineTitle} (Copia)');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guardar como Plantilla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Esta acción creará una nueva rutina en tu librería basada en esta configuración.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Nombre de la nueva plantilla',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              
              try {
                // Show loading
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Guardando plantilla...')),
                );
                
                final service = ref.read(trainerServiceProvider);
                await service.saveRoutineAsTemplate(
                  sourceRoutineId: widget.routineId,
                  newTitle: controller.text.trim(),
                );
                
                ref.invalidate(myRoutinesProvider); // Refresh dashboard list
                
                navigator.pop(); // Close dialog
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('¡Plantilla guardada con éxito!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRoutine() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar rutina'),
        content: const Text('¿Estás seguro de eliminar esta rutina? Esta acción no se puede deshacer.'),
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
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      
      try {
        final service = ref.read(trainerServiceProvider);
        await service.deleteRoutine(widget.routineId);
        
        // Refresh lists and stats
        ref.invalidate(myRoutinesProvider);
        ref.invalidate(trainerStatsProvider);
        
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Rutina eliminada'), backgroundColor: AppColors.success),
          );
          navigator.pop(); // Go back to dashboard
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
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
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      try {
        final service = ref.read(trainerServiceProvider);
        await service.removeExerciseFromRoutine(exerciseId);
        ref.invalidate(routineDetailProvider(widget.routineId));
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Ejercicio eliminado'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
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
  final Color? backgroundColor;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
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
  final VoidCallback onEdit;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final exerciseData = exercise['exercises'] as Map<String, dynamic>?;
    final name = exerciseData?['name'] ?? 'Ejercicio';
    final muscleGroup = exerciseData?['muscle_group'] ?? '';
    final sets = exercise['sets'] ?? 3;
    final repsTarget = exercise['reps_target'] ?? '10-12';
    final rest = exercise['rest_seconds'] ?? 60;
    final comment = exercise['comment'] as String?;

    // Parse reps for display
    String repsDisplay;
    if (repsTarget.toString().contains('|')) {
       final parts = repsTarget.toString().split('|');
       // If all are same, show one
       if (parts.every((r) => r == parts[0])) {
         repsDisplay = '$sets sets × ${parts[0]} reps';
       } else {
         repsDisplay = '$sets sets × Varias reps (${parts.join(", ")})';
       }
    } else {
       repsDisplay = '$sets sets × $repsTarget reps';
    }

    return Card(
      key: key,
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryDark],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '${(exercise['order_index'] as int? ?? 0) + 1}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                               Text(
                                 name, 
                                 style: const TextStyle(
                                   fontWeight: FontWeight.bold, 
                                   fontSize: 18,
                                   color: Colors.white,
                                 )
                               ),
                               Text(
                                 muscleGroup, 
                                 style: const TextStyle(
                                   color: AppColors.textLight, 
                                   fontSize: 13,
                                 )
                               ),
                           ]
                         )
                       ),
                       Icon(Icons.drag_indicator_rounded, color: Colors.white.withOpacity(0.2)),
                   ] 
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                      children: [
                          Expanded(child: _DetailIconInfo(icon: Icons.repeat_one_rounded, label: repsDisplay)),
                          const SizedBox(width: 16),
                          Expanded(child: _DetailIconInfo(icon: Icons.timer_outlined, label: '${rest}s descanso')),
                      ],
                  ),
                ),
                if (comment != null && comment.isNotEmpty) ...[
                    const Divider(height: 16),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            const Icon(Icons.comment_outlined, size: 16, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(child: Text(comment, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic))),
                        ],
                    )
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                      onPressed: onDelete, 
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error), 
                      label: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailIconInfo extends StatelessWidget {
    final IconData icon;
    final String label;
    
    const _DetailIconInfo({required this.icon, required this.label});
    
    @override
    Widget build(BuildContext context) {
        return Row(
           children: [
               Icon(icon, size: 18, color: AppColors.accent),
               const SizedBox(width: 6),
               Expanded(
                 child: Text(
                   label, 
                   style: const TextStyle(
                     color: Colors.white, 
                     fontSize: 14, 
                     fontWeight: FontWeight.w500,
                   ),
                   overflow: TextOverflow.ellipsis,
                 )
               ),
           ],
        );
    }
}

// Add/Edit Exercise Sheet
class _AddExerciseSheet extends ConsumerStatefulWidget {
  final String routineId;
  final int dayNumber;
  final Map<String, dynamic>? existingExercise;

  const _AddExerciseSheet({
    required this.routineId,
    required this.dayNumber,
    this.existingExercise,
  });

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
  String? _selectedExerciseId;
  int _sets = 3;
  bool _useSameReps = true;
  String _standardReps = '10-12';
  List<String> _individualReps = ['10', '10', '10'];
  int _rest = 60;
  String _comments = '';
  bool _isLoading = false;
  
  // Search state
  String _searchQuery = '';
  String? _selectedMuscleGroup;

  @override
  void initState() {
    super.initState();
    if (widget.existingExercise != null) {
      _initializeFromExisting();
    }
  }

  void _initializeFromExisting() {
    final ex = widget.existingExercise!;
    _selectedExerciseId = ex['exercise_id'];
    _sets = ex['sets'] ?? 3;
    _rest = ex['rest_seconds'] ?? 60;
    _comments = ex['comment'] ?? '';
    
    final repsTarget = ex['reps_target']?.toString() ?? '10-12';
    if (repsTarget.contains('|')) {
      _useSameReps = false;
      _individualReps = repsTarget.split('|');
      // Ensure specific list length matches sets
      if (_individualReps.length < _sets) {
        _individualReps.addAll(List.filled(_sets - _individualReps.length, '10'));
      }
    } else {
      _useSameReps = true;
      _standardReps = repsTarget;
      // Pre-fill individual just in case they toggle
      _individualReps = List.filled(_sets, repsTarget);
    }
  }

  void _updateSets(int newSets) {
    setState(() {
      _sets = newSets;
      // Adjust individual reps list size
      if (_individualReps.length < newSets) {
        _individualReps.addAll(List.filled(newSets - _individualReps.length, '10'));
      } else {
        _individualReps = _individualReps.sublist(0, newSets);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingExercise != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_rounded : Icons.add_rounded, 
                    color: AppColors.accent, 
                    size: 24
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isEditing ? 'Editar Ejercicio' : 'Agregar Ejercicio',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedExerciseId == null ? null : _saveExercise,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    disabledForegroundColor: Colors.grey,
                  ),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : Text(isEditing ? 'ACTUALIZAR' : 'GUARDAR', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Exercise Selection Section ---
                  // Only show current exercise info if editing, or allow changing it?
                  // Usually changing the exercise itself is rare, better to delete and add new.
                  // But for flexibility let's allow it, OR just lock it. 
                  // Let's allow searching/changing to match user flexibility request.
                  
                  const Text('1. Buscar Ejercicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 16),
                  
                  // Search Bar
                  TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.accent),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.03),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                  const SizedBox(height: 12),

                  // Muscle Group Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          selected: _selectedMuscleGroup == null,
                          onSelected: () => setState(() => _selectedMuscleGroup = null),
                        ),
                        ...['Pecho', 'Espalda', 'Piernas', 'Hombros', 'Brazos', 'Abdominales'].map((group) => 
                          _FilterChip(
                            label: group,
                            selected: _selectedMuscleGroup == group,
                            onSelected: () => setState(() => _selectedMuscleGroup = group),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Exercise List Box
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _ExerciseSelector(
                        selectedExerciseId: _selectedExerciseId,
                        searchQuery: _searchQuery,
                        muscleGroupFilter: _selectedMuscleGroup,
                        onSelect: (id) => setState(() => _selectedExerciseId = id),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text('2. Configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 20),

                  // Sets Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Series (Sets)'),
                      Text('$_sets', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Slider(
                    value: _sets.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    onChanged: (v) => _updateSets(v.round()),
                    activeColor: AppColors.primary,
                  ),

                  const SizedBox(height: 8),

                  // Reps Configuration Type
                  Row(
                    children: [
                      Checkbox(
                        value: _useSameReps,
                        activeColor: AppColors.primary,
                        onChanged: (val) => setState(() => _useSameReps = val ?? true),
                      ),
                      const Text('Mismas repeticiones para todas las series'),
                    ],
                  ),

                  // Reps Inputs
                  if (_useSameReps)
                    TextFormField(
                      initialValue: _standardReps,
                      decoration: const InputDecoration(
                        labelText: 'Repeticiones',
                        hintText: 'Ej: 10-12',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => _standardReps = v,
                    )
                  else
                    Column(
                      children: List.generate(_sets, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Text('Serie ${index + 1}:', style: const TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  // Use Key to force rebuild if individual reps change drastically
                                  key: ValueKey('rep_input_$index'), 
                                  initialValue: _individualReps.length > index ? _individualReps[index] : '',
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    hintText: 'Reps',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) {
                                    if (index < _individualReps.length) {
                                      _individualReps[index] = v;
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 24),

                  // Rest Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Descanso'),
                      Text('${_rest}s', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Slider(
                    value: _rest.toDouble(),
                    min: 30,
                    max: 180,
                    divisions: 15,
                    onChanged: (v) => setState(() => _rest = v.round()),
                  ),

                  const SizedBox(height: 16),

                  // Comments
                  TextFormField(
                    initialValue: _comments,
                    decoration: const InputDecoration(
                      labelText: 'Comentarios (Opcional)',
                      hintText: 'Ej: Controlar la excéntrica, pausa abajo...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment_outlined),
                    ),
                    onChanged: (v) => _comments = v,
                    minLines: 1,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 32),
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
      
      // Determine final reps string format
      // "12-15" (Standard) or "12|10|8|6" (Individual)
      String finalReps;
      if (_useSameReps) {
        finalReps = _standardReps;
      } else {
        finalReps = _individualReps.sublist(0, _sets).join('|');
      }

      if (widget.existingExercise != null) {
        // UPDATE
        await service.updateRoutineExercise(
          widget.existingExercise!['id'], 
          {
            'exercise_id': _selectedExerciseId,
            'sets': _sets,
            'reps_target': finalReps,
            'rest_seconds': _rest,
            'comment': _comments.isNotEmpty ? _comments : null,
          }
        );
      } else {
        // CREATE
        await service.addExerciseToRoutine(
          routineId: widget.routineId,
          exerciseId: _selectedExerciseId!,
          dayNumber: widget.dayNumber,
          sets: _sets,
          reps: finalReps,
          restTime: '${_rest}s',
          notes: _comments.isNotEmpty ? _comments : null,
        );
      }

      ref.invalidate(routineDetailProvider(widget.routineId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingExercise != null ? 'Ejercicio actualizado' : 'Ejercicio agregado'), 
            backgroundColor: AppColors.success
          ),
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        selectedColor: AppColors.primary.withOpacity(0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : Colors.black87,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// Exercise Selector Widget with Search & Filter
class _ExerciseSelector extends ConsumerWidget {
  final String? selectedExerciseId;
  final String searchQuery;
  final String? muscleGroupFilter;
  final Function(String) onSelect;

  const _ExerciseSelector({
    required this.selectedExerciseId,
    required this.searchQuery,
    required this.muscleGroupFilter,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return exercisesAsync.when(
      data: (exercises) {
        // Filter list locally
        final filtered = exercises.where((ex) {
          final name = (ex['name'] as String? ?? '').toLowerCase();
          final group = (ex['muscle_group'] as String? ?? '');
          
          final matchesSearch = name.contains(searchQuery.toLowerCase());
          final matchesGroup = muscleGroupFilter == null || group == muscleGroupFilter;
          
          return matchesSearch && matchesGroup;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Text('No se encontraron ejercicios', style: TextStyle(color: Colors.grey)),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final exercise = filtered[index];
            final isSelected = selectedExerciseId == exercise['id'];

            return ListTile(
              dense: true,
              selected: isSelected,
              selectedTileColor: AppColors.primary.withOpacity(0.1),
              leading: isSelected 
                ? const Icon(Icons.check_circle, color: AppColors.primary)
                : const Icon(Icons.circle_outlined, color: Colors.grey),
              title: Text(exercise['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(exercise['muscle_group'] ?? '', style: const TextStyle(fontSize: 12)),
              onTap: () => onSelect(exercise['id']),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// Provider for routine detail
final routineDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, routineId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getRoutine(routineId);
});

// Add this class at the end of the file
class _AssignToStudentsSheet extends ConsumerStatefulWidget {
  final String routineId;

  const _AssignToStudentsSheet({super.key, required this.routineId});

  @override
  ConsumerState<_AssignToStudentsSheet> createState() => _AssignToStudentsSheetState();
}

class _AssignToStudentsSheetState extends ConsumerState<_AssignToStudentsSheet> {
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(myStudentsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Asignar a Alumnos',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _selectedStudentIds.isEmpty || _isLoading ? null : _assign,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight))
                    : Text('ASIGNAR (${_selectedStudentIds.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 16),
                        Text('No tienes alumnos asignados', style: TextStyle(color: AppColors.textLight)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final profile = student['profiles'];
                    final name = profile?['name'] ?? 'Sin nombre';
                    final email = profile?['email'] ?? '';
                    final studentId = student['id'];
                    final isSelected = _selectedStudentIds.contains(studentId);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: CheckboxListTile(
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedStudentIds.add(studentId);
                            } else {
                              _selectedStudentIds.remove(studentId);
                            }
                          });
                        },
                        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(email, style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.15),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'A',
                            style: const TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.bold),
                          ),
                        ),
                        activeColor: AppColors.primaryLight,
                        checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, s) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assign() async {
    setState(() => _isLoading = true);
    try {
      final service = ref.read(trainerServiceProvider);
      await service.assignRoutineToMultipleStudents(
        athleteIds: _selectedStudentIds.toList(),
        routineId: widget.routineId,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rutina asignada a ${_selectedStudentIds.length} alumnos'),
            backgroundColor: AppColors.success,
          ),
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


