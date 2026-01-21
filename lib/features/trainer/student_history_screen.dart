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
      appBar: AppBar(
        title: Text('Historial de ${widget.studentName}'),
      ),
      body: historyAsync.when(
        data: (logs) {
          if (logs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Sin historial de entrenamientos'),
                ],
              ),
            );
          }

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (rpe != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRpeColor(rpe),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('RPE $rpe', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
             Text(
              exerciseName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatBadge(icon: Icons.repeat, text: '$reps reps'),
                const SizedBox(width: 12),
                _StatBadge(icon: Icons.fitness_center, text: '${weight}kg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getRpeColor(int rpe) {
    if (rpe < 6) return Colors.green;
    if (rpe < 8) return Colors.orange;
    return Colors.red;
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
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// Provider
final studentHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getStudentHistory(studentId);
});
