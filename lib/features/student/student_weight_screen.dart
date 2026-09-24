import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';

class StudentWeightScreen extends ConsumerStatefulWidget {
  const StudentWeightScreen({super.key});

  @override
  ConsumerState<StudentWeightScreen> createState() => _StudentWeightScreenState();
}

class _StudentWeightScreenState extends ConsumerState<StudentWeightScreen> {
  final TextEditingController _weightController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _saveWeight() async {
    final weight = double.tryParse(_weightController.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un peso válido')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(studentServiceProvider).logMetrics(weight: weight);
      _weightController.clear();
      ref.invalidate(myWeightHistoryProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Peso registrado correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Peso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Input Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                   BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    'Nuevo Registro',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0.0',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      const Text('kg', style: TextStyle(fontSize: 24, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveWeight,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Guardar Registro'),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            
            // History chart
            const Text(
              'Historial Reciente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 220,
              padding: const EdgeInsets.fromLTRB(8, 24, 24, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Consumer(
                builder: (context, ref, _) {
                  final historyAsync = ref.watch(myWeightHistoryProvider);
                  return historyAsync.when(
                    data: (history) => _buildChart(history),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Center(
                      child: Text(
                        'No se pudo cargar el historial',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 32),

            // Detailed list
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Registro Detallado',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Consumer(
              builder: (context, ref, _) {
                final historyAsync = ref.watch(myWeightHistoryProvider);
                return historyAsync.when(
                  data: (history) => _buildHistoryList(history),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Sin registros',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Provider data is oldest-first (for the chart); show most-recent-first.
    final entries = history.reversed.toList();
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatEntryDate(entry, dateFormat),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                Text(
                  '${(entry['body_weight'] as num?)?.toStringAsFixed(1) ?? '-'} kg',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatEntryDate(Map<String, dynamic> entry, DateFormat dateFormat) {
    final raw = entry['date'] ?? entry['created_at'];
    final parsed = raw is String ? DateTime.tryParse(raw) : null;
    return parsed != null ? dateFormat.format(parsed) : '-';
  }

  Widget _buildChart(List<Map<String, dynamic>> history) {
    if (history.isEmpty) {
      return const Center(
        child: Text(
          'Registrá tu peso para ver tu progreso',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final recent = history.length > 15
        ? history.sublist(history.length - 15)
        : history;
    final spots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      final w = (recent[i]['body_weight'] as num?)?.toDouble();
      if (w != null) spots.add(FlSpot(i.toDouble(), w));
    }
    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'Sin datos de peso',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    final weights = spots.map((s) => s.y);
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 2);
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 2;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}kg',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.2),
                  AppColors.primary.withValues(alpha: 0),
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
