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
            icon: const Icon(Icons.save_as),
            tooltip: 'Guardar como Plantilla',
            onPressed: () => _showSaveAsTemplateDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Asignar a alumnos',
            onPressed: () => _showAssignToStudents(context),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edición de detalles próximamente')));
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
                      Icon(Icons.edit, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Editar Detalles'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
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
                    final dayExercises = exercises.where((e) => e['day_number'] == dayNum).cast<Map<String, dynamic>>().toList();
                    // Sort by order_index just in case
                    dayExercises.sort((a, b) => (a['order_index'] as int? ?? 0).compareTo(b['order_index'] as int? ?? 0));

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

                    return ReorderableListView.builder(
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
              
              Navigator.pop(context); // Close dialog
              
              try {
                // Show loading
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Guardando plantilla...')),
                  );
                }
                
                final service = ref.read(trainerServiceProvider);
                await service.saveRoutineAsTemplate(
                  sourceRoutineId: widget.routineId,
                  newTitle: controller.text.trim(),
                );
                
                ref.invalidate(myRoutinesProvider); // Refresh dashboard list
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('¡Plantilla guardada con éxito!'),
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
      try {
        final service = ref.read(trainerServiceProvider);
        await service.deleteRoutine(widget.routineId);
        
        // Refresh lists and stats
        ref.invalidate(myRoutinesProvider);
        ref.invalidate(trainerStatsProvider);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rutina eliminada'), backgroundColor: AppColors.success),
          );
          Navigator.pop(context); // Go back to dashboard
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            '${(exercise['order_index'] as int? ?? 0) + 1}',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                               Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               Text(muscleGroup, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                           ]
                         )
                       ),
                       Icon(Icons.drag_handle, color: Colors.grey.shade400),
                   ] 
                ),
                const SizedBox(height: 12),
                Row(
                    children: [
                        _DetailIconInfo(icon: Icons.repeat, label: repsDisplay),
                        const SizedBox(width: 16),
                        _DetailIconInfo(icon: Icons.timer_outlined, label: '${rest}s descanso'),
                    ],
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
               Icon(icon, size: 16, color: Colors.grey.shade600),
               const SizedBox(width: 4),
               Text(label, style: TextStyle(color: Colors.grey.shade800, fontSize: 13, fontWeight: FontWeight.w500)),
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
      height: MediaQuery.of(context).size.height * 0.85,
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
                    isEditing ? 'Editar Ejercicio' : 'Agregar ejercicio - Día ${widget.dayNumber}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedExerciseId == null ? null : _saveExercise,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEditing ? 'Actualizar' : 'Guardar'),
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
                  // --- Exercise Selection Section ---
                  // Only show current exercise info if editing, or allow changing it?
                  // Usually changing the exercise itself is rare, better to delete and add new.
                  // But for flexibility let's allow it, OR just lock it. 
                  // Let's allow searching/changing to match user flexibility request.
                  
                  const Text('1. Buscar Ejercicio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  
                  // Search Bar
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
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
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _ExerciseSelector(
                      selectedExerciseId: _selectedExerciseId,
                      searchQuery: _searchQuery,
                      muscleGroupFilter: _selectedMuscleGroup,
                      onSelect: (id) => setState(() => _selectedExerciseId = id),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Configuration Section ---
                  const Text('2. Configuración', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),

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
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Asignar Rutina',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: _selectedStudentIds.isEmpty || _isLoading ? null : _assign,
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Asignar (${_selectedStudentIds.length})'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return const Center(child: Text('No tienes alumnos asignados'));
                }
                return ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    final profile = student['profiles'];
                    final name = profile?['name'] ?? 'Sin nombre';
                    final email = profile?['email'] ?? '';
                    final studentId = student['id'];
                    final isSelected = _selectedStudentIds.contains(studentId);

                    return CheckboxListTile(
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
                      title: Text(name),
                      subtitle: Text(email),
                      secondary: CircleAvatar(
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A'),
                      ),
                      activeColor: AppColors.primary,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
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


