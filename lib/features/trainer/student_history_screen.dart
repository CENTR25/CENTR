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
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Icon(Icons.history_rounded, size: 64, color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sin historial de entrenamientos',
                    style: TextStyle(color: AppColors.textLight, fontSize: 16),
                  ),
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
    // Each row is a completed workout_sessions record
    final routineName = log['routines']?['title'] ?? 'Rutina';
    final dayNumber = log['day_number'] as int?;
    final setsCompleted = log['sets_completed'] as int? ?? 0;
    final durationSeconds = log['duration_seconds'] as int? ?? 0;
    // toLocal(): the DB stores UTC; show the phone's local date/time
    final date = DateTime.parse(
      (log['started_at'] ?? log['created_at']) as String,
    ).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
             Text(
              dayNumber != null ? '$routineName — Día $dayNumber' : routineName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatBadge(icon: Icons.repeat_rounded, text: '$setsCompleted series'),
                const SizedBox(width: 20),
                _StatBadge(
                  icon: Icons.timer_rounded,
                  text: '${(durationSeconds / 60).round()} min',
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
            color: AppColors.primary.withValues(alpha: 0.1),
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
