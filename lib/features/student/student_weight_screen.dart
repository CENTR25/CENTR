import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';
import 'student_meal_plan_screen.dart';
import 'student_routine_screen.dart';
import 'widgets/student_bottom_nav.dart';

const _monthAbbr = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Student "Registrar peso" — PRGS navy/teal redesign (Figma). Big tappable
/// weight display + teal Guardar; on save → success state; history card with a
/// 1M / 3M / Todo range toggle, delta label and a teal line chart.
class StudentWeightScreen extends ConsumerStatefulWidget {
  const StudentWeightScreen({super.key});

  @override
  ConsumerState<StudentWeightScreen> createState() =>
      _StudentWeightScreenState();
}

class _StudentWeightScreenState extends ConsumerState<StudentWeightScreen> {
  final TextEditingController _weightController = TextEditingController();
  bool _isLoading = false;
  bool _saved = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveWeight() async {
    // Accept the Spanish decimal comma (5,4) as well as a dot.
    final weight =
        double.tryParse(_weightController.text.trim().replaceAll(',', '.'));
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresá un peso válido')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(studentServiceProvider).logMetrics(weight: weight);
      ref.invalidate(myWeightHistoryProvider);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.peligro300,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetToForm() {
    _weightController.clear();
    setState(() => _saved = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          centerTitle: true,
          title: const Text(
            'Registrar peso',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
        bottomNavigationBar: StudentBottomNav(
          active: StudentNavTab.inicio,
          onInicioTap: () => Navigator.popUntil(context, (r) => r.isFirst),
          onEntrenarTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentRoutineScreen(),
              fullscreenDialog: true,
            ),
          ),
          onNutricionTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StudentMealPlanScreen()),
          ),
        ),
        body: _saved ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  // ─── Form view ─────────────────────────────────────────────────────────────

  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Nuevo registro',
              style: TextStyle(
                color: RedesignColors.primario50,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Big weight display (editable)
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    textAlign: TextAlign.center,
                    cursorColor: RedesignColors.actionPrimary,
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: RedesignColors.primario50,
                      fontFamily: 'Metropolis',
                      height: 1.0,
                    ),
                    decoration: const InputDecoration(
                      // No themed pill behind the number — matches Figma.
                      filled: false,
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '0.0',
                      hintStyle: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: RedesignColors.primario500,
                        fontFamily: 'Metropolis',
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: RedesignColors.primario400,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Guardar
          ElevatedButton(
            onPressed: _isLoading ? null : _saveWeight,
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.actionPrimary,
              foregroundColor: RedesignColors.onActionPrimary,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        RedesignColors.onActionPrimary,
                      ),
                    ),
                  )
                : const Text(
                    'Guardar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Metropolis',
                    ),
                  ),
          ),
          const SizedBox(height: 36),

          // Historial
          Row(
            children: [
              const Icon(Icons.history_rounded,
                  color: RedesignColors.primario50, size: 22),
              const SizedBox(width: 8),
              const Text(
                'Historial',
                style: TextStyle(
                  color: RedesignColors.primario50,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Metropolis',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Consumer(
            builder: (context, ref, _) {
              final historyAsync = ref.watch(myWeightHistoryProvider);
              return historyAsync.when(
                data: (history) => history.isEmpty
                    ? const _HistoryPlaceholder(
                        text:
                            'Ingresá un nuevo peso para guardar en el historial',
                      )
                    : _HistoryCard(history: history),
                loading: () => const _HistoryPlaceholder(
                  text: 'Cargando…',
                ),
                error: (_, __) => const _HistoryPlaceholder(
                  text: 'No se pudo cargar el historial',
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Success view ────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: RedesignColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Peso registrado!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Hemos subido tu peso al historial',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RedesignColors.primario300,
              fontSize: 15,
              fontFamily: 'Metropolis',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _resetToForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.actionPrimary,
              foregroundColor: RedesignColors.onActionPrimary,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Volver al registro',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.primario700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Ir al inicio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History placeholder (empty / loading / error)
// ---------------------------------------------------------------------------

class _HistoryPlaceholder extends StatelessWidget {
  final String text;
  const _HistoryPlaceholder({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(20),
      alignment: Alignment.topLeft,
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: RedesignColors.primario400,
          fontSize: 15,
          fontFamily: 'Metropolis',
          height: 1.4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// History card — range toggle + delta + line chart
// ---------------------------------------------------------------------------

enum _Range { oneMonth, threeMonths, all }

class _HistoryCard extends StatefulWidget {
  final List<Map<String, dynamic>> history; // oldest-first, non-empty
  const _HistoryCard({required this.history});

  @override
  State<_HistoryCard> createState() => _HistoryCardState();
}

class _HistoryCardState extends State<_HistoryCard> {
  _Range _range = _Range.threeMonths;

  DateTime? _entryDate(Map<String, dynamic> e) {
    final raw = e['date'] ?? e['created_at'];
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  double? _weight(Map<String, dynamic> e) =>
      (e['body_weight'] as num?)?.toDouble();

  List<Map<String, dynamic>> get _filtered {
    if (_range == _Range.all) return widget.history;
    final days = _range == _Range.oneMonth ? 30 : 90;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final f = widget.history.where((e) {
      final d = _entryDate(e);
      return d == null || !d.isBefore(cutoff);
    }).toList();
    return f.isEmpty ? widget.history : f;
  }

  String _shortDate(DateTime d) => '${d.day} ${_monthAbbr[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final latest = _weight(widget.history.last);
    final firstW = _weight(filtered.first);
    final firstDate = _entryDate(filtered.first);
    final delta = (latest != null && firstW != null) ? latest - firstW : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Peso',
                      style: TextStyle(
                        color: RedesignColors.primario300,
                        fontSize: 14,
                        fontFamily: 'Metropolis',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          latest != null
                              ? latest.toStringAsFixed(1)
                              : '-',
                          style: const TextStyle(
                            color: RedesignColors.primario50,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Metropolis',
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'kg',
                          style: TextStyle(
                            color: RedesignColors.primario400,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Metropolis',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _RangeToggle(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
            ],
          ),
          if (delta != null && firstDate != null) ...[
            const SizedBox(height: 6),
            Text(
              '${_fmtDelta(delta)} desde el ${_shortDate(firstDate)}',
              style: const TextStyle(
                color: RedesignColors.success,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Metropolis',
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(height: 160, child: _buildChart(filtered)),
          if (filtered.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 12),
            const Text(
              'Registros',
              style: TextStyle(
                color: RedesignColors.primario300,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Metropolis',
              ),
            ),
            const SizedBox(height: 6),
            _buildRecordList(filtered),
          ],
        ],
      ),
    );
  }

  /// A newest-first list of each individual weight recording: date, value and
  /// the delta versus the previous (older) entry.
  Widget _buildRecordList(List<Map<String, dynamic>> data) {
    // data is oldest-first; render newest-first.
    final rows = <Widget>[];
    for (var i = data.length - 1; i >= 0; i--) {
      final w = _weight(data[i]);
      if (w == null) continue;
      final d = _entryDate(data[i]);
      final prev = i > 0 ? _weight(data[i - 1]) : null;
      final delta = prev != null ? w - prev : null;
      rows.add(_recordRow(d, w, delta));
    }
    return Column(children: rows);
  }

  Widget _recordRow(DateTime? date, double weight, double? delta) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date != null ? _longDate(date) : '-',
              style: const TextStyle(
                color: RedesignColors.primario300,
                fontSize: 14,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
          if (delta != null && delta != 0) ...[
            Text(
              _fmtDelta(delta),
              style: const TextStyle(
                color: RedesignColors.primario400,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                fontFamily: 'Metropolis',
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            weight.toStringAsFixed(1),
            style: const TextStyle(
              color: RedesignColors.primario50,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(width: 3),
          const Text(
            'kg',
            style: TextStyle(
              color: RedesignColors.primario400,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Metropolis',
            ),
          ),
        ],
      ),
    );
  }

  String _longDate(DateTime d) =>
      '${d.day} ${_monthAbbr[d.month - 1]} ${d.year}';

  String _fmtDelta(double d) {
    final s = d.abs().toStringAsFixed(1).replaceAll('.', ',');
    final sign = d > 0 ? '+' : (d < 0 ? '-' : '');
    return '$sign$s kg';
  }

  Widget _buildChart(List<Map<String, dynamic>> data) {
    final spots = <FlSpot>[];
    final dates = <DateTime?>[];
    for (var i = 0; i < data.length; i++) {
      final w = _weight(data[i]);
      if (w != null) {
        spots.add(FlSpot(i.toDouble(), w));
        dates.add(_entryDate(data[i]));
      }
    }
    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos de peso',
          style: TextStyle(
            color: RedesignColors.primario400,
            fontFamily: 'Metropolis',
          ),
        ),
      );
    }

    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b) - 1.5;
    final maxY = ys.reduce((a, b) => a > b ? a : b) + 1.5;

    // Label the first, middle and last points on the x-axis.
    final lastIdx = spots.length - 1;
    final labelIdx = <int>{0, lastIdx, lastIdx ~/ 2};

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.06),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: ((maxY - minY) / 2).clamp(1, double.infinity),
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 11,
                  color: RedesignColors.primario400,
                  fontFamily: 'Metropolis',
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (!labelIdx.contains(i) || i < 0 || i >= dates.length) {
                  return const SizedBox.shrink();
                }
                final d = dates[i];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    d != null ? _shortDate(d) : '',
                    style: const TextStyle(
                      fontSize: 11,
                      color: RedesignColors.primario400,
                      fontFamily: 'Metropolis',
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
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: RedesignColors.actionPrimary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 4,
                color: RedesignColors.background,
                strokeWidth: 2.5,
                strokeColor: RedesignColors.actionPrimary,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  RedesignColors.actionPrimary.withValues(alpha: 0.22),
                  RedesignColors.actionPrimary.withValues(alpha: 0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range toggle (1M / 3M / Todo)
// ---------------------------------------------------------------------------

class _RangeToggle extends StatelessWidget {
  final _Range value;
  final ValueChanged<_Range> onChanged;

  const _RangeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('1M', _Range.oneMonth),
          _segment('3M', _Range.threeMonths),
          _segment('Todo', _Range.all),
        ],
      ),
    );
  }

  Widget _segment(String label, _Range range) {
    final isActive = value == range;
    return GestureDetector(
      onTap: () => onChanged(range),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? RedesignColors.primario600 : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive
                ? RedesignColors.primario50
                : RedesignColors.primario400,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontFamily: 'Metropolis',
          ),
        ),
      ),
    );
  }
}
