import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
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
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(myRoutinesProvider);

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
                const Expanded(
                  child: Text(
                    'Asignar Rutina',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedRoutineId == null ? null : _assignRoutine,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Asignar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: routinesAsync.when(
              data: (routines) {
                if (routines.isEmpty) {
                  return const Center(child: Text('No tienes rutinas creadas.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final routine = routines[index];
                    final isSelected = _selectedRoutineId == routine['id'];
                    
                    return RadioListTile<String>(
                      value: routine['id'],
                      groupValue: _selectedRoutineId,
                      onChanged: (val) => setState(() => _selectedRoutineId = val),
                      title: Text(routine['title'] ?? 'Rutina'),
                      subtitle: Text(routine['objective'] ?? ''),
                      secondary: isSelected 
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                      activeColor: AppColors.primary,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSelected 
                           ? const BorderSide(color: AppColors.primary)
                           : BorderSide.none,
                      ),
                      tileColor: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
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

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rutina asignada correctamente'), backgroundColor: AppColors.success),
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


// ==================== ASSIGN MEAL PLAN SHEET ====================

class AssignMealPlanSheet extends ConsumerStatefulWidget {
  final String studentId;

  const AssignMealPlanSheet({super.key, required this.studentId});

  @override
  ConsumerState<AssignMealPlanSheet> createState() => _AssignMealPlanSheetState();
}

class _AssignMealPlanSheetState extends ConsumerState<AssignMealPlanSheet> {
  String? _selectedMealPlanId;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final mealPlansAsync = ref.watch(myMealPlansProvider);

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
                const Expanded(
                  child: Text(
                    'Asignar Plan Alimenticio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedMealPlanId == null ? null : _assignMealPlan,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Asignar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: mealPlansAsync.when(
              data: (plans) {
                if (plans.isEmpty) {
                  return const Center(child: Text('No tienes planes creados.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final isSelected = _selectedMealPlanId == plan['id'];
                    
                    return RadioListTile<String>(
                      value: plan['id'],
                      groupValue: _selectedMealPlanId,
                      onChanged: (val) => setState(() => _selectedMealPlanId = val),
                      title: Text(plan['title'] ?? 'Plan'),
                      subtitle: Text(plan['objective'] ?? ''),
                      secondary: isSelected 
                        ? const Icon(Icons.check_circle, color: AppColors.warning)
                        : null,
                      activeColor: AppColors.warning,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                       shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSelected 
                           ? const BorderSide(color: AppColors.warning)
                           : BorderSide.none,
                      ),
                      tileColor: isSelected ? AppColors.warning.withOpacity(0.05) : null,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
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
          const SnackBar(content: Text('Plan asignado correctamente'), backgroundColor: AppColors.success),
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
