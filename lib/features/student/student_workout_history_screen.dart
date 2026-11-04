import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';

/// Student's own workout history (Entrenar → history button). Read-only: tapping
/// a session expands it in place to show the recorded series. The athlete cannot
/// edit a session — corrections go through the trainer. Completed sessions show a
/// green check; abandoned ones an amber marker.
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
              itemBuilder: (context, i) => _SessionCard(session: list[i]),
            );
          },
        ),
      ),
    );
  }
}

/// A single history row that expands in place to reveal the recorded series.
class _SessionCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> session;

  const _SessionCard({required this.session});

  @override
  ConsumerState<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends ConsumerState<_SessionCard> {
  bool _expanded = false;
  Future<List<Map<String, dynamic>>>? _exercisesFuture;

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      // Lazy-load the routine's exercise names the first time we expand.
      if (_expanded && _exercisesFuture == null) {
        final routineId = widget.session['routine_id'] as String?;
        final dayNumber = (widget.session['day_number'] as num?)?.toInt() ?? 1;
        _exercisesFuture = routineId == null
            ? Future.value(const <Map<String, dynamic>>[])
            : ref
                .read(studentServiceProvider)
                .getSessionExercises(routineId, dayNumber);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final isCompleted = session['is_completed'] as bool? ?? false;
    final setsCompleted = (session['sets_completed'] as num?)?.toInt() ?? 0;
    final durationSeconds =
        (session['duration_seconds'] as num?)?.toInt() ?? 0;
    // DB stores UTC; show the phone's local date/time.
    final date = DateTime.parse(
      (session['started_at'] ?? session['created_at']) as String,
    ).toLocal();

    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    final durationStr = '${durationSeconds ~/ 60}m ${durationSeconds % 60}s';

    return Container(
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted
              ? RedesignColors.success.withValues(alpha: 0.45)
              : RedesignColors.primario600,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Collapsed header (always visible, tappable)
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Status marker — green check (completed) / brown timer (abandoned)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? RedesignColors.success
                          : RedesignColors.advertencia600,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCompleted ? Icons.check_rounded : Icons.timer_outlined,
                      color: isCompleted
                          ? Colors.white
                          : RedesignColors.advertencia900,
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
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontFamily: 'Metropolis',
                                color: RedesignColors.primario50,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
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
                            const Spacer(),
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
                  const SizedBox(width: 12),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: RedesignColors.primario400),
                  ),
                ],
              ),
            ),
          ),

          // Expanded detail (recorded series, read-only)
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _ExpandedDetail(
              session: session,
              exercisesFuture: _exercisesFuture,
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

/// Read-only list of the recorded series for a session, grouped by exercise.
class _ExpandedDetail extends StatelessWidget {
  final Map<String, dynamic> session;
  final Future<List<Map<String, dynamic>>>? exercisesFuture;

  const _ExpandedDetail({
    required this.session,
    required this.exercisesFuture,
  });

  static String _fmtNum(dynamic v) {
    if (v == null) return '–';
    if (v is num) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final setLogs = session['set_logs'] as Map<String, dynamic>? ?? const {};
    final repsLogs = session['reps_logs'] as Map<String, dynamic>? ?? const {};
    final routineName = session['routines']?['title'] as String? ?? 'Rutina';
    final dayNumber = (session['day_number'] as num?)?.toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: RedesignColors.primario600),
          const SizedBox(height: 14),
          Text(
            dayNumber != null ? '$routineName — Día $dayNumber' : routineName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.secundario300,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (setLogs.isEmpty)
            const Text(
              'Sin series registradas',
              style: TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario400,
                fontSize: 13,
              ),
            )
          else
            FutureBuilder<List<Map<String, dynamic>>>(
              future: exercisesFuture,
              builder: (context, snap) {
                final exercises = snap.data ?? const [];
                // set_logs is keyed by exercise_id (UUID); map each id to its
                // name and the routine's order_index for labelling + ordering.
                final nameById = <String, String>{};
                final orderById = <String, int>{};
                for (var i = 0; i < exercises.length; i++) {
                  final id = exercises[i]['exercise_id'] as String?;
                  if (id == null) continue;
                  nameById[id] =
                      exercises[i]['exercises']?['name'] as String? ?? '';
                  orderById[id] =
                      (exercises[i]['order_index'] as num?)?.toInt() ?? i;
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final id in _orderedExerciseIds(setLogs, orderById))
                      _exerciseBlock(id, nameById, setLogs, repsLogs),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  /// Exercise ids present in the logs, ordered by the routine's order_index.
  /// Ids no longer in the routine (e.g. an exercise removed after the session)
  /// sort last but stay visible.
  List<String> _orderedExerciseIds(
    Map<String, dynamic> setLogs,
    Map<String, int> orderById,
  ) {
    final keys = setLogs.keys.toList()
      ..sort((a, b) =>
          (orderById[a] ?? 1 << 30).compareTo(orderById[b] ?? 1 << 30));
    return keys;
  }

  Widget _exerciseBlock(
    String exId,
    Map<String, String> nameById,
    Map<String, dynamic> setLogs,
    Map<String, dynamic> repsLogs,
  ) {
    final resolved = nameById[exId];
    final name =
        (resolved != null && resolved.isNotEmpty) ? resolved : 'Ejercicio';

    final exWeights = setLogs[exId] as Map<String, dynamic>? ?? const {};
    final exReps = repsLogs[exId] as Map<String, dynamic>? ?? const {};
    final setNumbers = exWeights.keys
        .map((k) => int.tryParse(k))
        .whereType<int>()
        .toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final s in setNumbers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 66,
                    child: Text(
                      'Serie $s',
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.primario400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmtNum(exWeights['$s'])} kg × ${_fmtNum(exReps['$s'])} reps',
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario200,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
