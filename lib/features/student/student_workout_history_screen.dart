import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import '../trainer/session_detail_screen.dart';

/// Student's own completed workout history (drawer → "Historial de
/// Entrenamientos"). Tapping a session opens it in edit mode so the athlete can
/// correct a mis-typed weight/rep after finishing.
final myWorkoutSessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(studentServiceProvider).getMyWorkoutSessions();
});

class StudentWorkoutHistoryScreen extends ConsumerWidget {
  const StudentWorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(myWorkoutSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Historial de Entrenamientos',
          style: TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                'Todavía no registraste entrenamientos',
                style: TextStyle(color: AppColors.textLight),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) => _SessionCard(
              session: list[i],
              onTap: () => _edit(context, ref, list[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> session,
  ) async {
    final routineId = session['routine_id'] as String?;
    if (routineId == null) return; // legacy rows with no routine can't be edited
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(
          session: session,
          athleteId: session['athlete_id'] as String,
          routineId: routineId,
          dayNumber: (session['day_number'] as int?) ?? 1,
          routineTitle: (session['routines']?['title'] as String?) ?? 'Rutina',
          isStudentEdit: true,
        ),
      ),
    );
    if (changed == true) ref.invalidate(myWorkoutSessionsProvider);
  }
}

class _SessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final routineName = session['routines']?['title'] ?? 'Rutina';
    final dayNumber = session['day_number'] as int?;
    final setsCompleted = session['sets_completed'] as int? ?? 0;
    final durationSeconds = session['duration_seconds'] as int? ?? 0;
    // DB stores UTC; show the phone's local date/time.
    final date = DateTime.parse(
      (session['started_at'] ?? session['created_at']) as String,
    ).toLocal();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.edit_outlined,
                          color: AppColors.primaryLight, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Editar',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                dayNumber != null ? '$routineName — Día $dayNumber' : routineName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatBadge(
                      icon: Icons.repeat_rounded,
                      text: '$setsCompleted series'),
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
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
