import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/theme_redesign.dart';
import '../../widgets/check_in_photo.dart';
import '../../services/trainer_service.dart';
import '../student/student_check_in_history_screen.dart';
import 'routine_detail_screen.dart';
import 'meal_plan_detail_screen.dart';
import 'assignment_sheets.dart';
import 'alimentacion_sheet.dart';
import 'student_history_screen.dart';
import 'intake_view_screen.dart';
import 'check_in_comparison_screen.dart';
import 'cardio_editor_screen.dart';
import 'supplements_editor_screen.dart';
import '../shared/chat_screen.dart';

const _monthAbbr = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

// ---------------------------------------------------------------------------
// Weight range enum (mirrors student_weight_screen.dart)
// ---------------------------------------------------------------------------

enum _WeightRange { oneMonth, threeMonths, all }

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() =>
      _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  int _tabIndex = 0; // 0=Semana 1=Plan 2=Progreso
  _WeightRange _weightRange = _WeightRange.threeMonths;

  @override
  Widget build(BuildContext context) {
    final studentAsync = ref.watch(studentDetailProvider(widget.studentId));

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: RedesignColors.primario50),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'Detalle del alumno',
            style: TextStyle(
              color: RedesignColors.primario50,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
          actions: [
            // Chat con el alumno
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded,
                  color: RedesignColors.primario300),
              tooltip: 'Mensajes',
              onPressed: () {
                final name = studentAsync.valueOrNull?['name'] as String? ??
                    'Alumno';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      athleteId: widget.studentId,
                      title: name,
                      viewerRole: 'trainer',
                    ),
                  ),
                );
              },
            ),
            // Ficha del atleta
            IconButton(
              icon: const Icon(Icons.assignment_ind_outlined,
                  color: RedesignColors.primario300),
              tooltip: 'Ficha del atleta',
              onPressed: () {
                final name = studentAsync.valueOrNull?['name'] as String? ??
                    'Alumno';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IntakeViewScreen(
                      athleteId: widget.studentId,
                      athleteName: name,
                    ),
                  ),
                );
              },
            ),
            // Overflow: eliminar alumno
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: RedesignColors.primario300),
              color: RedesignColors.primario700,
              onSelected: (val) {
                if (val == 'delete') {
                  _confirmDelete(
                      studentAsync.valueOrNull?['name'] as String?);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline,
                          color: RedesignColors.danger, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Eliminar alumno',
                        style: TextStyle(
                          color: RedesignColors.danger,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: studentAsync.when(
          data: (student) {
            if (student == null) {
              return const Center(
                child: Text(
                  'Alumno no encontrado',
                  style: TextStyle(
                    color: RedesignColors.primario300,
                    fontFamily: 'Metropolis',
                  ),
                ),
              );
            }
            final name = student['name'] as String? ?? 'Sin nombre';

            return Column(
              children: [
                // ── Pill segmented control ─────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: _TabPill(
                    index: _tabIndex,
                    onChanged: (i) => setState(() => _tabIndex = i),
                  ),
                ),
                // ── Tab content ───────────────────────────────────────
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _SemanaTab(
                        student: student,
                        studentId: widget.studentId,
                        studentName: name,
                      ),
                      _PlanTab(
                        student: student,
                        studentId: widget.studentId,
                        studentName: name,
                        onAssignRoutine: () =>
                            _showAssignRoutineSheet(context),
                        onAssignMealPlan: () =>
                            _showAssignMealPlanSheet(context),
                        onEditCardio: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CardioEditorScreen(
                              athleteId: widget.studentId,
                              studentName: name,
                              initialActivity: student['cardio_activity']
                                  as String?,
                              initialDuration: student['cardio_duration']
                                  as String?,
                              initialLevel:
                                  student['cardio_level'] as String?,
                              initialNote:
                                  student['cardio_note'] as String?,
                              initialDays: (student['cardio_days'] as List?)
                                      ?.cast<int>() ??
                                  [],
                            ),
                          ),
                        ),
                        onEditSupplements: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SupplementsListScreen(
                              athleteId: widget.studentId,
                              studentName: name,
                            ),
                          ),
                        ),
                        onEditRenewal: () =>
                            _showEditRenewalDateDialog(context, student),
                        onPersonalizeRoutine: (id, title) =>
                            _personalizeRoutine(context, id, title, name),
                        onPersonalizeMealPlan: (id, title) =>
                            _personalizeMealPlan(context, id, title, name),
                      ),
                      _ProgresoTab(
                        student: student,
                        weightRange: _weightRange,
                        onRangeChanged: (r) =>
                            setState(() => _weightRange = r),
                        onAddWeight: () => _showAddWeightDialog(context),
                        onSetAssignedDate: (id, raw) =>
                            _setAssignedDate(context, id, raw),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: RedesignColors.actionPrimary),
          ),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(
                color: RedesignColors.danger,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Action methods ────────────────────────────────────────────────────────

  Future<void> _personalizeRoutine(
    BuildContext context,
    String routineId,
    String routineTitle,
    String studentName,
  ) async {
    final confirmed = await _confirmPersonalize(
      context,
      'Se creará una copia de "$routineTitle" solo para $studentName. '
      'Los cambios que hagas en la copia no afectan la rutina original.',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final service = ref.read(trainerServiceProvider);
      final newId = await service.personalizeRoutineForStudent(
        athleteId: widget.studentId,
        routineId: routineId,
        newTitle: '$routineTitle — $studentName',
      );
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutineDetailScreen(
            routineId: newId,
            routineTitle: '$routineTitle — $studentName',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(String? name) async {
    final label =
        (name == null || name.trim().isEmpty) ? 'este alumno' : name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        title: const Text(
          'Eliminar alumno',
          style: TextStyle(
            color: RedesignColors.primario50,
            fontFamily: 'Metropolis',
          ),
        ),
        content: Text(
          '¿Seguro que querés eliminar a $label? Se borrará su cuenta y todos '
          'sus datos de forma permanente. Esta acción no se puede deshacer.',
          style: const TextStyle(
            color: RedesignColors.primario300,
            fontFamily: 'Metropolis',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: RedesignColors.danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(trainerServiceProvider)
          .deleteStudent(widget.studentId);
      ref.invalidate(myStudentsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alumno eliminado'),
          backgroundColor: RedesignColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _personalizeMealPlan(
    BuildContext context,
    String mealPlanId,
    String planTitle,
    String studentName,
  ) async {
    final confirmed = await _confirmPersonalize(
      context,
      'Se creará una copia de "$planTitle" solo para $studentName. '
      'Los cambios que hagas en la copia no afectan el plan original.',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final service = ref.read(trainerServiceProvider);
      final newId = await service.personalizeMealPlanForStudent(
        athleteId: widget.studentId,
        mealPlanId: mealPlanId,
        newTitle: '$planTitle — $studentName',
      );
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealPlanDetailScreen(
            planId: newId,
            planName: '$planTitle — $studentName',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

  Future<bool?> _confirmPersonalize(
      BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        title: const Text(
          'Personalizar',
          style: TextStyle(
            color: RedesignColors.primario50,
            fontFamily: 'Metropolis',
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
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear copia'),
          ),
        ],
      ),
    );
  }

  void _showAssignRoutineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignRoutineSheet(studentId: widget.studentId),
    );
  }

  void _showAssignMealPlanSheet(BuildContext context) {
    // Read current student data from the provider's cached value.
    final student = ref.read(studentDetailProvider(widget.studentId)).valueOrNull;
    final name = (student?['name'] as String?) ?? 'Alumno';
    final mealPlans = (student?['athlete_meal_plans'] as List?) ?? [];
    final activeMealPlan = mealPlans.firstWhere(
      (m) => m['is_active'] == true,
      orElse: () => null,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AlimentacionSheet(
        athleteId: widget.studentId,
        studentName: name,
        activeMealPlan: activeMealPlan,
      ),
    );
  }

  void _showAddWeightDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        title: const Text(
          'Registrar Peso',
          style: TextStyle(
            color: RedesignColors.primario50,
            fontFamily: 'Metropolis',
          ),
        ),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(
            color: RedesignColors.primario50,
            fontSize: 24,
            fontFamily: 'Metropolis',
          ),
          decoration: const InputDecoration(
            hintText: '0.0',
            hintStyle: TextStyle(color: RedesignColors.primario500),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: RedesignColors.primario400),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (weight == null || weight <= 0) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(trainerServiceProvider)
                    .logStudentWeight(widget.studentId, weight);
                ref.invalidate(studentDetailProvider(widget.studentId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Peso registrado: ${weight}kg'),
                      backgroundColor: RedesignColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: RedesignColors.danger,
                    ),
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

  Future<void> _setAssignedDate(
    BuildContext context,
    String checkInId,
    String? currentAssigned,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final initial = currentAssigned != null
        ? (DateTime.tryParse(currentAssigned) ?? now)
        : now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha asignada del check-in',
      cancelText: 'Cancelar',
      confirmText: 'Guardar',
    );
    if (picked == null) return;

    final dateStr =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    try {
      await ref
          .read(trainerServiceProvider)
          .setCheckInAssignedDate(checkInId, dateStr);
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Fecha de check-in actualizada'),
            backgroundColor: RedesignColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

  void _showEditRenewalDateDialog(
    BuildContext context,
    Map<String, dynamic> student,
  ) async {
    final raw = student['next_renewal_date'] as String?;
    final initial =
        raw != null ? (DateTime.tryParse(raw) ?? DateTime.now()) : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Seleccionar fecha de vencimiento',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: RedesignColors.actionPrimary,
            onPrimary: RedesignColors.onActionPrimary,
            surface: RedesignColors.primario700,
            onSurface: RedesignColors.primario50,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !context.mounted) return;

    try {
      await ref
          .read(trainerServiceProvider)
          .updateStudentRenewalDate(widget.studentId, picked);
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fecha de vencimiento actualizada'),
            backgroundColor: RedesignColors.success,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final studentDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>(
        (ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getStudentDetails(studentId);
});

// ---------------------------------------------------------------------------
// Tab pill segmented control
// ---------------------------------------------------------------------------

class _TabPill extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _TabPill({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = ['Semana', 'Plan', 'Progreso'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active
                      ? RedesignColors.secundario300
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active
                        ? RedesignColors.secundario900
                        : RedesignColors.primario300,
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Semana tab
// ---------------------------------------------------------------------------

class _SemanaTab extends StatelessWidget {
  final Map<String, dynamic> student;
  final String studentId;
  final String studentName;

  const _SemanaTab({
    required this.student,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context) {
    final workoutSessions =
        (student['workout_sessions'] as List?) ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Current week Monday→Sunday
    final weekday = today.weekday; // 1=Mon
    final monday = today.subtract(Duration(days: weekday - 1));

    // Dates for the 7-day row (Mon–Sun of current week)
    final weekDays =
        List.generate(7, (i) => monday.add(Duration(days: i)));

    // Completed sessions per day (for the current week)
    bool didTrain(DateTime date) {
      return workoutSessions.any((s) {
        if (s['is_completed'] != true) return false;
        final raw =
            (s['started_at'] ?? s['created_at']) as String?;
        if (raw == null) return false;
        final d = DateTime.parse(raw).toLocal();
        return d.year == date.year &&
            d.month == date.month &&
            d.day == date.day;
      });
    }

    // Stats
    final completedCount = workoutSessions
        .where((s) => s['is_completed'] == true)
        .length;

    String? lastSessionDate;
    final completedSessions = workoutSessions
        .where((s) => s['is_completed'] == true)
        .toList();
    if (completedSessions.isNotEmpty) {
      completedSessions.sort((a, b) {
        final aRaw =
            (a['started_at'] ?? a['created_at']) as String? ?? '';
        final bRaw =
            (b['started_at'] ?? b['created_at']) as String? ?? '';
        return bRaw.compareTo(aRaw);
      });
      final rawLast =
          (completedSessions.first['started_at'] ??
              completedSessions.first['created_at']) as String?;
      if (rawLast != null) {
        final d = DateTime.tryParse(rawLast)?.toLocal();
        if (d != null) {
          lastSessionDate =
              '${d.day}/${d.month}/${d.year}';
        }
      }
    }

    // Active routine
    final routines = (student['athlete_routines'] as List?) ?? [];
    final activeRoutine = routines.firstWhere(
      (r) => r['is_active'] == true,
      orElse: () => null,
    );
    final cardioDesc =
        student['cardio_description'] as String? ?? '';

    // Month abbreviation for week label
    final endOfWeek = monday.add(const Duration(days: 6));
    final startMonth = _monthAbbr[monday.month - 1];
    final endMonth = _monthAbbr[endOfWeek.month - 1];
    final weekLabel = monday.month == endOfWeek.month
        ? '${monday.day}-${endOfWeek.day} ${startMonth[0].toUpperCase()}${startMonth.substring(1)}'
        : '${monday.day} ${startMonth[0].toUpperCase()}${startMonth.substring(1)} - ${endOfWeek.day} ${endMonth[0].toUpperCase()}${endMonth.substring(1)}';

    final dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Week range label
          Text(
            weekLabel,
            style: const TextStyle(
              color: RedesignColors.primario50,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(height: 12),

          // Week calendar card
          _NavyCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final date = weekDays[i];
                final trained = didTrain(date);
                final isToday = date.year == today.year &&
                    date.month == today.month &&
                    date.day == today.day;

                return Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: TextStyle(
                        color: isToday
                            ? RedesignColors.actionPrimary
                            : RedesignColors.primario400,
                        fontSize: 12,
                        fontWeight: isToday
                            ? FontWeight.w700
                            : FontWeight.normal,
                        fontFamily: 'Metropolis',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (_) {
                        final dayLabel = Text(
                          '${date.day}',
                          style: TextStyle(
                            color: trained
                                ? RedesignColors.actionPrimary
                                : isToday
                                    ? RedesignColors.primario50
                                    : RedesignColors.primario400,
                            fontSize: 13,
                            fontWeight: trained || isToday
                                ? FontWeight.w700
                                : FontWeight.normal,
                            fontFamily: 'Metropolis',
                          ),
                        );
                        // Trained → filled teal; today → solid teal ring;
                        // otherwise → dashed "planificado sin hacer" circle.
                        if (trained) {
                          return Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: RedesignColors.actionPrimary
                                  .withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: RedesignColors.actionPrimary
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                            child: dayLabel,
                          );
                        }
                        if (isToday) {
                          return Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: RedesignColors.actionPrimary,
                                width: 2,
                              ),
                            ),
                            child: dayLabel,
                          );
                        }
                        return _DashedCircle(
                          size: 36,
                          color: RedesignColors.primario400
                              .withValues(alpha: 0.6),
                          child: dayLabel,
                        );
                      },
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: RedesignColors.actionPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Entrenó',
                style: TextStyle(
                  color: RedesignColors.primario400,
                  fontSize: 11,
                  fontFamily: 'Metropolis',
                ),
              ),
              const SizedBox(width: 14),
              _DashedCircle(
                size: 14,
                color: RedesignColors.primario400,
                child: const SizedBox.shrink(),
              ),
              const SizedBox(width: 4),
              const Text(
                'Planificado sin hacer',
                style: TextStyle(
                  color: RedesignColors.primario400,
                  fontSize: 11,
                  fontFamily: 'Metropolis',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Le toca hoy
          const Text(
            'Le toca hoy',
            style: TextStyle(
              color: RedesignColors.primario50,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(height: 10),

          if (activeRoutine != null) ...[
            _TappableRow(
              icon: Icons.fitness_center_rounded,
              iconColor: RedesignColors.actionPrimary,
              title: activeRoutine['routines']?['title'] as String? ??
                  'Rutina',
              subtitle: 'Rutina',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutineDetailScreen(
                    routineId: activeRoutine['routine_id'],
                    routineTitle: activeRoutine['routines']?['title'] ??
                        'Rutina',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (cardioDesc.isNotEmpty) ...[
            _TappableRow(
              icon: Icons.directions_run_rounded,
              iconColor: RedesignColors.warning,
              title: cardioDesc,
              subtitle: 'Cardio',
              onTap: () {},
            ),
            const SizedBox(height: 8),
          ],

          if (activeRoutine == null && cardioDesc.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: const Text(
                'Sin actividad asignada para hoy',
                style: TextStyle(
                  color: RedesignColors.primario400,
                  fontFamily: 'Metropolis',
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Última actividad
          const Text(
            'Última actividad',
            style: TextStyle(
              color: RedesignColors.primario50,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(height: 10),
          _TappableRow(
            icon: Icons.history_rounded,
            iconColor: RedesignColors.secundario500,
            title: 'Ir a historial',
            subtitle: '$completedCount sesiones'
                '${lastSessionDate != null ? ' · última $lastSessionDate' : ''}',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudentHistoryScreen(
                  studentId: studentId,
                  studentName: studentName,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan tab
// ---------------------------------------------------------------------------

class _PlanTab extends ConsumerWidget {
  final Map<String, dynamic> student;
  final String studentId;
  final String studentName;
  final VoidCallback onAssignRoutine;
  final VoidCallback onAssignMealPlan;
  final VoidCallback onEditCardio;
  final VoidCallback onEditSupplements;
  final VoidCallback onEditRenewal;
  final void Function(String id, String title) onPersonalizeRoutine;
  final void Function(String id, String title) onPersonalizeMealPlan;

  const _PlanTab({
    required this.student,
    required this.studentId,
    required this.studentName,
    required this.onAssignRoutine,
    required this.onAssignMealPlan,
    required this.onEditCardio,
    required this.onEditSupplements,
    required this.onEditRenewal,
    required this.onPersonalizeRoutine,
    required this.onPersonalizeMealPlan,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = (student['athlete_routines'] as List?) ?? [];
    final activeRoutine = routines.firstWhere(
      (r) => r['is_active'] == true,
      orElse: () => null,
    );
    final mealPlans = (student['athlete_meal_plans'] as List?) ?? [];
    final activeMealPlan = mealPlans.firstWhere(
      (m) => m['is_active'] == true,
      orElse: () => null,
    );

    final cardioDesc =
        student['cardio_description'] as String? ?? '';
    final cardioDays = student['cardio_days'] as List?;

    // Structured supplements via provider.
    final supplementsAsync =
        ref.watch(athleteSupplementsProvider(studentId));

    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Entrenamiento ──────────────────────────────────────────
          _PlanCard(
            title: 'Entrenamiento',
            onEdit: onAssignRoutine,
            child: activeRoutine != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlanCardRow(
                        icon: Icons.fitness_center_rounded,
                        iconColor: RedesignColors.actionPrimary,
                        title: activeRoutine['routines']?['title']
                                as String? ??
                            'Rutina',
                        subtitle: 'Rutina',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoutineDetailScreen(
                              routineId:
                                  activeRoutine['routine_id'],
                              routineTitle:
                                  activeRoutine['routines']
                                          ?['title'] ??
                                      'Rutina',
                            ),
                          ),
                        ),
                      ),
                      if (cardioDesc.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PlanCardRow(
                          icon: Icons.directions_run_rounded,
                          iconColor: RedesignColors.warning,
                          title: cardioDesc,
                          subtitle: cardioDays != null &&
                                  cardioDays.isNotEmpty
                              ? _formatCardioDays(cardioDays)
                              : 'Cardio',
                          onTap: onEditCardio,
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: onEditCardio,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.add_rounded,
                                color: RedesignColors.actionPrimaryDark,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Agregar cardio',
                                style: TextStyle(
                                  color:
                                      RedesignColors.actionPrimaryDark,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Metropolis',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => onPersonalizeRoutine(
                            activeRoutine['routine_id'] as String,
                            activeRoutine['routines']?['title']
                                    as String? ??
                                'Rutina',
                          ),
                          icon: const Icon(Icons.copy_rounded,
                              size: 14),
                          label: const Text(
                              'Personalizar para este alumno'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                RedesignColors.actionPrimaryDark,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Metropolis',
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  )
                : _PlanEmptyState(
                    icon: Icons.fitness_center_rounded,
                    text: 'Sin rutina asignada',
                    onTap: onAssignRoutine,
                  ),
          ),
          const SizedBox(height: 14),

          // ── Alimentación ──────────────────────────────────────────
          _PlanCard(
            title: 'Alimentación',
            onEdit: onAssignMealPlan,
            child: activeMealPlan != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PlanCardRow(
                        icon: Icons.restaurant_rounded,
                        iconColor: RedesignColors.warning,
                        title: activeMealPlan['meal_plans']?[
                                'title'] as String? ??
                            'Plan',
                        subtitle: 'Plan',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MealPlanDetailScreen(
                              planId:
                                  activeMealPlan['meal_plan_id'],
                              planName:
                                  activeMealPlan['meal_plans']
                                          ?['title'] ??
                                      'Plan Alimenticio',
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => onPersonalizeMealPlan(
                            activeMealPlan['meal_plan_id']
                                as String,
                            activeMealPlan['meal_plans']?['title']
                                    as String? ??
                                'Plan Alimenticio',
                          ),
                          icon: const Icon(Icons.copy_rounded,
                              size: 14),
                          label: const Text(
                              'Personalizar para este alumno'),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                RedesignColors.actionPrimaryDark,
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'Metropolis',
                            ),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  )
                : _PlanEmptyState(
                    icon: Icons.restaurant_rounded,
                    text: 'Sin plan asignado',
                    onTap: onAssignMealPlan,
                  ),
          ),
          const SizedBox(height: 14),

          // ── Suplementación ────────────────────────────────────────
          _PlanCard(
            title: 'Suplementación',
            onEdit: onEditSupplements,
            child: supplementsAsync.when(
              loading: () => const SizedBox(
                height: 20,
                child: LinearProgressIndicator(
                  color: RedesignColors.actionPrimary,
                  backgroundColor: RedesignColors.primario700,
                ),
              ),
              error: (_, __) => const _PlanEmptyState(
                icon: Icons.medication_rounded,
                text: 'No asignado',
                onTap: null,
              ),
              data: (supplements) {
                if (supplements.isEmpty) {
                  return const _PlanEmptyState(
                    icon: Icons.medication_rounded,
                    text: 'Sin asignar',
                    onTap: null,
                  );
                }
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: supplements.map((s) {
                    final name =
                        (s['name'] as String?) ?? 'Suplemento';
                    final dose = (s['dose'] as String?) ?? '';
                    final unit = (s['unit'] as String?) ?? '';
                    final label = dose.isNotEmpty || unit.isNotEmpty
                        ? '$name $dose$unit'
                        : name;
                    return _SupplementChip(label: label);
                  }).toList(),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // ── Próximo Vencimiento ───────────────────────────────────
          _RenewalCard(
            student: student,
            onEdit: onEditRenewal,
          ),
        ],
      ),
    );
  }

  String _formatCardioDays(List days) {
    const dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return days.map((d) => dayNames[(d as int) - 1]).join(', ');
  }
}

// ---------------------------------------------------------------------------
// Progreso tab
// ---------------------------------------------------------------------------

class _ProgresoTab extends StatelessWidget {
  final Map<String, dynamic> student;
  final _WeightRange weightRange;
  final ValueChanged<_WeightRange> onRangeChanged;
  final VoidCallback onAddWeight;
  final Future<void> Function(String id, String? raw) onSetAssignedDate;

  const _ProgresoTab({
    required this.student,
    required this.weightRange,
    required this.onRangeChanged,
    required this.onAddWeight,
    required this.onSetAssignedDate,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Peso card ────────────────────────────────────────────
          _WeightCard(
            student: student,
            range: weightRange,
            onRangeChanged: onRangeChanged,
            onAddWeight: onAddWeight,
          ),
          const SizedBox(height: 20),

          // ── Check-in section ─────────────────────────────────────
          _CheckInSection(
            student: student,
            onSetAssignedDate: onSetAssignedDate,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight card (Progreso tab)
// ---------------------------------------------------------------------------

class _WeightCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final _WeightRange range;
  final ValueChanged<_WeightRange> onRangeChanged;
  final VoidCallback onAddWeight;

  const _WeightCard({
    required this.student,
    required this.range,
    required this.onRangeChanged,
    required this.onAddWeight,
  });

  DateTime? _entryDate(Map<String, dynamic> e) {
    final raw = e['date'] ?? e['created_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  double? _weight(Map<String, dynamic> e) =>
      (e['body_weight'] as num?)?.toDouble();

  List<Map<String, dynamic>> _filtered(
      List<Map<String, dynamic>> all) {
    if (range == _WeightRange.all) return all;
    final days = range == _WeightRange.oneMonth ? 30 : 90;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final f = all.where((e) {
      final d = _entryDate(e);
      return d == null || !d.isBefore(cutoff);
    }).toList();
    return f.isEmpty ? all : f;
  }

  String _shortDate(DateTime d) =>
      '${d.day} ${_monthAbbr[d.month - 1]}';

  String _fmtDelta(double d) {
    final s =
        d.abs().toStringAsFixed(1).replaceAll('.', ',');
    final sign = d > 0 ? '+' : (d < 0 ? '-' : '');
    return '$sign$s kg';
  }

  @override
  Widget build(BuildContext context) {
    final bodyProgress =
        (student['body_progress'] as List?) ?? [];
    final allProgress =
        List<Map<String, dynamic>>.from(bodyProgress);
    allProgress.sort((a, b) {
      final aD = _entryDate(a);
      final bD = _entryDate(b);
      if (aD == null || bD == null) return 0;
      return aD.compareTo(bD);
    });

    // Header row: title + Agregar
    Widget header = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Peso',
          style: TextStyle(
            color: RedesignColors.primario50,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFamily: 'Metropolis',
          ),
        ),
        GestureDetector(
          onTap: onAddWeight,
          child: const Text(
            'Agregar',
            style: TextStyle(
              color: RedesignColors.actionPrimaryDark,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
      ],
    );

    if (allProgress.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Sin peso cargado',
                style: TextStyle(
                  color: RedesignColors.primario300,
                  fontSize: 15,
                  fontFamily: 'Metropolis',
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Pedísele para empezar a ver su evolución',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: RedesignColors.primario400,
                  fontSize: 13,
                  fontFamily: 'Metropolis',
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: OutlinedButton(
                onPressed: onAddWeight,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 40),
                ),
                child: const Text('Pedir registro'),
              ),
            ),
          ],
        ),
      );
    }

    final filtered = _filtered(allProgress);
    final latest = _weight(allProgress.last);
    final firstW = _weight(filtered.first);
    final firstDate = _entryDate(filtered.first);
    final delta =
        (latest != null && firstW != null) ? latest - firstW : null;

    // Build chart spots from filtered (only entries with weight)
    final plotted = filtered
        .where((e) => _weight(e) != null)
        .toList();
    final spots = [
      for (int i = 0; i < plotted.length; i++)
        FlSpot(i.toDouble(), _weight(plotted[i])!),
    ];

    double minY = 0;
    double maxY = 100;
    if (spots.isNotEmpty) {
      final ys = spots.map((s) => s.y);
      minY = ys.reduce((a, b) => a < b ? a : b) - 1.5;
      maxY = ys.reduce((a, b) => a > b ? a : b) + 1.5;
    }

    final lastIdx = spots.length - 1;
    final labelIdx = <int>{0, lastIdx, lastIdx ~/ 2};

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          latest != null
                              ? latest.toStringAsFixed(1)
                              : '-',
                          style: const TextStyle(
                            color: RedesignColors.primario50,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Metropolis',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'kg',
                          style: TextStyle(
                            color: RedesignColors.primario400,
                            fontSize: 15,
                            fontFamily: 'Metropolis',
                          ),
                        ),
                      ],
                    ),
                    if (delta != null && firstDate != null)
                      Text(
                        '${_fmtDelta(delta)} desde el ${_shortDate(firstDate)}',
                        style: TextStyle(
                          color: delta <= 0
                              ? RedesignColors.success
                              : RedesignColors.danger,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                  ],
                ),
              ),
              _WeightRangeToggle(
                value: range,
                onChanged: onRangeChanged,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (spots.isNotEmpty)
            SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Colors.white.withValues(alpha: 0.06),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        interval:
                            ((maxY - minY) / 2).clamp(1, double.infinity),
                        getTitlesWidget: (value, meta) => Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 10,
                            color: RedesignColors.primario400,
                            fontFamily: 'Metropolis',
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (!labelIdx.contains(i) ||
                              i < 0 ||
                              i >= plotted.length) {
                            return const SizedBox.shrink();
                          }
                          final d = _entryDate(plotted[i]);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              d != null ? _shortDate(d) : '',
                              style: const TextStyle(
                                fontSize: 10,
                                color: RedesignColors.primario400,
                                fontFamily: 'Metropolis',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) =>
                          RedesignColors.primario700,
                      tooltipBorder: BorderSide(
                        color: RedesignColors.actionPrimary
                            .withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: RedesignColors.actionPrimary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, _, __, ___) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: RedesignColors.background,
                          strokeWidth: 2.5,
                          strokeColor:
                              RedesignColors.actionPrimary,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            RedesignColors.actionPrimary
                                .withValues(alpha: 0.22),
                            RedesignColors.actionPrimary
                                .withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Weight range toggle
// ---------------------------------------------------------------------------

class _WeightRangeToggle extends StatelessWidget {
  final _WeightRange value;
  final ValueChanged<_WeightRange> onChanged;

  const _WeightRangeToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('1M', _WeightRange.oneMonth),
          _segment('3M', _WeightRange.threeMonths),
          _segment('Todo', _WeightRange.all),
        ],
      ),
    );
  }

  Widget _segment(String label, _WeightRange range) {
    final isActive = value == range;
    return GestureDetector(
      onTap: () => onChanged(range),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isActive
              ? RedesignColors.primario600
              : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? RedesignColors.primario50
                : RedesignColors.primario400,
            fontSize: 12,
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.w500,
            fontFamily: 'Metropolis',
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Check-in section (Progreso tab)
// ---------------------------------------------------------------------------

class _CheckInSection extends StatelessWidget {
  final Map<String, dynamic> student;
  final Future<void> Function(String id, String? raw) onSetAssignedDate;

  const _CheckInSection({
    required this.student,
    required this.onSetAssignedDate,
  });

  @override
  Widget build(BuildContext context) {
    final checkIns = (student['check_ins'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Check-in',
              style: TextStyle(
                color: RedesignColors.primario50,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Metropolis',
              ),
            ),
            if (checkIns.isNotEmpty)
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => CheckInGridSheet(
                    checkIns: List<Map<String, dynamic>>.from(
                      checkIns,
                    ),
                  ),
                ),
                child: const Text(
                  'Ir a todos',
                  style: TextStyle(
                    color: RedesignColors.actionPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (checkIns.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: _cardDecoration(),
            child: Column(
              children: [
                Icon(
                  Icons.photo_camera_rounded,
                  size: 40,
                  color: RedesignColors.primario500
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Sin fotos de check-in',
                  style: TextStyle(
                    color: RedesignColors.primario400,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: checkIns.length,
              itemBuilder: (context, index) {
                final checkIn =
                    checkIns[index] as Map<String, dynamic>;
                final allUrls =
                    (checkIn['photo_urls'] as List?)
                            ?.whereType<String>()
                            .where((s) => s.isNotEmpty)
                            .toList() ??
                        (checkIn['photo_url'] != null
                            ? [checkIn['photo_url'] as String]
                            : <String>[]);
                final assignedRaw =
                    checkIn['assigned_date'] as String?;
                final createdRaw =
                    checkIn['created_at'] as String?;
                final dateStr = () {
                  if (assignedRaw != null) {
                    final d = DateTime.tryParse(assignedRaw);
                    if (d != null) {
                      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                    }
                  }
                  if (createdRaw != null) {
                    final d = DateTime.tryParse(createdRaw)
                        ?.toLocal();
                    if (d != null) {
                      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
                    }
                  }
                  return '';
                }();

                return GestureDetector(
                  onTap: allUrls.isNotEmpty
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CheckInPhotoViewerScreen(
                                urls: allUrls,
                                initialIndex: 0,
                              ),
                            ),
                          )
                      : null,
                  onLongPress: () => onSetAssignedDate(
                    checkIn['id'] as String,
                    assignedRaw,
                  ),
                  child: Container(
                    width: 108,
                    margin: EdgeInsets.only(
                        right:
                            index < checkIns.length - 1 ? 10 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: RedesignColors.primario700,
                      border: Border.all(
                        color: RedesignColors.secundario300
                            .withValues(alpha: 0.18),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        allUrls.isNotEmpty
                            ? CheckInPhoto(
                                key: ValueKey(allUrls.first),
                                url: allUrls.first,
                                cacheWidth: 300,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: RedesignColors.primario400,
                                  size: 28,
                                ),
                              ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => onSetAssignedDate(
                              checkIn['id'] as String,
                              assignedRaw,
                            ),
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 5,
                                horizontal: 6,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin:
                                      Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black
                                        .withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dateStr.isNotEmpty
                                        ? dateStr
                                        : 'Fecha',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Metropolis',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.edit_calendar_rounded,
                                    color: assignedRaw != null
                                        ? RedesignColors
                                            .actionPrimary
                                        : Colors.white,
                                    size: 13,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Renewal card (Plan tab)
// ---------------------------------------------------------------------------

class _RenewalCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final VoidCallback onEdit;

  const _RenewalCard({required this.student, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final raw = student['next_renewal_date'] as String?;
    final renewalDate =
        raw != null ? DateTime.tryParse(raw) : null;

    String label;
    Color statusColor;
    IconData statusIcon;

    if (renewalDate == null) {
      label = 'Sin fecha asignada';
      statusColor =
          RedesignColors.primario400;
      statusIcon = Icons.event_busy_rounded;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final renewalDay = DateTime(
          renewalDate.year, renewalDate.month, renewalDate.day);
      final daysLeft =
          renewalDay.difference(today).inDays;
      final dateLabel =
          '${renewalDate.day.toString().padLeft(2, '0')}/${renewalDate.month.toString().padLeft(2, '0')}/${renewalDate.year}';

      if (daysLeft <= 0) {
        label = 'Venció el $dateLabel';
        statusColor = RedesignColors.danger;
        statusIcon = Icons.warning_rounded;
      } else if (daysLeft <= 5) {
        label = 'Vence en $daysLeft día${daysLeft == 1 ? '' : 's'} ($dateLabel)';
        statusColor = RedesignColors.danger;
        statusIcon = Icons.warning_amber_rounded;
      } else if (daysLeft <= 14) {
        label = 'Vence el $dateLabel ($daysLeft días)';
        statusColor = RedesignColors.warning;
        statusIcon = Icons.schedule_rounded;
      } else {
        label = 'Vence el $dateLabel ($daysLeft días)';
        statusColor = RedesignColors.success;
        statusIcon = Icons.check_circle_rounded;
      }
    }

    return _PlanCard(
      title: 'Próximo Vencimiento',
      onEdit: onEdit,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius:
                  BorderRadius.circular(RedesignRadius.iconBadge),
            ),
            child: Icon(statusIcon,
                color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: renewalDate != null
                    ? RedesignColors.primario50
                    : RedesignColors.primario400,
                fontWeight: renewalDate != null
                    ? FontWeight.w600
                    : FontWeight.normal,
                fontStyle: renewalDate != null
                    ? FontStyle.normal
                    : FontStyle.italic,
                fontSize: 15,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card decoration helper
// ---------------------------------------------------------------------------

BoxDecoration _cardDecoration() => BoxDecoration(
      color: RedesignColors.surface,
      borderRadius:
          BorderRadius.circular(RedesignRadius.card),
      border: Border.all(
        color: RedesignColors.secundario300
            .withValues(alpha: 0.18),
      ),
    );

// ---------------------------------------------------------------------------
// Navy card wrapper (used in Semana tab)
// ---------------------------------------------------------------------------

class _NavyCard extends StatelessWidget {
  final Widget child;
  const _NavyCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Plan section card (used in Plan tab)
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final String title;
  final VoidCallback onEdit;
  final Widget child;

  const _PlanCard({
    required this.title,
    required this.onEdit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: RedesignColors.primario50,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Metropolis',
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: const Text(
                  'Editar',
                  style: TextStyle(
                    color: RedesignColors.actionPrimaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan card row (icon tile + title + subtitle + chevron)
// ---------------------------------------------------------------------------

class _PlanCardRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlanCardRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(
                  RedesignRadius.iconBadge),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RedesignColors.primario50,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Metropolis',
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RedesignColors.primario400,
                    fontSize: 12,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: RedesignColors.primario500,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tappable row (Semana tab)
// ---------------------------------------------------------------------------

class _TappableRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _TappableRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RedesignColors.primario50,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: RedesignColors.primario400,
                      fontSize: 12,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: RedesignColors.primario500,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plan empty state
// ---------------------------------------------------------------------------

class _PlanEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _PlanEmptyState({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: RedesignColors.primario500,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: RedesignColors.primario400,
              fontStyle: FontStyle.italic,
              fontFamily: 'Metropolis',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supplement chip
// ---------------------------------------------------------------------------

class _SupplementChip extends StatelessWidget {
  final String label;
  const _SupplementChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: RedesignColors.primario600,
        borderRadius: BorderRadius.circular(
            RedesignRadius.buttonSm),
        border: Border.all(
          color: RedesignColors.secundario300
              .withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: RedesignColors.primario200,
          fontSize: 13,
          fontFamily: 'Metropolis',
        ),
      ),
    );
  }
}

/// Dashed circular border — "Planificado sin hacer" day marker (Figma).
class _DashedCircle extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;

  const _DashedCircle({
    required this.size,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedCirclePainter(color: color),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;

  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: size.width / 2 - 0.6,
    );
    final path = Path()..addOval(rect);
    const dash = 3.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
