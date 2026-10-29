import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import 'student_detail_screen.dart';

// ==================== ASSIGN ROUTINE SHEET ====================

class AssignRoutineSheet extends ConsumerStatefulWidget {
  final String studentId;

  const AssignRoutineSheet({super.key, required this.studentId});

  @override
  ConsumerState<AssignRoutineSheet> createState() => _AssignRoutineSheetState();
}

class _AssignRoutineSheetState extends ConsumerState<AssignRoutineSheet> {
  String? _selectedRoutineId;
  final DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(myRoutinesProvider);

    return _AssignSheetShell(
      title: 'Asignar rutina',
      subtitle: 'Elegí la rutina para este alumno',
      actionLabel: 'Guardar',
      isLoading: _isLoading,
      canSubmit: _selectedRoutineId != null,
      onSubmit: _assignRoutine,
      child: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return const _AssignEmpty(text: 'No tienes rutinas creadas.');
          }
          return RadioGroup<String>(
            groupValue: _selectedRoutineId,
            onChanged: (val) => setState(() => _selectedRoutineId = val),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              itemCount: routines.length,
              itemBuilder: (context, index) {
                final routine = routines[index];
                return _AssignItemCard(
                  value: routine['id'] as String,
                  title: routine['title'] ?? 'Rutina',
                  subtitle: routine['objective'] ?? '',
                  selected: _selectedRoutineId == routine['id'],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _AssignEmpty(text: 'Error: $e'),
      ),
    );
  }

  Future<void> _assignRoutine() async {
    if (_selectedRoutineId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(trainerServiceProvider);
      await service.assignRoutineToStudent(
        athleteId: widget.studentId,
        routineId: _selectedRoutineId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      // Invalidate student detail provider to refresh info
      ref.invalidate(studentDetailProvider(widget.studentId));
      ref.invalidate(myStudentsProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rutina asignada correctamente'),
            backgroundColor: RedesignColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: RedesignColors.danger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ==================== ASSIGN MEAL PLAN SHEET ====================

class AssignMealPlanSheet extends ConsumerStatefulWidget {
  final String studentId;

  const AssignMealPlanSheet({super.key, required this.studentId});

  @override
  ConsumerState<AssignMealPlanSheet> createState() =>
      _AssignMealPlanSheetState();
}

class _AssignMealPlanSheetState extends ConsumerState<AssignMealPlanSheet> {
  String? _selectedMealPlanId;
  final DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final mealPlansAsync = ref.watch(myMealPlansProvider);

    return _AssignSheetShell(
      title: 'Asignar plan',
      subtitle: 'Elegí el plan de alimentación',
      actionLabel: 'Guardar',
      isLoading: _isLoading,
      canSubmit: _selectedMealPlanId != null,
      onSubmit: _assignMealPlan,
      child: mealPlansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const _AssignEmpty(text: 'No tienes planes creados.');
          }
          return RadioGroup<String>(
            groupValue: _selectedMealPlanId,
            onChanged: (val) => setState(() => _selectedMealPlanId = val),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
              itemCount: plans.length,
              itemBuilder: (context, index) {
                final plan = plans[index];
                return _AssignItemCard(
                  value: plan['id'] as String,
                  title: plan['title'] ?? 'Plan',
                  subtitle: plan['objective'] ?? '',
                  selected: _selectedMealPlanId == plan['id'],
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _AssignEmpty(text: 'Error: $e'),
      ),
    );
  }

  Future<void> _assignMealPlan() async {
    if (_selectedMealPlanId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(trainerServiceProvider);
      await service.assignMealPlanToStudent(
        athleteId: widget.studentId,
        mealPlanId: _selectedMealPlanId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      // Invalidate student detail provider to refresh info
      ref.invalidate(studentDetailProvider(widget.studentId));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan asignado correctamente'),
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

// ==================== SHARED PIECES ====================

/// Navy→teal gradient picker sheet: handle, title/subtitle + close, a scrollable
/// selection list, and a bottom mint action button.
class _AssignSheetShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool isLoading;
  final bool canSubmit;
  final VoidCallback onSubmit;
  final Widget child;

  const _AssignSheetShell({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.isLoading,
    required this.canSubmit,
    required this.onSubmit,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: RedesignType.headingMd.copyWith(
                              color: RedesignColors.primario50,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.primario300),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            color: RedesignColors.primario300, size: 24),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: child),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isLoading || !canSubmit) ? null : onSubmit,
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RedesignColors.onActionPrimary,
                            ),
                          )
                        : Text(actionLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignItemCard extends StatelessWidget {
  final String value;
  final String title;
  final String subtitle;
  final bool selected;

  const _AssignItemCard({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.18),
          width: selected ? 1.2 : 1,
        ),
      ),
      child: RadioListTile<String>(
        value: value,
        title: Text(
          title,
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        subtitle: subtitle.isEmpty
            ? null
            : Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300),
              ),
        secondary: selected
            ? const Icon(Icons.check_circle_rounded,
                color: RedesignColors.actionPrimary)
            : null,
        activeColor: RedesignColors.actionPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.card),
        ),
      ),
    );
  }
}

class _AssignEmpty extends StatelessWidget {
  final String text;

  const _AssignEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
      ),
    );
  }
}
