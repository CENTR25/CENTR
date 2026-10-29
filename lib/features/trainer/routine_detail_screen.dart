import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../core/utils/string_utils.dart';
import '../../../models/exercise_model.dart';
import '../../../services/exercise_media_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/trainer_service.dart';
import '../../../widgets/exercise_gif_view.dart';
import '../shared/redesign_toast.dart';
import 'package:north_star/utils/exercise_category.dart';

// ---------------------------------------------------------------------------
// Day names used for the pill selector (L M X J V S D).
// ---------------------------------------------------------------------------
const _kDayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
const _kDayNames = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

// ---------------------------------------------------------------------------
// RoutineDetailScreen
// ---------------------------------------------------------------------------

class RoutineDetailScreen extends ConsumerStatefulWidget {
  final String routineId;
  final String routineTitle;

  const RoutineDetailScreen({
    super.key,
    required this.routineId,
    required this.routineTitle,
  });

  @override
  ConsumerState<RoutineDetailScreen> createState() =>
      _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends ConsumerState<RoutineDetailScreen>
    with TickerProviderStateMixin {
  // Day selection state — replaces the TabController-based approach while
  // keeping all per-day content switching logic intact.
  int _currentDay = 1; // 1-based, matching day_number in DB
  int _defaultRest = 60;

  @override
  void initState() {
    super.initState();
    _loadDefaultRest();
  }

  Future<void> _loadDefaultRest() async {
    final rest = await ref.read(trainerServiceProvider).getDefaultRestSeconds();
    if (mounted) setState(() => _defaultRest = rest);
  }

  @override
  Widget build(BuildContext context) {
    final routineAsync = ref.watch(routineDetailProvider(widget.routineId));

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.routineTitle,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Rutina',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario400),
              ),
            ],
          ),
          centerTitle: true,
          actions: [
            // Assign-to-students circular button
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => _showAssignToStudents(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario700,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RedesignColors.secundario300
                          .withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: RedesignColors.actionPrimary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: routineAsync.when(
          data: (routine) {
            if (routine == null) {
              return const Center(
                child: Text(
                  'Rutina no encontrada',
                  style: TextStyle(color: RedesignColors.primario300),
                ),
              );
            }

            final daysPerWeek = (routine['days_per_week'] as int?) ?? 3;

            // Clamp selected day if daysPerWeek changes
            if (_currentDay > daysPerWeek) {
              WidgetsBinding.instance.addPostFrameCallback(
                  (_) => setState(() => _currentDay = 1));
            }

            final exercises = routine['routine_exercises'] as List? ?? [];

            // Per-day exercise list for the currently selected day
            final dayExercises = exercises
                .where((e) => e['day_number'] == _currentDay)
                .cast<Map<String, dynamic>>()
                .toList()
              ..sort((a, b) => (a['order_index'] as int? ?? 0)
                  .compareTo(b['order_index'] as int? ?? 0));

            final List<int> cardioDays =
                List<int>.from(routine['cardio_days'] ?? []);
            final isCardioDay = cardioDays.contains(_currentDay);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Info card ────────────────────────────────────────────
                _RoutineInfoCard(
                  routine: routine,
                  onEditTap: () => _showEditRoutineDetails(routine),
                  onAssignTap: () => _showAssignToStudents(context),
                ),

                // ── Day pill selector ────────────────────────────────────
                _DayPillSelector(
                  daysPerWeek: daysPerWeek,
                  selectedDay: _currentDay,
                  onDaySelected: (day) => setState(() => _currentDay = day),
                ),

                // ── Per-day content ──────────────────────────────────────
                Expanded(
                  child: Column(
                    children: [
                      // Day header row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                        child: Row(
                          children: [
                            Text(
                              _dayName(_currentDay),
                              style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.primario50,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () =>
                                  _showAddExercise(context, _currentDay),
                              style: TextButton.styleFrom(
                                foregroundColor: RedesignColors.actionPrimary,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Agregar ejercicio',
                                style: RedesignType.buttonSm.copyWith(
                                  color: RedesignColors.actionPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Cardio toggle
                      _CardioBanner(
                        isCardioDay: isCardioDay,
                        onChanged: (val) =>
                            _toggleCardio(routine, _currentDay, val),
                      ),

                      // Exercise list or empty state
                      Expanded(
                        child: dayExercises.isEmpty
                            ? _EmptyDayState(
                                onAddTap: () =>
                                    _showAddExercise(context, _currentDay),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 8, 16, 100),
                                itemCount: dayExercises.length,
                                // ignore: deprecated_member_use
                                onReorder: (oldIndex, newIndex) =>
                                    _onReorder(
                                        dayExercises, oldIndex, newIndex),
                                itemBuilder: (context, index) {
                                  final exercise = dayExercises[index];
                                  return _ExerciseCard(
                                    key: ValueKey(exercise['id']),
                                    exercise: exercise,
                                    onDelete: () =>
                                        _deleteExercise(exercise['id']),
                                    onEdit: () =>
                                        _showEditExercise(exercise),
                                    onDuplicate: () =>
                                        _duplicateExercise(exercise),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) =>
              Center(child: Text('Error: $error')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddExercise(context, _currentDay),
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          elevation: 0,
          shape: const CircleBorder(),
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _dayName(int day) {
    final idx = (day - 1).clamp(0, _kDayNames.length - 1);
    return _kDayNames[idx];
  }

  void _showAssignToStudents(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _AssignToStudentsSheet(routineId: widget.routineId),
    );
  }

  void _onReorder(
    List<Map<String, dynamic>> exercises,
    int oldIndex,
    int newIndex,
  ) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al reordenar: $e')));
      }
    }
  }

  Future<void> _toggleCardio(
    Map<String, dynamic> routine,
    int dayNum,
    bool isActive,
  ) async {
    final List<int> cardioDays =
        List<int>.from(routine['cardio_days'] ?? []);

    if (isActive) {
      if (!cardioDays.contains(dayNum)) cardioDays.add(dayNum);
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
          SnackBar(
            content: Text('Error al actualizar cardio: $e'),
            backgroundColor: RedesignColors.danger,
          ),
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
        defaultRest: _defaultRest,
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditRoutineSheet(
        routineId: widget.routineId,
        routine: routine,
        onRoutineUpdated: () {
          ref.invalidate(routineDetailProvider(widget.routineId));
          ref.invalidate(myRoutinesProvider);
        },
        onRoutineDeleted: () {
          ref.invalidate(myRoutinesProvider);
          ref.invalidate(trainerStatsProvider);
          Navigator.of(context).pop(); // exit detail screen
        },
        onSaveAsTemplate: () => _showSaveAsTemplateDialog(context),
      ),
    );
  }

  void _showSaveAsTemplateDialog(BuildContext context) {
    final controller = TextEditingController(
      text: '${widget.routineTitle} (Copia)',
    );

    showDialog(
      context: context,
      builder: (context) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RedesignRadius.card)),
          title: Text(
            'Guardar como Plantilla',
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se creará una nueva rutina en tu librería basada en esta configuración.',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: const TextStyle(color: RedesignColors.primario50),
                decoration: InputDecoration(
                  labelText: 'Nombre de la nueva plantilla',
                  border: OutlineInputBorder(
                      borderRadius: RedesignRadius.inputBr),
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar',
                  style: TextStyle(color: RedesignColors.primario300)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                final scaffoldMessenger =
                    ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);

                try {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                        content: Text('Guardando plantilla...')),
                  );
                  final service = ref.read(trainerServiceProvider);
                  await service.saveRoutineAsTemplate(
                    sourceRoutineId: widget.routineId,
                    newTitle: controller.text.trim(),
                  );
                  ref.invalidate(myRoutinesProvider);
                  navigator.pop();
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content:
                          const Text('Plantilla guardada con éxito'),
                      backgroundColor: RedesignColors.success,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: RedesignColors.danger,
                    ),
                  );
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteExercise(String exerciseId) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RedesignRadius.card)),
          title: Text('Eliminar ejercicio',
              style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700)),
          content: Text(
            '¿Estás seguro de eliminar este ejercicio?',
            style:
                RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar',
                  style: TextStyle(color: RedesignColors.primario300)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style:
                  TextButton.styleFrom(foregroundColor: RedesignColors.danger),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(trainerServiceProvider);
        await service.removeExerciseFromRoutine(exerciseId);
        ref.invalidate(routineDetailProvider(widget.routineId));
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: const Text('Ejercicio eliminado'),
              backgroundColor: RedesignColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: RedesignColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _duplicateExercise(Map<String, dynamic> exercise) async {
    try {
      final service = ref.read(trainerServiceProvider);
      final repsTarget = exercise['reps_target']?.toString() ?? '10-12';
      final weightTarget = exercise['weight_target'] as String?;
      await service.addExerciseToRoutine(
        routineId: widget.routineId,
        exerciseId: exercise['exercise_id'] as String,
        dayNumber: exercise['day_number'] as int,
        sets: exercise['sets'] ?? 3,
        reps: repsTarget,
        restTime: '${exercise['rest_seconds'] ?? 60}s',
        notes: exercise['comment'] as String?,
        weightTarget: weightTarget,
      );
      ref.invalidate(routineDetailProvider(widget.routineId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al duplicar: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// _RoutineInfoCard — rounded navy info card with objective, days, edit & assign
// ---------------------------------------------------------------------------
class _RoutineInfoCard extends StatelessWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onEditTap;
  final VoidCallback onAssignTap;

  const _RoutineInfoCard({
    required this.routine,
    required this.onEditTap,
    required this.onAssignTap,
  });

  @override
  Widget build(BuildContext context) {
    final objective = routine['objective'] as String?;
    final daysPerWeek = (routine['days_per_week'] as int?) ?? 3;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: RedesignRadius.cardBr,
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  objective?.isNotEmpty == true
                      ? objective!
                      : 'Sin objetivo definido',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onEditTap,
                child: Text(
                  'Editar',
                  style: RedesignType.buttonSm.copyWith(
                    color: RedesignColors.actionPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$daysPerWeek días por semana',
            style: RedesignType.label.copyWith(color: RedesignColors.primario400),
          ),
          Divider(
            height: 24,
            color: RedesignColors.primario600,
          ),
          Row(
            children: [
              Expanded(
                child: Builder(builder: (_) {
                  final athleteRoutines =
                      routine['athlete_routines'] as List? ?? [];
                  final activeNames = athleteRoutines
                      .where((ar) => ar['is_active'] == true)
                      .map((ar) {
                        final ath = ar['athletes'] as Map<String, dynamic>?;
                        return ath?['name'] as String? ?? '';
                      })
                      .where((n) => n.isNotEmpty)
                      .toList();
                  final label = activeNames.isEmpty
                      ? 'Sin asignar'
                      : 'Asignada a ${activeNames.join(', ')}';
                  return Text(
                    label,
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onAssignTap,
                child: Text(
                  'Asignar',
                  style: RedesignType.buttonSm.copyWith(
                    color: RedesignColors.actionPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DayPillSelector — pill row L M X J V S D
// ---------------------------------------------------------------------------
class _DayPillSelector extends StatelessWidget {
  final int daysPerWeek;
  final int selectedDay; // 1-based
  final ValueChanged<int> onDaySelected;

  const _DayPillSelector({
    required this.daysPerWeek,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: daysPerWeek,
        itemBuilder: (context, index) {
          final day = index + 1;
          final isSelected = day == selectedDay;
          final label = index < _kDayLabels.length ? _kDayLabels[index] : 'D$day';
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onDaySelected(day),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? RedesignColors.secundario300
                      : RedesignColors.secundario300.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(RedesignRadius.buttonSm),
                  border: Border.all(
                    color: RedesignColors.secundario300
                        .withValues(alpha: isSelected ? 1 : 0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: RedesignType.buttonSm.copyWith(
                    color: isSelected
                        ? RedesignColors.secundario900
                        : RedesignColors.secundario300,
                    fontWeight: FontWeight.w700,
                  ),
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
// _CardioBanner — cardio toggle row
// ---------------------------------------------------------------------------
class _CardioBanner extends StatelessWidget {
  final bool isCardioDay;
  final ValueChanged<bool> onChanged;

  const _CardioBanner({required this.isCardioDay, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: RedesignColors.primario800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCardioDay
                ? RedesignColors.actionPrimary.withValues(alpha: 0.4)
                : RedesignColors.secundario300.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCardioDay
                    ? RedesignColors.actionPrimary.withValues(alpha: 0.18)
                    : RedesignColors.primario700,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_run_rounded,
                color: isCardioDay
                    ? RedesignColors.actionPrimary
                    : RedesignColors.primario400,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cardio para este día',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    isCardioDay
                        ? 'Marcado como día con cardio'
                        : 'Sin cardio marcado',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario400),
                  ),
                ],
              ),
            ),
            Switch(
              value: isCardioDay,
              onChanged: onChanged,
              activeThumbColor: RedesignColors.onActionPrimary,
              activeTrackColor: RedesignColors.actionPrimary,
              inactiveThumbColor: RedesignColors.primario400,
              inactiveTrackColor:
                  RedesignColors.primario600.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyDayState
// ---------------------------------------------------------------------------
class _EmptyDayState extends StatelessWidget {
  final VoidCallback onAddTap;
  const _EmptyDayState({required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 64,
            color: RedesignColors.primario50.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin ejercicios para este día',
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario400),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Agregar ejercicio'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _InfoChip — small stat chip (kept for internal use)
// ---------------------------------------------------------------------------
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: RedesignColors.actionPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
        border: Border.all(
          color: RedesignColors.actionPrimary.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: RedesignColors.actionPrimary),
          const SizedBox(width: 5),
          Text(
            label,
            style: RedesignType.buttonSm.copyWith(
              color: RedesignColors.actionPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ExerciseCard
// ---------------------------------------------------------------------------
class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;

  const _ExerciseCard({
    super.key,
    required this.exercise,
    required this.onDelete,
    required this.onEdit,
    required this.onDuplicate,
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
    String setsDisplay;
    String repsDisplay;
    if (repsTarget.toString().contains('|')) {
      final parts = repsTarget.toString().split('|');
      if (parts.every((r) => r == parts[0])) {
        setsDisplay = '$sets series';
        repsDisplay = '${parts[0]} reps';
      } else {
        setsDisplay = '$sets series';
        repsDisplay = 'Varias reps';
      }
    } else {
      setsDisplay = '$sets series';
      repsDisplay = '$repsTarget reps';
    }

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.14),
        ),
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
                  // Order badge
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          RedesignColors.actionPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${(exercise['order_index'] as int? ?? 0) + 1}',
                      style: RedesignType.buttonSm.copyWith(
                        color: RedesignColors.actionPrimary,
                        fontWeight: FontWeight.w700,
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
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (muscleGroup.isNotEmpty)
                          Text(
                            muscleGroup,
                            style: RedesignType.label
                                .copyWith(color: RedesignColors.primario400),
                          ),
                      ],
                    ),
                  ),
                  // Overflow menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      color: RedesignColors.primario400,
                      size: 20,
                    ),
                    color: RedesignColors.primario800,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(RedesignRadius.card)),
                    onSelected: (value) {
                      if (value == 'edit') onEdit();
                      if (value == 'duplicate') onDuplicate();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            const Icon(Icons.edit_rounded,
                                color: RedesignColors.actionPrimary, size: 18),
                            const SizedBox(width: 8),
                            Text('Editar',
                                style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.primario50)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: Row(
                          children: [
                            const Icon(Icons.copy_all_rounded,
                                color: RedesignColors.actionPrimary, size: 18),
                            const SizedBox(width: 8),
                            Text('Duplicar',
                                style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.primario50)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded,
                                color: RedesignColors.danger, size: 18),
                            const SizedBox(width: 8),
                            Text('Eliminar',
                                style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      color: RedesignColors.primario50.withValues(alpha: 0.18),
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stat chips row
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoChip(icon: Icons.layers_rounded, label: setsDisplay),
                  _InfoChip(icon: Icons.repeat_one_rounded, label: repsDisplay),
                  _InfoChip(
                      icon: Icons.timer_outlined, label: '${rest}s descanso'),
                ],
              ),
              // Comment
              if (comment != null && comment.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color:
                        RedesignColors.primario700.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.comment_outlined,
                          size: 14,
                          color: RedesignColors.primario400),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          comment,
                          style: RedesignType.label.copyWith(
                            color: RedesignColors.primario300,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// _EditRoutineSheet — Figma screen 4: Editar rutina
// ---------------------------------------------------------------------------
class _EditRoutineSheet extends ConsumerStatefulWidget {
  final String routineId;
  final Map<String, dynamic> routine;
  final VoidCallback onRoutineUpdated;
  final VoidCallback onRoutineDeleted;
  final VoidCallback onSaveAsTemplate;

  const _EditRoutineSheet({
    required this.routineId,
    required this.routine,
    required this.onRoutineUpdated,
    required this.onRoutineDeleted,
    required this.onSaveAsTemplate,
  });

  @override
  ConsumerState<_EditRoutineSheet> createState() => _EditRoutineSheetState();
}

class _EditRoutineSheetState extends ConsumerState<_EditRoutineSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _objectiveController;
  late int _selectedDays;
  late String _level;
  String? _imageUrl;
  Uint8List? _pickedImageBytes;
  String _pickedImageExt = 'jpg';
  bool _isSaving = false;
  bool _isDeleting = false;

  static const _levelOptions = [
    ('Principiante', 'beginner'),
    ('Intermedio', 'intermediate'),
    ('Avanzado', 'advanced'),
  ];

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.routine['title'] ?? '');
    _objectiveController =
        TextEditingController(text: widget.routine['objective'] ?? '');
    _selectedDays = (widget.routine['days_per_week'] as int?) ?? 3;
    _level = (widget.routine['level'] as String?) ?? 'beginner';
    _imageUrl = widget.routine['image_url'] as String?;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RedesignSheet(
      children: [
        // Header
        Text(
          'Editar rutina',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.routine['title'] ?? '',
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario400),
        ),
        const SizedBox(height: 24),

        // Añadir foto
        _buildPhotoBox(),
        const SizedBox(height: 20),

        // Nombre
        Text(
          'Nombre',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _titleController,
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'Nombre de la rutina',
          ),
        ),
        const SizedBox(height: 16),

        // Objetivo
        Text(
          'Objetivo',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _objectiveController,
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Ej: Ganar masa muscular, perder peso...',
          ),
        ),
        const SizedBox(height: 20),

        // Días por semana pills
        Text(
          'Días por semana',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final d = index + 1;
            final selected = d == _selectedDays;
            return GestureDetector(
              onTap: () => setState(() => _selectedDays = d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? RedesignColors.secundario300
                      : RedesignColors.secundario300.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(RedesignRadius.buttonSm),
                  border: Border.all(
                    color: RedesignColors.secundario300
                        .withValues(alpha: selected ? 1 : 0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '$d',
                  style: RedesignType.buttonSm.copyWith(
                    color: selected
                        ? RedesignColors.secundario900
                        : RedesignColors.secundario300,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        // Nivel
        Text(
          'Nivel',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _levelOptions.map((opt) {
            final (label, value) = opt;
            final selected = _level == value;
            return GestureDetector(
              onTap: () => setState(() => _level = value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? RedesignColors.secundario300
                      : RedesignColors.secundario300
                          .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(RedesignRadius.buttonSm),
                  border: Border.all(
                    color: RedesignColors.secundario300
                        .withValues(alpha: selected ? 1 : 0.4),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  label,
                  style: RedesignType.buttonSm.copyWith(
                    color: selected
                        ? RedesignColors.secundario900
                        : RedesignColors.secundario300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Duplicar rutina row
        _ActionRow(
          icon: Icons.copy_rounded,
          label: 'Duplicar rutina',
          color: RedesignColors.primario50,
          onTap: () {
            Navigator.pop(context);
            widget.onSaveAsTemplate();
          },
        ),
        const Divider(height: 1, color: RedesignColors.primario700),

        // Eliminar rutina row
        _ActionRow(
          icon: Icons.delete_outline_rounded,
          label: 'Eliminar rutina',
          color: RedesignColors.danger,
          trailing: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: RedesignColors.danger,
                  ),
                )
              : null,
          onTap: _isDeleting ? null : _confirmDelete,
        ),
        const SizedBox(height: 24),

        // Guardar cambios button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary,
                    ),
                  )
                : const Text('Guardar cambios'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExt = ext;
    });
  }

  Widget _buildPhotoBox() {
    final hasExistingImage =
        (_imageUrl?.isNotEmpty ?? false) && _pickedImageBytes == null;
    final hasPicked = _pickedImageBytes != null;

    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: RedesignColors.primario800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.3),
            width: 1.5,
            // dashed effect via strokeAlign — Flutter doesn't support native
            // dashed borders, so we use a semi-transparent solid which is
            // consistent with the card style.
          ),
        ),
        clipBehavior: Clip.hardEdge,
        child: hasExistingImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    _imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: RedesignColors.primario500, size: 32),
                    ),
                  ),
                  Container(
                    color: RedesignColors.primario900.withValues(alpha: 0.45),
                    alignment: Alignment.center,
                    child: const Icon(Icons.edit_rounded,
                        color: RedesignColors.primario50, size: 28),
                  ),
                ],
              )
            : hasPicked
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        _pickedImageBytes!,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        color:
                            RedesignColors.primario900.withValues(alpha: 0.45),
                        alignment: Alignment.center,
                        child: const Icon(Icons.edit_rounded,
                            color: RedesignColors.primario50, size: 28),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: RedesignColors.secundario300
                            .withValues(alpha: 0.6),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Añadir foto',
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.secundario300
                              .withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isSaving = true);
    final nav = Navigator.of(context);
    final overlay = Overlay.of(context);

    try {
      final service = ref.read(trainerServiceProvider);

      // Upload new image if picked
      String? finalImageUrl = _imageUrl;
      if (_pickedImageBytes != null) {
        final userId = service.currentUserId ?? '';
        finalImageUrl = await ref
            .read(storageServiceProvider)
            .uploadRoutineImageBytes(
                _pickedImageBytes!, _pickedImageExt, userId);
      }

      await service.updateRoutine(widget.routineId, {
        'title': _titleController.text.trim(),
        'objective': _objectiveController.text.trim(),
        'days_per_week': _selectedDays,
        'level': _level,
        if (finalImageUrl != null) 'image_url': finalImageUrl,
      });
      widget.onRoutineUpdated();
      if (nav.mounted) nav.pop();
      // overlay.context belongs to the scaffold ancestor which outlives the
      // sheet — safe to use after pop.
      final toastCtx = overlay.context; // ignore: use_build_context_synchronously
      showRedesignToast(toastCtx, title: '¡Guardado exitosamente!', subtitle: 'Se han guardado los cambios'); // ignore: use_build_context_synchronously
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RedesignRadius.card)),
          title: Text(
            'Eliminar rutina',
            style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700),
          ),
          content: Text(
            '¿Estás seguro de eliminar esta rutina? Esta acción no se puede deshacer.',
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: TextStyle(color: RedesignColors.primario300)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  TextButton.styleFrom(foregroundColor: RedesignColors.danger),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    setState(() => _isDeleting = true);

    try {
      final service = ref.read(trainerServiceProvider);
      await service.deleteRoutine(widget.routineId);
      if (mounted) {
        Navigator.of(context).pop(); // close sheet
        widget.onRoutineDeleted(); // pops detail screen
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: const Text('Rutina eliminada'),
            backgroundColor: RedesignColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
        setState(() => _isDeleting = false);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// _ActionRow — icon + label row used in _EditRoutineSheet
// ---------------------------------------------------------------------------
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style:
                    RedesignType.bodySm.copyWith(color: color),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RedesignSheet — navy→teal gradient bottom sheet (matches dashboard pattern)
// ---------------------------------------------------------------------------
class _RedesignSheet extends StatelessWidget {
  final List<Widget> children;

  const _RedesignSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RedesignColors.primario900,
              RedesignColors.secundario900,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          RedesignColors.primario50.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Close button
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded,
                          color: RedesignColors.primario300, size: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AddExerciseSheet — 2-step exercise picker + config (Figma screens 2 & 3)
// ---------------------------------------------------------------------------
class _AddExerciseSheet extends ConsumerStatefulWidget {
  final String routineId;
  final int dayNumber;
  final Map<String, dynamic>? existingExercise;
  final int defaultRest;

  const _AddExerciseSheet({
    required this.routineId,
    required this.dayNumber,
    this.existingExercise,
    this.defaultRest = 60,
  });

  @override
  ConsumerState<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends ConsumerState<_AddExerciseSheet> {
  // Step: 0 = exercise picker, 1 = config
  int _step = 0;

  String? _selectedExerciseId;
  String? _selectedExerciseName;
  String? _selectedExerciseMuscle;

  int _sets = 3;
  bool _useSameReps = true;
  String _standardReps = '10-12';
  List<String> _individualReps = ['10', '10', '10'];
  // Weight state (per-set follows _useSameReps toggle)
  String _standardWeight = '';
  List<String> _individualWeights = ['', '', ''];
  late int _rest = widget.defaultRest;
  String _comments = '';
  bool _isLoading = false;

  // Search/filter state (step 0)
  String _searchQuery = '';
  String? _selectedMuscleGroup;

  @override
  void initState() {
    super.initState();
    if (widget.existingExercise != null) {
      _initializeFromExisting();
      // Start directly at config step when editing
      _step = 1;
    }
  }

  void _initializeFromExisting() {
    final ex = widget.existingExercise!;
    _selectedExerciseId = ex['exercise_id'];

    final exerciseData = ex['exercises'] as Map<String, dynamic>?;
    _selectedExerciseName = exerciseData?['name'] ?? 'Ejercicio';
    _selectedExerciseMuscle = exerciseData?['muscle_group'] ?? '';

    _sets = ex['sets'] ?? 3;
    _rest = ex['rest_seconds'] ?? widget.defaultRest;
    _comments = ex['comment'] ?? '';

    final repsTarget = ex['reps_target']?.toString() ?? '10-12';
    if (repsTarget.contains('|')) {
      _useSameReps = false;
      _individualReps = repsTarget.split('|');
      if (_individualReps.length < _sets) {
        _individualReps
            .addAll(List.filled(_sets - _individualReps.length, '10'));
      }
    } else {
      _useSameReps = true;
      _standardReps = repsTarget;
      _individualReps = List.filled(_sets, repsTarget);
    }

    // Weight target (per-set follows same reps toggle)
    final weightTarget = ex['weight_target']?.toString() ?? '';
    if (weightTarget.contains('|')) {
      _individualWeights = weightTarget.split('|');
      if (_individualWeights.length < _sets) {
        _individualWeights
            .addAll(List.filled(_sets - _individualWeights.length, ''));
      }
    } else {
      _standardWeight = weightTarget;
      _individualWeights = List.filled(_sets, weightTarget);
    }
  }

  void _updateSets(int newSets) {
    setState(() {
      _sets = newSets;
      if (_individualReps.length < newSets) {
        _individualReps.addAll(
            List.filled(newSets - _individualReps.length, '10'));
      } else {
        _individualReps = _individualReps.sublist(0, newSets);
      }
      if (_individualWeights.length < newSets) {
        _individualWeights.addAll(
            List.filled(newSets - _individualWeights.length, ''));
      } else {
        _individualWeights = _individualWeights.sublist(0, newSets);
      }
    });
  }

  String _dayName(int day) {
    final idx = (day - 1).clamp(0, _kDayNames.length - 1);
    return _kDayNames[idx];
  }

  @override
  Widget build(BuildContext context) {
    return _step == 0 ? _buildPickerStep() : _buildConfigStep();
  }

  // ── Step 0: Exercise picker ──────────────────────────────────────────────

  Widget _buildPickerStep() {
    return _RedesignSheet(
      children: [
        // Title + subtitle
        Text(
          'Agregar ejercicio',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _dayName(widget.dayNumber),
          style: RedesignType.bodySm
              .copyWith(color: RedesignColors.primario400),
        ),
        const SizedBox(height: 20),

        // Search field
        TextField(
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre',
            prefixIcon: const Icon(Icons.search_rounded,
                color: RedesignColors.primario400, size: 20),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 12),

        // Category pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _Pill(
                label: 'Todos',
                selected: _selectedMuscleGroup == null,
                onTap: () =>
                    setState(() => _selectedMuscleGroup = null),
              ),
              ...ExerciseCategory.routineFilters.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _Pill(
                    label: group,
                    selected: _selectedMuscleGroup == group,
                    onTap: () =>
                        setState(() => _selectedMuscleGroup = group),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Exercise list
        SizedBox(
          height: 280,
          child: _ExerciseSelector(
            selectedExerciseId: _selectedExerciseId,
            searchQuery: _searchQuery,
            muscleGroupFilter: _selectedMuscleGroup,
            onSelect: (id, name, muscle) {
              setState(() {
                _selectedExerciseId = id;
                _selectedExerciseName = name;
                _selectedExerciseMuscle = muscle;
              });
            },
          ),
        ),
        const SizedBox(height: 20),

        // Siguiente button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed:
                _selectedExerciseId == null ? null : () => setState(() => _step = 1),
            child: const Text('Siguiente'),
          ),
        ),
      ],
    );
  }

  // ── Step 1: Config ────────────────────────────────────────────────────────

  Widget _buildConfigStep() {
    final isEditing = widget.existingExercise != null;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return _RedesignSheet(
      children: [
        // Back + title
        Row(
          children: [
            if (!isEditing)
              GestureDetector(
                onTap: () => setState(() => _step = 0),
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: RedesignColors.primario400, size: 18),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedExerciseName ?? 'Ejercicio',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_selectedExerciseMuscle?.isNotEmpty == true)
                    Text(
                      _selectedExerciseMuscle!,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario400),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Sets counter
        _SetsCounter(
          sets: _sets,
          onDecrement:
              _sets > 1 ? () => _updateSets(_sets - 1) : null,
          onIncrement:
              _sets < 10 ? () => _updateSets(_sets + 1) : null,
        ),
        const SizedBox(height: 16),

        // Reps config
        Row(
          children: [
            Checkbox(
              value: _useSameReps,
              activeColor: RedesignColors.actionPrimary,
              checkColor: RedesignColors.onActionPrimary,
              onChanged: (val) =>
                  setState(() => _useSameReps = val ?? true),
            ),
            Expanded(
              child: Text(
                'Mismas reps para todas las series',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300),
              ),
            ),
          ],
        ),

        if (_useSameReps) ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: TextEditingController.fromValue(
                    TextEditingValue(
                      text: _standardReps,
                      selection: TextSelection.collapsed(
                          offset: _standardReps.length),
                    ),
                  ),
                  style: RedesignType.bodySm
                      .copyWith(color: RedesignColors.primario50),
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Reps (ej: 10-12)',
                  ),
                  onChanged: (v) => _standardReps = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: TextEditingController.fromValue(
                    TextEditingValue(
                      text: _standardWeight,
                      selection: TextSelection.collapsed(
                          offset: _standardWeight.length),
                    ),
                  ),
                  style: RedesignType.bodySm
                      .copyWith(color: RedesignColors.primario50),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Peso (kg)',
                    hintText: 'Opcional',
                  ),
                  onChanged: (v) => _standardWeight = v,
                ),
              ),
            ],
          ),
        ] else ...[
          // Header row for per-set table
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const SizedBox(width: 64),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Peso (kg)',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario400),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reps',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario400),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(_sets, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: Text(
                        'Serie ${index + 1}',
                        style: RedesignType.label.copyWith(
                            color: RedesignColors.primario300),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: ValueKey('weight_input_$index'),
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: index < _individualWeights.length
                                ? _individualWeights[index]
                                : '',
                            selection: TextSelection.collapsed(
                              offset: (index < _individualWeights.length
                                  ? _individualWeights[index].length
                                  : 0),
                            ),
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario50),
                        decoration: const InputDecoration(
                            hintText: 'kg'),
                        onChanged: (v) {
                          if (index < _individualWeights.length) {
                            _individualWeights[index] = v;
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: ValueKey('rep_input_$index'),
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: index < _individualReps.length
                                ? _individualReps[index]
                                : '',
                            selection: TextSelection.collapsed(
                              offset: (index < _individualReps.length
                                  ? _individualReps[index].length
                                  : 0),
                            ),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario50),
                        decoration: const InputDecoration(
                            hintText: 'Reps'),
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
        ],
        const SizedBox(height: 16),

        // Descanso (uniform, single value)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Descanso (seg)',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300)),
            Text('${_rest}s',
                style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.actionPrimary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: RedesignColors.actionPrimary,
            inactiveTrackColor:
                RedesignColors.actionPrimary.withValues(alpha: 0.18),
            thumbColor: RedesignColors.actionPrimary,
            overlayColor:
                RedesignColors.actionPrimary.withValues(alpha: 0.12),
          ),
          child: Slider(
            value: _rest.toDouble(),
            min: 30,
            max: 180,
            divisions: 15,
            onChanged: (v) => setState(() => _rest = v.round()),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saveDefaultRest,
            icon: const Icon(Icons.push_pin_outlined, size: 14),
            label: const Text('Usar como predeterminado'),
            style: TextButton.styleFrom(
              foregroundColor: RedesignColors.actionPrimary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Nota para el alumno
        TextField(
          controller: TextEditingController.fromValue(
            TextEditingValue(
              text: _comments,
              selection:
                  TextSelection.collapsed(offset: _comments.length),
            ),
          ),
          style: RedesignType.bodySm
              .copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            labelText: 'Nota para el alumno (opcional)',
            hintText: 'Ej: Controlar la excéntrica, pausa abajo...',
            prefixIcon: Icon(Icons.comment_outlined,
                color: RedesignColors.primario400, size: 18),
          ),
          onChanged: (v) => _comments = v,
          minLines: 1,
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || _selectedExerciseId == null
                ? null
                : _saveExercise,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary,
                    ),
                  )
                : Text(
                    isEditing
                        ? 'Guardar cambios'
                        : 'Agregar al ${_dayName(widget.dayNumber)}',
                  ),
          ),
        ),

        SizedBox(height: keyboardHeight),
      ],
    );
  }

  Future<void> _saveDefaultRest() async {
    await ref.read(trainerServiceProvider).updateDefaultRestSeconds(_rest);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Descanso predeterminado guardado'),
          backgroundColor: RedesignColors.success,
        ),
      );
    }
  }

  String? _buildWeightTarget() {
    if (_useSameReps) {
      // Single weight field
      final w = _standardWeight.trim();
      return w.isEmpty ? null : w;
    } else {
      // Per-set weights
      final parts = _individualWeights.sublist(0, _sets);
      final encoded = parts.join('|');
      // Return null if every part is blank
      if (parts.every((w) => w.trim().isEmpty)) return null;
      return encoded;
    }
  }

  Future<void> _saveExercise() async {
    if (_selectedExerciseId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(trainerServiceProvider);
      final nav = Navigator.of(context);
      final overlay = Overlay.of(context);

      String finalReps;
      if (_useSameReps) {
        finalReps = _standardReps;
      } else {
        finalReps = _individualReps.sublist(0, _sets).join('|');
      }

      final weightTarget = _buildWeightTarget();

      if (widget.existingExercise != null) {
        await service.updateRoutineExercise(widget.existingExercise!['id'], {
          'exercise_id': _selectedExerciseId,
          'sets': _sets,
          'reps_target': finalReps,
          'rest_seconds': _rest,
          'comment': _comments.isNotEmpty ? _comments : null,
          'weight_target': weightTarget,
        });
      } else {
        await service.addExerciseToRoutine(
          routineId: widget.routineId,
          exerciseId: _selectedExerciseId!,
          dayNumber: widget.dayNumber,
          sets: _sets,
          reps: finalReps,
          restTime: '${_rest}s',
          notes: _comments.isNotEmpty ? _comments : null,
          weightTarget: weightTarget,
        );
      }

      ref.invalidate(routineDetailProvider(widget.routineId));

      if (nav.mounted) nav.pop();
      // overlay.context belongs to the scaffold ancestor which outlives the
      // sheet — safe to use after pop.
      final toastCtx = overlay.context; // ignore: use_build_context_synchronously
      if (widget.existingExercise != null) {
        showRedesignToast(toastCtx, title: '¡Guardado exitosamente!', subtitle: 'Se han guardado los cambios'); // ignore: use_build_context_synchronously
      } else {
        showRedesignToast(toastCtx, title: '¡Agregado exitosamente!', subtitle: 'Se ha agregado al ${_dayName(widget.dayNumber)}'); // ignore: use_build_context_synchronously
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ---------------------------------------------------------------------------
// _SetsCounter — + / - stepper used in config step
// ---------------------------------------------------------------------------
class _SetsCounter extends StatelessWidget {
  final int sets;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  const _SetsCounter({
    required this.sets,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Text(
            'Series (Sets)',
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario300),
          ),
          const Spacer(),
          _StepButton(
            icon: Icons.remove_rounded,
            enabled: onDecrement != null,
            onTap: onDecrement,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$sets',
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepButton(
            icon: Icons.add_rounded,
            enabled: onIncrement != null,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _StepButton(
      {required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? RedesignColors.actionPrimary.withValues(alpha: 0.15)
              : RedesignColors.primario700,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? RedesignColors.actionPrimary
              : RedesignColors.primario500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Pill — filter pill used in exercise picker (matches _FilterPill in dashboard)
// ---------------------------------------------------------------------------
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1 : 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.secundario900
                : RedesignColors.secundario300,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ExerciseSelector — scrollable list with search + filter
// ---------------------------------------------------------------------------
class _ExerciseSelector extends ConsumerWidget {
  final String? selectedExerciseId;
  final String searchQuery;
  final String? muscleGroupFilter;
  final void Function(String id, String name, String muscle) onSelect;

  const _ExerciseSelector({
    required this.selectedExerciseId,
    required this.searchQuery,
    required this.muscleGroupFilter,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final mediaService = ref.read(exerciseMediaServiceProvider);

    return exercisesAsync.when(
      data: (exercises) {
        final filtered = exercises.where((ex) {
          final name = ex['name'] as String? ?? '';
          final matchesSearch =
              foldSearch(name).contains(foldSearch(searchQuery));
          final matchesGroup =
              ExerciseCategory.matches(ex, muscleGroupFilter);
          return matchesSearch && matchesGroup;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              'No se encontraron ejercicios',
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario400),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final exercise = filtered[index];
              final isSelected =
                  selectedExerciseId == exercise['id'];
              final exerciseModel = ExerciseModel.fromMap(exercise);
              final gifUrl = mediaService.resolveGifUrl(
                exerciseModel.gifUrl,
                mediaId: exerciseModel.mediaId,
              );
              final name = exercise['name'] as String? ?? '';
              final muscle = exercise['muscle_group'] as String? ?? '';

              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 0, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? RedesignColors.actionPrimary
                          .withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected
                      ? Border.all(
                          color: RedesignColors.actionPrimary
                              .withValues(alpha: 0.4),
                          width: 0.5,
                        )
                      : null,
                ),
                child: ListTile(
                  dense: true,
                  leading: _ExerciseGifThumb(
                    gifUrl: gifUrl,
                    isSelected: isSelected,
                  ),
                  title: Text(
                    name,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    muscle,
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario400),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: RedesignColors.actionPrimary, size: 20),
                      IconButton(
                        tooltip: 'Previsualizar ejercicio',
                        icon: Icon(
                          Icons.visibility_outlined,
                          color: RedesignColors.primario400,
                          size: 18,
                        ),
                        onPressed: () => _showExercisePreview(
                            context, exerciseModel, gifUrl),
                      ),
                    ],
                  ),
                  onTap: () => onSelect(exercise['id'], name, muscle),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// ---------------------------------------------------------------------------
// _ExerciseGifThumb
// ---------------------------------------------------------------------------
class _ExerciseGifThumb extends StatelessWidget {
  final String? gifUrl;
  final bool isSelected;

  const _ExerciseGifThumb(
      {required this.gifUrl, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: gifUrl == null
                ? Container(
                    color:
                        RedesignColors.primario700.withValues(alpha: 0.8),
                    child: const Icon(Icons.fitness_center,
                        color: RedesignColors.primario500, size: 22),
                  )
                : ExerciseGifView(
                    url: gifUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: RedesignColors.primario700
                          .withValues(alpha: 0.8),
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: RedesignColors.primario700
                          .withValues(alpha: 0.8),
                      child: const Icon(Icons.broken_image_outlined,
                          color: RedesignColors.primario500),
                    ),
                  ),
          ),
        ),
        if (isSelected)
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RedesignColors.actionPrimary.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle,
                color: Colors.white, size: 22),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _showExercisePreview — dialog unchanged, colors updated
// ---------------------------------------------------------------------------
void _showExercisePreview(
  BuildContext context,
  ExerciseModel exercise,
  String? gifUrl,
) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => Theme(
      data: RedesignTheme.theme,
      child: Dialog(
        backgroundColor: RedesignColors.primario800,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RedesignRadius.card)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close,
                          color: RedesignColors.primario400),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: gifUrl == null
                      ? Container(
                          width: double.infinity,
                          height: 240,
                          color: RedesignColors.primario700
                              .withValues(alpha: 0.8),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.fitness_center,
                                  color: RedesignColors.primario500,
                                  size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Este ejercicio no tiene GIF',
                                style: TextStyle(
                                    color: RedesignColors.primario400),
                              ),
                            ],
                          ),
                        )
                      : ExerciseGifView(
                          url: gifUrl,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const SizedBox(
                            height: 240,
                            child: Center(
                                child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => const SizedBox(
                            height: 240,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: RedesignColors.primario400,
                                  size: 48),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  exercise.instructionsEs,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario300, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// routineDetailProvider
// ---------------------------------------------------------------------------
final routineDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, routineId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getRoutine(routineId);
});

// ---------------------------------------------------------------------------
// _AssignToStudentsSheet
// ---------------------------------------------------------------------------
class _AssignToStudentsSheet extends ConsumerStatefulWidget {
  final String routineId;

  const _AssignToStudentsSheet({required this.routineId});

  @override
  ConsumerState<_AssignToStudentsSheet> createState() =>
      _AssignToStudentsSheetState();
}

class _AssignToStudentsSheetState
    extends ConsumerState<_AssignToStudentsSheet> {
  final Set<String> _selectedStudentIds = {};
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(myStudentsProvider);

    return _RedesignSheet(
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Asignar a alumnos',
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                      fontSize: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedStudentIds.length} seleccionado(s)',
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario400),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed:
                  _selectedStudentIds.isEmpty || _isLoading ? null : _assign,
              style: TextButton.styleFrom(
                foregroundColor: RedesignColors.actionPrimary,
                disabledForegroundColor: RedesignColors.primario500,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RedesignColors.actionPrimary,
                      ),
                    )
                  : Text(
                      'ASIGNAR',
                      style: RedesignType.buttonSm.copyWith(
                        color: RedesignColors.actionPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        studentsAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No tienes alumnos asignados',
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario400),
                  ),
                ),
              );
            }
            return Column(
              children: students.map((student) {
                final profile = student['profiles'];
                final name = student['name'] ?? 'Sin nombre';
                final email = profile?['email'] ?? '';
                final studentId = student['id'];
                final isSelected =
                    _selectedStudentIds.contains(studentId);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? RedesignColors.actionPrimary
                            .withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? RedesignColors.actionPrimary
                              .withValues(alpha: 0.3)
                          : RedesignColors.primario700
                              .withValues(alpha: 0.5),
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
                    title: Text(
                      name,
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: email.isNotEmpty
                        ? Text(
                            email,
                            style: RedesignType.label.copyWith(
                                color: RedesignColors.primario400),
                          )
                        : null,
                    secondary: CircleAvatar(
                      backgroundColor:
                          RedesignColors.actionPrimary.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'A',
                        style: RedesignType.buttonSm.copyWith(
                          color: RedesignColors.actionPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    activeColor: RedesignColors.actionPrimary,
                    checkColor: RedesignColors.onActionPrimary,
                    checkboxShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => Text(
            'Error: $e',
            style: const TextStyle(color: RedesignColors.danger),
          ),
        ),
      ],
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

      ref.invalidate(myStudentsProvider);
      ref.invalidate(routineDetailProvider(widget.routineId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Rutina asignada a ${_selectedStudentIds.length} alumnos',
            ),
            backgroundColor: RedesignColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
