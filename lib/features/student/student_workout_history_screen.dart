import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';
import '../trainer/session_detail_screen.dart';

/// Student's own workout history (Entrenar → history button). Tapping a session
/// opens it in edit mode so the athlete can correct a mis-typed weight/rep.
/// Completed sessions show a green check; abandoned ones an amber marker.
final myWorkoutSessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(studentServiceProvider).getMyWorkoutSessions();
});

class StudentWorkoutHistoryScreen extends ConsumerWidget {
  const StudentWorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(myWorkoutSessionsProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          centerTitle: true,
          title: const Text(
            'Historial de Entrenamiento',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
        body: sessions.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(RedesignColors.actionPrimary),
            ),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: RedesignColors.primario300)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Todavía no registraste entrenamientos',
                  style: TextStyle(
                    color: RedesignColors.primario400,
                    fontFamily: 'Metropolis',
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, i) => _SessionCard(
                session: list[i],
                onTap: () => _edit(context, ref, list[i]),
              ),
            );
          },
        ),
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
    final isCompleted = session['is_completed'] as bool? ?? false;
    // DB stores UTC; show the phone's local date/time.
    final date = DateTime.parse(
      (session['started_at'] ?? session['created_at']) as String,
    ).toLocal();

    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr =
        '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    final durationStr = '${mins}m ${secs}s';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            // Status marker
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isCompleted
                    ? RedesignColors.success
                    : RedesignColors.advertencia400,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted ? Icons.check_rounded : Icons.timer_outlined,
                color: isCompleted ? Colors.white : RedesignColors.primario900,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario50,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario50,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayNumber != null
                        ? '$routineName — Día $dayNumber'
                        : routineName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario300,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 15, color: RedesignColors.primario400),
                      const SizedBox(width: 5),
                      Text(
                        durationStr,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario300,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 18),
                      const Icon(Icons.repeat_rounded,
                          size: 15, color: RedesignColors.primario400),
                      const SizedBox(width: 5),
                      Text(
                        '$setsCompleted series',
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario300,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario400),
          ],
        ),
      ),
    );
  }
}
