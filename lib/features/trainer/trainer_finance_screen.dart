import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

/// Finances / cuotas organizer for the trainer: every student's renewal
/// (cuota) status at a glance, with the ability to set/update the next renewal
/// date. Tracker only — no payment processing (Mercado Pago lands later).
class TrainerFinanceScreen extends ConsumerWidget {
  const TrainerFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeAsync = ref.watch(studentsFinanceProvider);

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
            'Finanzas',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: financeAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: RedesignColors.actionPrimary),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300)),
          ),
          data: (students) {
            if (students.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Todavía no tenés alumnos.',
                    textAlign: TextAlign.center,
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ),
              );
            }

            final rows = students.map(_FinanceRow.fromJson).toList()
              ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

            final overdue = rows.where((r) => r.status == _PayStatus.overdue).length;
            final dueSoon = rows.where((r) => r.status == _PayStatus.dueSoon).length;
            final upToDate = rows.where((r) => r.status == _PayStatus.upToDate).length;
            final noDate = rows.where((r) => r.status == _PayStatus.noDate).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Row(
                  children: [
                    _SummaryCard(
                      count: overdue,
                      label: 'Vencidas',
                      color: RedesignColors.danger,
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      count: dueSoon,
                      label: 'Por vencer',
                      color: RedesignColors.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _SummaryCard(
                      count: upToDate,
                      label: 'Al día',
                      color: RedesignColors.secundario300,
                    ),
                    const SizedBox(width: 10),
                    _SummaryCard(
                      count: noDate,
                      label: 'Sin fecha',
                      color: RedesignColors.primario400,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Alumnos',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _StudentFinanceTile(
                      row: r,
                      onEdit: () => _editDate(context, ref, r),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editDate(
    BuildContext context,
    WidgetRef ref,
    _FinanceRow row,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: row.renewalDate ?? now.add(const Duration(days: 30)),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Próxima cuota de ${row.name}',
      builder: (ctx, child) => Theme(
        data: RedesignTheme.theme.copyWith(
          colorScheme: RedesignTheme.theme.colorScheme.copyWith(
            primary: RedesignColors.actionPrimary,
            onPrimary: RedesignColors.onActionPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    try {
      await ref
          .read(trainerServiceProvider)
          .updateStudentRenewalDate(row.id, picked);
      ref.invalidate(studentsFinanceProvider);
      ref.invalidate(upcomingRenewalsProvider);
      ref.invalidate(expandedRenewalsProvider);
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'Fecha actualizada',
        subtitle: 'Se guardó la próxima cuota de ${row.name}.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'No se pudo guardar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }
}

enum _PayStatus { overdue, dueSoon, upToDate, noDate }

class _FinanceRow {
  final String id;
  final String name;
  final DateTime? renewalDate;
  final _PayStatus status;
  final int? daysLeft;

  _FinanceRow({
    required this.id,
    required this.name,
    required this.renewalDate,
    required this.status,
    required this.daysLeft,
  });

  /// Sort: overdue first (most overdue first), then due soon, up to date, then
  /// students without a date.
  int get sortKey {
    switch (status) {
      case _PayStatus.overdue:
        return -10000 + (daysLeft ?? 0); // more negative daysLeft = sooner
      case _PayStatus.dueSoon:
        return daysLeft ?? 0;
      case _PayStatus.upToDate:
        return 10000 + (daysLeft ?? 0);
      case _PayStatus.noDate:
        return 1000000;
    }
  }

  static _FinanceRow fromJson(Map<String, dynamic> j) {
    final name = j['name'] as String? ?? 'Alumno';
    final dateStr = j['next_renewal_date'] as String?;
    final date = dateStr != null ? DateTime.tryParse(dateStr) : null;

    _PayStatus status;
    int? daysLeft;
    if (date == null) {
      status = _PayStatus.noDate;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(date.year, date.month, date.day);
      daysLeft = day.difference(today).inDays;
      if (daysLeft < 0) {
        status = _PayStatus.overdue;
      } else if (daysLeft <= 7) {
        status = _PayStatus.dueSoon;
      } else {
        status = _PayStatus.upToDate;
      }
    }

    return _FinanceRow(
      id: j['id'] as String,
      name: name,
      renewalDate: date,
      status: status,
      daysLeft: daysLeft,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _SummaryCard({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: RedesignType.bodySm.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentFinanceTile extends StatelessWidget {
  final _FinanceRow row;
  final VoidCallback onEdit;

  const _StudentFinanceTile({required this.row, required this.onEdit});

  (Color, String) get _statusLabel {
    switch (row.status) {
      case _PayStatus.overdue:
        final d = (row.daysLeft ?? 0).abs();
        return (RedesignColors.danger, 'Vencida hace $d día${d == 1 ? '' : 's'}');
      case _PayStatus.dueSoon:
        final d = row.daysLeft ?? 0;
        return (
          RedesignColors.warning,
          d == 0 ? 'Vence hoy' : 'Vence en $d día${d == 1 ? '' : 's'}'
        );
      case _PayStatus.upToDate:
        return (RedesignColors.secundario300, 'Al día');
      case _PayStatus.noDate:
        return (RedesignColors.primario400, 'Sin fecha');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = _statusLabel;
    final dateLabel = row.renewalDate != null
        ? '${row.renewalDate!.day.toString().padLeft(2, '0')}/${row.renewalDate!.month.toString().padLeft(2, '0')}/${row.renewalDate!.year}'
        : '—';

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(RedesignRadius.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          label,
                          style: RedesignType.label.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateLabel,
                        style: RedesignType.label
                            .copyWith(color: RedesignColors.primario400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_calendar_outlined,
                color: RedesignColors.primario400, size: 20),
          ],
        ),
      ),
    );
  }
}
