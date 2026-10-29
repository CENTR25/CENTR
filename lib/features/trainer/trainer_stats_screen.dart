import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import 'student_detail_screen.dart';

// ---------------------------------------------------------------------------
// TrainerStatsScreen (Figma "Estadísticas")
//
// Range chips (7 / 30 / 90 días) over two metric cards (Adherencia +Δ,
// Entrenamientos completados), a "Requieren atención" list, and an
// "Adherencia por alumno" bar list. Data from TrainerService.getAdherenceStats.
// ---------------------------------------------------------------------------

const _kRanges = [
  (label: '7 días', days: 7),
  (label: '30 días', days: 30),
  (label: '3 meses', days: 90),
];

class TrainerStatsScreen extends ConsumerStatefulWidget {
  const TrainerStatsScreen({super.key});

  @override
  ConsumerState<TrainerStatsScreen> createState() => _TrainerStatsScreenState();
}

class _TrainerStatsScreenState extends ConsumerState<TrainerStatsScreen> {
  int _rangeIndex = 1; // default 30 días
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() =>
      ref.read(trainerServiceProvider).getAdherenceStats(_kRanges[_rangeIndex].days);

  void _selectRange(int i) {
    if (i == _rangeIndex) return;
    setState(() {
      _rangeIndex = i;
      _future = _load();
    });
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Estadísticas',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState == ConnectionState.waiting;
            final data = snapshot.data;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                // ── Range chips ─────────────────────────────────────────
                Row(
                  children: [
                    for (var i = 0; i < _kRanges.length; i++) ...[
                      _Chip(
                        label: _kRanges[i].label,
                        selected: _rangeIndex == i,
                        onTap: () => _selectRange(i),
                      ),
                      if (i != _kRanges.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                          color: RedesignColors.actionPrimary),
                    ),
                  )
                else if (data == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text('No se pudieron cargar las estadísticas',
                          style:
                              TextStyle(color: RedesignColors.primario300)),
                    ),
                  )
                else
                  ..._buildContent(context, data),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(BuildContext context, Map<String, dynamic> data) {
    final adherence = (data['adherence'] as num?)?.toDouble() ?? 0;
    final delta = (data['adherence_delta'] as num?)?.toDouble() ?? 0;
    final completed = (data['completed'] as num?)?.toInt() ?? 0;
    final perStudent =
        List<Map<String, dynamic>>.from(data['per_student'] as List? ?? []);
    final attention =
        List<Map<String, dynamic>>.from(data['attention'] as List? ?? []);

    final withAdherence =
        perStudent.where((s) => s['adherence'] != null).toList();
    final topStudents = withAdherence.take(3).toList();

    return [
      // ── Metric cards ──────────────────────────────────────────────────
      Row(
        children: [
          Expanded(
            child: _MetricCard(
              label: 'Adherencia',
              value: '${(adherence * 100).round()}%',
              footer: _DeltaFooter(delta: delta),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _MetricCard(
              label: 'Entrenamientos',
              value: '$completed',
              footer: Text(
                'completados',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),

      // ── Requieren atención ────────────────────────────────────────────
      if (attention.isNotEmpty) ...[
        _SectionTitle('Requieren atención'),
        const SizedBox(height: 12),
        for (final s in attention) _AttentionCard(student: s),
        const SizedBox(height: 16),
      ],

      // ── Adherencia por alumno ─────────────────────────────────────────
      _SectionTitle('Adherencia por alumno'),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
        child: topStudents.isEmpty
            ? Text(
                'Todavía no hay datos de adherencia.',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300),
              )
            : Column(
                children: [
                  for (final s in topStudents) _AdherenceBar(student: s),
                  if (withAdherence.length > topStudents.length) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () => _showAllStudents(context, withAdherence),
                      child: Text(
                        'Ver los ${withAdherence.length} alumnos',
                        style: RedesignType.buttonSm.copyWith(
                          color: RedesignColors.actionPrimaryDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    ];
  }

  void _showAllStudents(
      BuildContext context, List<Map<String, dynamic>> students) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: RedesignColors.primario800,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Adherencia por alumno',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  children: [
                    for (final s in students) _AdherenceBar(student: s),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: RedesignType.bodySm.copyWith(
          color: RedesignColors.primario50,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1 : 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.secundario900
                : RedesignColors.secundario300,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Widget footer;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300)),
          const SizedBox(height: 8),
          Text(
            value,
            style: RedesignType.headingMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 6),
          footer,
        ],
      ),
    );
  }
}

class _DeltaFooter extends StatelessWidget {
  final double delta;
  const _DeltaFooter({required this.delta});

  @override
  Widget build(BuildContext context) {
    final pct = (delta * 100).round();
    final positive = pct >= 0;
    final color =
        positive ? RedesignColors.actionPrimaryDark : RedesignColors.danger;
    return Text(
      '${positive ? '+' : ''}$pct%  vs. anterior',
      style: RedesignType.label.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _AttentionCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = (student['name'] ?? 'Alumno').toString();
    final reason = (student['reason'] ?? '').toString();
    final avatarUrl = student['avatar_url'] as String?;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  StudentDetailScreen(studentId: student['id'] as String),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: RedesignColors.primario700,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(initial,
                          style: const TextStyle(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w700,
                          ))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: RedesignColors.primario300, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdherenceBar extends StatelessWidget {
  final Map<String, dynamic> student;
  const _AdherenceBar({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = (student['name'] ?? 'Alumno').toString();
    final adh = (student['adherence'] as num?)?.toDouble() ?? 0;
    final pct = (adh * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: adh.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: RedesignColors.primario600,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  RedesignColors.actionPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
