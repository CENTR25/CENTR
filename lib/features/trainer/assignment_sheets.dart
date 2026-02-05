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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Header
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                  child: const Icon(Icons.assignment_rounded, color: AppColors.primaryLight, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Asignar Rutina',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedRoutineId == null ? null : _assignRoutine,
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Text('ASIGNAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.primary.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: RadioListTile<String>(
                        value: routine['id'],
                        groupValue: _selectedRoutineId,
                        onChanged: (val) => setState(() => _selectedRoutineId = val),
                        title: Text(
                          routine['title'] ?? 'Rutina',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          routine['objective'] ?? '',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        secondary: isSelected 
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight)
                          : null,
                        activeColor: AppColors.primaryLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Header
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                    color: AppColors.warning.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.warning, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Asignar Plan',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: _isLoading || _selectedMealPlanId == null ? null : _assignMealPlan,
                  style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                      : const Text('ASIGNAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.warning.withOpacity(0.05) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.warning.withOpacity(0.3) : Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: RadioListTile<String>(
                        value: plan['id'],
                        groupValue: _selectedMealPlanId,
                        onChanged: (val) => setState(() => _selectedMealPlanId = val),
                        title: Text(
                          plan['title'] ?? 'Plan',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          plan['objective'] ?? '',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        secondary: isSelected 
                          ? const Icon(Icons.check_circle_rounded, color: AppColors.warning)
                          : null,
                        activeColor: AppColors.warning,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
