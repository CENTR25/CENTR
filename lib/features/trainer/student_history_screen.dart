import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';

class StudentHistoryScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;

  const StudentHistoryScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  ConsumerState<StudentHistoryScreen> createState() => _StudentHistoryScreenState();
}

class _StudentHistoryScreenState extends ConsumerState<StudentHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    // We will need a provider to fetch history logs. Defining it here or in service.
    // For now assume we use a future builder calling service directly or a provider we'll create.
    final historyAsync = ref.watch(studentHistoryProvider(widget.studentId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Historial de ${widget.studentName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: historyAsync.when(
        data: (logs) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Icon(Icons.history_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sin historial de entrenamientos',
                    style: TextStyle(color: AppColors.textLight, fontSize: 16),
                  ),
                ],
              ),
            );

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _WorkoutLogCard(log: log);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _WorkoutLogCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _WorkoutLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    // Parse log data
    final routineName = log['routine_exercises']?['routines']?['title'] ?? 'Rutina desconocida'; // This might need adjustment based on join
    // Actually, workout_logs is usually per exercise set. We might want to group them by session (date).
    // If the API returns raw logs, we might need to group them here or in the service.
    
    // Assuming the service returns grouped sessions or we display raw list for now.
    // Let's assume for now we list "Workout Sessions" if we had a sessions table, 
    // but the current schema seems to have `workout_logs` per exercise/set?
    // Let's check schema in trainer_service.dart again.
    // `workout_logs(*, routine_exercises(*, exercises(*)))`
    // This returns individual set logs.
    
    final exerciseName = log['routine_exercises']?['exercises']?['name'] ?? 'Ejercicio';
    final weight = log['weight_kg'];
    final reps = log['reps_completed'];
    final rpe = log['rpe'];
    final date = DateTime.parse(log['created_at']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                ),
                if (rpe != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getRpeColor(rpe).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getRpeColor(rpe).withOpacity(0.3)),
                    ),
                    child: Text('RPE $rpe', style: TextStyle(color: _getRpeColor(rpe), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
             Text(
              exerciseName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBadge(icon: Icons.repeat_rounded, text: '$reps reps'),
                const SizedBox(width: 20),
                _StatBadge(icon: Icons.fitness_center_rounded, text: '${weight}kg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRpeColor(int rpe) {
    if (rpe < 6) return AppColors.success;
    if (rpe < 8) return AppColors.warning;
    return AppColors.error;
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StatBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: AppColors.primaryLight),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14)),
      ],
    );
  }
}

// Provider
final studentHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getStudentHistory(studentId);
});
