import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
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
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: RedesignColors.primario50),
          centerTitle: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Historial',
                style: RedesignType.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: RedesignColors.primario50,
                ),
              ),
              Text(
                widget.studentName,
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario300,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                onPressed: _logInPerson,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RedesignColors.secundario500,
                  side: const BorderSide(
                    color: RedesignColors.secundario500,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
                  ),
                  textStyle: RedesignType.buttonSm,
                ),
                child: const Text('+ Registrar'),
              ),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: RedesignColors.secundario500,
            indicatorWeight: 2,
            labelColor: RedesignColors.secundario500,
            unselectedLabelColor: RedesignColors.primario300,
            labelStyle: RedesignType.buttonSm.copyWith(
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: RedesignType.buttonSm,
            tabs: const [
              Tab(text: 'Resumen'),
              Tab(text: 'Sesiones'),
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
                    color: RedesignColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RedesignColors.secundario300.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    size: 64,
                    color: RedesignColors.primario400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sin historial de entrenamientos',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario400,
                  ),
                ),
              ],
            ),
          );
        }

        // Group logs by ISO week (Monday-based)
        final grouped = <String, List<Map<String, dynamic>>>{};
        for (final log in logs) {
          final date = DateTime.parse(
            (log['started_at'] ?? log['created_at']) as String,
          ).toLocal();
          final weekKey = _weekKey(date);
          grouped.putIfAbsent(weekKey, () => []).add(log);
        }
        final weeks = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: weeks.length,
          itemBuilder: (context, wi) {
            final weekLogs = grouped[weeks[wi]]!;
            return _WeekGroup(
              weekKey: weeks[wi],
              logs: weekLogs,
              onTap: (log) {
                if (log['routine_id'] != null) _openSession(log);
              },
            );
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(RedesignColors.actionPrimary),
        ),
      ),
      error: (e, s) => Center(
        child: Text(
          'Error: $e',
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
      ),
    );
  }

  /// Returns an ISO-week string "YYYY-Www" for grouping, e.g. "2024-W42".
  String _weekKey(DateTime d) {
    // Monday of that week
    final monday = d.subtract(Duration(days: d.weekday - 1));
    final weekNum = ((monday.difference(DateTime(monday.year)).inDays) / 7).ceil();
    return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
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
    Map<String, dynamic>? routine;
    try {
      routine = await service.getActiveRoutineForAthlete(widget.studentId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar la rutina: $e'),
          backgroundColor: RedesignColors.danger,
        ),
      );
      return;
    }
    if (!mounted) return;
    if (routine == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El alumno no tiene una rutina activa'),
          backgroundColor: RedesignColors.warning,
        ),
      );
      return;
    }
    final days = (routine['days'] as List).cast<int>();
    if (days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La rutina activa no tiene días configurados'),
          backgroundColor: RedesignColors.warning,
        ),
      );
      return;
    }

    final day = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: RedesignColors.primario800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RedesignRadius.card),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: RedesignColors.primario500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Elegí el día',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final d in days)
              ListTile(
                title: Text(
                  'Día $d',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: RedesignColors.primario300,
                ),
                onTap: () => Navigator.of(context).pop(d),
              ),
            const SizedBox(height: 8),
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
          routineId: routine!['routine_id'] as String,
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

// ---------------------------------------------------------------------------
// Week group header + session rows inside a rounded navy card
// ---------------------------------------------------------------------------

class _WeekGroup extends StatelessWidget {
  final String weekKey;
  final List<Map<String, dynamic>> logs;
  final void Function(Map<String, dynamic>) onTap;

  const _WeekGroup({
    required this.weekKey,
    required this.logs,
    required this.onTap,
  });

  String _weekLabel(String key) {
    // Parse the first log's date to derive start/end label
    try {
      final parts = key.split('-W');
      final year = int.parse(parts[0]);
      final week = int.parse(parts[1]);
      final jan4 = DateTime(year, 1, 4);
      final monday = jan4.subtract(Duration(days: jan4.weekday - 1))
          .add(Duration(days: (week - 1) * 7));
      final sunday = monday.add(const Duration(days: 6));
      final now = DateTime.now();
      final thisMonday = now.subtract(Duration(days: now.weekday - 1));
      if (monday.isAtSameMomentAs(thisMonday) ||
          (monday.isBefore(now) && sunday.isAfter(now))) {
        return 'Esta semana';
      }
      final months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];
      return '${monday.day} - ${sunday.day} ${months[sunday.month - 1]}';
    } catch (_) {
      return weekKey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Week header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _weekLabel(weekKey),
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${logs.length} sesión${logs.length == 1 ? '' : 'es'}',
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario400,
                ),
              ),
            ],
          ),
        ),
        // Sessions card
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: RedesignColors.surface,
            borderRadius: BorderRadius.circular(RedesignRadius.card),
            border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < logs.length; i++) ...[
                _SessionRow(
                  log: logs[i],
                  onTap: logs[i]['routine_id'] == null
                      ? null
                      : () => onTap(logs[i]),
                ),
                if (i < logs.length - 1)
                  Divider(
                    height: 1,
                    color: RedesignColors.primario600.withValues(alpha: 0.5),
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  final Map<String, dynamic> log;
  final VoidCallback? onTap;

  const _SessionRow({required this.log, this.onTap});

  static const _weekdays = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];

  @override
  Widget build(BuildContext context) {
    final routineName = log['routines']?['title'] ?? 'Rutina';
    final dayNumber = log['day_number'] as int?;
    final setsCompleted = log['sets_completed'] as int? ?? 0;
    final durationSeconds = log['duration_seconds'] as int? ?? 0;
    final date = DateTime.parse(
      (log['started_at'] ?? log['created_at']) as String,
    ).toLocal();
    final weekdayAbbr = _weekdays[(date.weekday - 1) % 7];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RedesignRadius.card),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Date block
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${date.day}',
                  style: RedesignType.bodyMd.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  weekdayAbbr,
                  style: RedesignType.label.copyWith(
                    color: RedesignColors.secundario300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayNumber != null ? 'Día $dayNumber - $routineName' : routineName,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${date.hour}:${date.minute.toString().padLeft(2, '0')} · $setsCompleted series · ${(durationSeconds / 60).round()} min',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.primario400,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right,
                color: RedesignColors.primario300,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// Providers
final studentHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getStudentHistory(studentId);
});

final athleteProgressProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getAthleteProgress(studentId);
});

// ---------------------------------------------------------------------------
// "Resumen" tab — stats header + exercise progress chart
// ---------------------------------------------------------------------------

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
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(RedesignColors.actionPrimary),
        ),
      ),
      error: (e, s) => Center(
        child: Text(
          'Error: $e',
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
      ),
      data: (data) {
        final exercises =
            (data['exercises'] as Map<String, dynamic>? ?? {});
        final total = data['total_sessions'] as int? ?? 0;

        if (total == 0) {
          return Center(
            child: Text(
              'Sin entrenamientos registrados',
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario400,
              ),
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            _statsRow(data),
            const SizedBox(height: 24),
            if (selected != null) ...[
              Text(
                'Progreso por ejercicio',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario300,
                  fontWeight: FontWeight.w600,
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
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario400,
                ),
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
          color: RedesignColors.surface,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: RedesignType.bodyMd.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: RedesignType.label.copyWith(
                color: RedesignColors.primario400,
              ),
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
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.input),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          dropdownColor: RedesignColors.primario700,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          icon: const Icon(
            Icons.expand_more,
            color: RedesignColors.primario300,
          ),
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
    RedesignColors.actionPrimary,
    RedesignColors.secundario500,
    RedesignColors.success,
    RedesignColors.secundario200,
    RedesignColors.warning,
    RedesignColors.secundario300,
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
    Widget chip(String label, bool isSelected, VoidCallback onTap) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? RedesignColors.secundario300
                : const Color(0x4081E1CA),
            borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
            border: Border.all(
              color: RedesignColors.secundario300,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: RedesignType.buttonSm.copyWith(
              color: isSelected
                  ? RedesignColors.secundario900
                  : RedesignColors.secundario300,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          chip('Todas', _selectedSet == null,
              () => setState(() => _selectedSet = null)),
          for (final s in series)
            chip('Serie $s', _selectedSet == s,
                () => setState(() => _selectedSet = s)),
        ],
      ),
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
              strokeColor: RedesignColors.background,
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
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${lastMax.toString().replaceAll('.0', '')} kg',
                style: RedesignType.bodyMd.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
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
                      color: delta > 0
                          ? RedesignColors.success
                          : RedesignColors.danger,
                    ),
                    Text(
                      '${delta.abs().toString().replaceAll('.0', '')} kg vs anterior',
                      style: RedesignType.label.copyWith(
                        color: delta > 0
                            ? RedesignColors.success
                            : RedesignColors.danger,
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
                    color: RedesignColors.primario50.withValues(alpha: 0.05),
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
                          style: RedesignType.label.copyWith(
                            color: RedesignColors.primario400,
                            fontSize: 10,
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
                            style: RedesignType.label.copyWith(
                              color: RedesignColors.primario400,
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario300,
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
