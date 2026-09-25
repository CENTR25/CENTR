import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';
import 'session_detail_screen.dart';

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

class _StudentHistoryScreenState extends ConsumerState<StudentHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Historial de ${widget.studentName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryLight,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textLight,
          tabs: const [
            Tab(text: 'Resumen'),
            Tab(text: 'Historial'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProgressDashboard(studentId: widget.studentId),
          _historyTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logInPerson,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Registro manual'),
      ),
    );
  }

  Widget _historyTab() {
    final historyAsync = ref.watch(studentHistoryProvider(widget.studentId));
    return historyAsync.when(
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
            return _WorkoutLogCard(
              log: log,
              onTap: log['routine_id'] == null ? null : () => _openSession(log),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }

  Future<void> _openSession(Map<String, dynamic> log) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(
          session: log,
          athleteId: log['athlete_id'] as String,
          routineId: log['routine_id'] as String,
          dayNumber: (log['day_number'] as int?) ?? 1,
          routineTitle: (log['routines']?['title'] as String?) ?? 'Rutina',
        ),
      ),
    );
    if (changed == true) {
      ref.invalidate(studentHistoryProvider(widget.studentId));
      ref.invalidate(athleteProgressProvider(widget.studentId));
    }
  }

  Future<void> _logInPerson() async {
    final service = ref.read(trainerServiceProvider);
    final routine = await service.getActiveRoutineForAthlete(widget.studentId);
    if (!mounted) return;
    if (routine == null || (routine['days'] as List).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El alumno no tiene una rutina activa')),
      );
      return;
    }

    final days = (routine['days'] as List).cast<int>();
    final day = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Elegí el día',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (final d in days)
              ListTile(
                title: Text(
                  'Día $d',
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.of(context).pop(d),
              ),
          ],
        ),
      ),
    );
    if (day == null || !mounted) return;

    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SessionDetailScreen(
          session: null,
          athleteId: widget.studentId,
          routineId: routine['routine_id'] as String,
          dayNumber: day,
          routineTitle: routine['title'] as String,
        ),
      ),
    );
    if (changed == true) {
      ref.invalidate(studentHistoryProvider(widget.studentId));
      ref.invalidate(athleteProgressProvider(widget.studentId));
    }
  }
}

class _WorkoutLogCard extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback? onTap;

  const _WorkoutLogCard({required this.log, this.onTap});

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
                      style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                ],
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

final athleteProgressProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getAthleteProgress(studentId);
});

/// Dashboard tab: summary counts + per-exercise weight progression over time.
class _ProgressDashboard extends ConsumerStatefulWidget {
  final String studentId;
  const _ProgressDashboard({required this.studentId});

  @override
  ConsumerState<_ProgressDashboard> createState() => _ProgressDashboardState();
}

class _ProgressDashboardState extends ConsumerState<_ProgressDashboard> {
  String? _selectedExercise;
  // null = show all series together; otherwise a single serie number.
  int? _selectedSet;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(athleteProgressProvider(widget.studentId));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
      data: (data) {
        final exercises =
            (data['exercises'] as Map<String, dynamic>? ?? {});
        final total = data['total_sessions'] as int? ?? 0;

        if (total == 0) {
          return Center(
            child: Text(
              'Sin entrenamientos registrados',
              style: TextStyle(color: AppColors.textLight),
            ),
          );
        }

        // Order exercises by most recently trained.
        final names = exercises.keys.toList()
          ..sort((a, b) {
            final la = (exercises[a] as List).last['date'] as String? ?? '';
            final lb = (exercises[b] as List).last['date'] as String? ?? '';
            return lb.compareTo(la);
          });
        final selected = _selectedExercise != null &&
                exercises.containsKey(_selectedExercise)
            ? _selectedExercise!
            : (names.isNotEmpty ? names.first : null);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _statsRow(data),
            const SizedBox(height: 20),
            if (selected != null) ...[
              Text(
                'Progreso por ejercicio',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              _exercisePicker(names, selected),
              const SizedBox(height: 12),
              Builder(
                builder: (_) {
                  final points = (exercises[selected] as List)
                      .cast<Map<String, dynamic>>();
                  final series = _seriesOf(points);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (series.length > 1) ...[
                        _setSelector(series),
                        const SizedBox(height: 12),
                      ],
                      _exerciseChart(points),
                    ],
                  );
                },
              ),
            ] else
              Text(
                'Aún no hay pesos registrados por ejercicio',
                style: TextStyle(color: AppColors.textLight),
              ),
          ],
        );
      },
    );
  }

  Widget _statsRow(Map<String, dynamic> data) {
    final total = data['total_sessions'] as int? ?? 0;
    final month = data['this_month'] as int? ?? 0;
    final lastRaw = data['last_date'] as String?;
    final last = lastRaw != null ? DateTime.tryParse(lastRaw)?.toLocal() : null;
    final lastLabel =
        last != null ? '${last.day}/${last.month}' : '—';

    return Row(
      children: [
        _statCard('Sesiones', '$total'),
        const SizedBox(width: 12),
        _statCard('Este mes', '$month'),
        const SizedBox(width: 12),
        _statCard('Última', lastLabel),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exercisePicker(List<String> names, String selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: AppColors.surface,
          style: const TextStyle(color: Colors.white),
          icon: Icon(Icons.expand_more, color: AppColors.textLight),
          items: [
            for (final n in names)
              DropdownMenuItem(value: n, child: Text(n)),
          ],
          onChanged: (v) => setState(() {
            _selectedExercise = v;
            _selectedSet = null; // series differ per exercise
          }),
        ),
      ),
    );
  }

  static const List<Color> _setColors = [
    AppColors.primary,
    AppColors.accent,
    AppColors.success,
    AppColors.info,
    AppColors.warning,
    AppColors.primaryLight,
  ];

  // Last 8 sessions (chronological), matching what the chart plots.
  List<Map<String, dynamic>> _recent(List<Map<String, dynamic>> points) =>
      points.length > 8 ? points.sublist(points.length - 8) : points;

  // Sorted serie numbers present across the recent window.
  List<int> _seriesOf(List<Map<String, dynamic>> points) {
    final setNums = <int>{};
    for (final p in _recent(points)) {
      (p['sets'] as Map<String, dynamic>? ?? {}).forEach((k, _) {
        final n = int.tryParse(k);
        if (n != null) setNums.add(n);
      });
    }
    return setNums.toList()..sort();
  }

  // Chips to view all series together or isolate a single serie's graph.
  Widget _setSelector(List<int> series) {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textLight,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        chip('Todas', _selectedSet == null,
            () => setState(() => _selectedSet = null)),
        for (final s in series)
          chip('Serie $s', _selectedSet == s,
              () => setState(() => _selectedSet = s)),
      ],
    );
  }

  // Best (max) weight logged in a session, across all its sets.
  num _sessionMax(Map<String, dynamic> point) {
    num m = 0;
    (point['sets'] as Map<String, dynamic>? ?? {}).forEach((_, v) {
      if (v is num && v > m) m = v;
    });
    return m;
  }

  Widget _exerciseChart(List<Map<String, dynamic>> points) {
    // Last 8 sessions, chronological.
    final recent = points.length > 8
        ? points.sublist(points.length - 8)
        : points;

    // Union of all serie numbers seen, sorted (Serie 1, 2, 3...).
    final setNums = <int>{};
    for (final p in recent) {
      (p['sets'] as Map<String, dynamic>? ?? {}).forEach((k, _) {
        final n = int.tryParse(k);
        if (n != null) setNums.add(n);
      });
    }
    final sortedSets = setNums.toList()..sort();
    // When a single serie is selected, isolate it into its own graph.
    final activeSet = (_selectedSet != null && sortedSets.contains(_selectedSet))
        ? _selectedSet
        : null;

    // One line per serie; track global min/max for the Y axis.
    double? maxW;
    double? minW;
    final bars = <LineChartBarData>[];
    for (int si = 0; si < sortedSets.length; si++) {
      final setNum = sortedSets[si];
      if (activeSet != null && setNum != activeSet) continue;
      final color = _setColors[si % _setColors.length];
      final barSpots = <FlSpot>[];
      for (int i = 0; i < recent.length; i++) {
        final sets = recent[i]['sets'] as Map<String, dynamic>? ?? {};
        final w = sets['$setNum'];
        if (w is num) {
          final y = w.toDouble();
          barSpots.add(FlSpot(i.toDouble(), y));
          maxW = (maxW == null || y > maxW) ? y : maxW;
          minW = (minW == null || y < minW) ? y : minW;
        }
      }
      if (barSpots.isEmpty) continue;
      bars.add(
        LineChartBarData(
          spots: barSpots,
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) =>
                FlDotCirclePainter(
              radius: 3.5,
              color: color,
              strokeWidth: 2,
              strokeColor: Colors.white,
            ),
          ),
        ),
      );
    }

    maxW ??= 0;
    minW ??= 0;
    // Header/delta reflect the isolated serie when one is selected.
    num sessionValue(Map<String, dynamic> point) => activeSet != null
        ? ((point['sets'] as Map<String, dynamic>?)?['$activeSet'] as num? ?? 0)
        : _sessionMax(point);
    final lastMax = sessionValue(recent.last);
    final delta = recent.length >= 2
        ? lastMax - sessionValue(recent[recent.length - 2])
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${lastMax.toString().replaceAll('.0', '')} kg',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              const SizedBox(width: 10),
              if (delta != 0)
                Row(
                  children: [
                    Icon(
                      delta > 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 16,
                      color: delta > 0 ? AppColors.success : AppColors.error,
                    ),
                    Text(
                      '${delta.abs().toString().replaceAll('.0', '')} kg vs anterior',
                      style: TextStyle(
                        color: delta > 0 ? AppColors.success : AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= recent.length) {
                          return const SizedBox.shrink();
                        }
                        final d = DateTime.tryParse(
                          recent[i]['date'] as String? ?? '',
                        )?.toLocal();
                        if (d == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.textLight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (recent.length - 1).toDouble(),
                minY: (minW - 5).clamp(0, double.infinity).toDouble(),
                maxY: maxW + 5,
                lineBarsData: bars,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Legend: which colour is which serie.
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (int si = 0; si < sortedSets.length; si++)
                if (activeSet == null || sortedSets[si] == activeSet)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _setColors[si % _setColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Serie ${sortedSets[si]}',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
