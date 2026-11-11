import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

/// Finances / cuotas organizer for the trainer: every student's renewal
/// (cuota) status at a glance, monthly earnings summary, and the ability to
/// record payments and set/update the next renewal date.
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

            final overdue =
                rows.where((r) => r.status == _PayStatus.overdue).length;
            final dueSoon =
                rows.where((r) => r.status == _PayStatus.dueSoon).length;
            final upToDate =
                rows.where((r) => r.status == _PayStatus.upToDate).length;
            final noDate =
                rows.where((r) => r.status == _PayStatus.noDate).length;

            // Current-month earnings — summed directly in the UI from the
            // merged paid_amount_this_month values returned by the service.
            final monthEarnings = rows.fold<double>(
              0.0,
              (acc, r) => acc + r.paidAmountThisMonth,
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                // ── Monthly earnings card ───────────────────────────────────
                _EarningsCard(monthEarnings: monthEarnings),
                const SizedBox(height: 14),
                // ── Status summary cards ────────────────────────────────────
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
                      onEditDate: () => _editDate(context, ref, r),
                      onEditFee: () => _editFee(context, ref, r),
                      onRecordPayment: () =>
                          _recordPayment(context, ref, r),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Edit renewal date (existing behaviour, unchanged) ───────────────────

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

  // ── Edit monthly fee ────────────────────────────────────────────────────

  Future<void> _editFee(
    BuildContext context,
    WidgetRef ref,
    _FinanceRow row,
  ) async {
    final ctrl = TextEditingController(
      text: row.monthlyFee != null
          ? row.monthlyFee!
              .toStringAsFixed(row.monthlyFee! % 1 == 0 ? 0 : 2)
          : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario700,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RedesignRadius.card)),
          title: Text(
            'Cuota de ${row.name}',
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            style:
                RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
            decoration: InputDecoration(
              prefixText: '\$ ',
              prefixStyle: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario300),
              hintText: '0',
              hintStyle: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario400),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                    color: RedesignColors.secundario300.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: RedesignColors.actionPrimary, width: 1.5),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario300)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Guardar',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.actionPrimary)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final raw = ctrl.text.trim();
    final fee = raw.isEmpty ? null : double.tryParse(raw);
    try {
      await ref.read(trainerServiceProvider).setMonthlyFee(row.id, fee);
      ref.invalidate(studentsFinanceProvider);
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'Cuota actualizada',
        subtitle: fee == null
            ? 'Se eliminó la cuota de ${row.name}.'
            : 'Cuota de ${row.name}: ${_formatCurrency(fee)}',
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

  // ── Record payment ──────────────────────────────────────────────────────

  Future<void> _recordPayment(
    BuildContext context,
    WidgetRef ref,
    _FinanceRow row,
  ) async {
    // If no fee is set, nudge first with an inline fee dialog.
    if (row.monthlyFee == null) {
      if (!context.mounted) return;
      await _editFee(context, ref, row);
      // After setting the fee, the provider is refreshed. We don't
      // auto-continue to record payment — the trainer can tap "Registrar
      // pago" again once the fee is set.
      return;
    }

    final ctrl = TextEditingController(
      text: row.monthlyFee!
          .toStringAsFixed(row.monthlyFee! % 1 == 0 ? 0 : 2),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario700,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RedesignRadius.card)),
          title: Text(
            'Registrar pago — ${row.name}',
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monto',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}')),
                ],
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: InputDecoration(
                  prefixText: '\$ ',
                  prefixStyle: RedesignType.bodySm
                      .copyWith(color: RedesignColors.primario300),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: RedesignColors.secundario300
                            .withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                        color: RedesignColors.actionPrimary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'La renovación se avanzará +1 mes automáticamente.',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario400, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario300)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Confirmar',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.actionPrimary)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(ctrl.text.trim());
    if (amount == null || amount <= 0) {
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'Monto inválido',
        subtitle: 'Ingresá un monto mayor a cero.',
        icon: Icons.error_outline_rounded,
      );
      return;
    }

    try {
      await ref.read(trainerServiceProvider).recordPayment(
            athleteId: row.id,
            amount: amount,
          );
      ref.invalidate(studentsFinanceProvider);
      ref.invalidate(upcomingRenewalsProvider);
      ref.invalidate(expandedRenewalsProvider);
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'Pago registrado',
        subtitle: '${row.name} · ${_formatCurrency(amount)}',
      );
    } catch (e) {
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'No se pudo registrar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }
}

// ── Currency formatter (es-AR style: $12.345, no decimals) ─────────────────

String _formatCurrency(num value) {
  final intPart = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '\$$buf';
}

// ── Spanish month names ─────────────────────────────────────────────────────

const _kMonthNames = [
  '',
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

// ── Data model ──────────────────────────────────────────────────────────────

enum _PayStatus { overdue, dueSoon, upToDate, noDate }

class _FinanceRow {
  final String id;
  final String name;
  final DateTime? renewalDate;
  final _PayStatus status;
  final int? daysLeft;
  final double? monthlyFee;
  final bool paidThisMonth;
  final double paidAmountThisMonth;

  _FinanceRow({
    required this.id,
    required this.name,
    required this.renewalDate,
    required this.status,
    required this.daysLeft,
    required this.monthlyFee,
    required this.paidThisMonth,
    required this.paidAmountThisMonth,
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

    final rawFee = j['monthly_fee'];
    final monthlyFee =
        rawFee != null ? (rawFee as num).toDouble() : null;

    return _FinanceRow(
      id: j['id'] as String,
      name: name,
      renewalDate: date,
      status: status,
      daysLeft: daysLeft,
      monthlyFee: monthlyFee,
      paidThisMonth: (j['paid_this_month'] as bool?) ?? false,
      paidAmountThisMonth:
          ((j['paid_amount_this_month'] as num?) ?? 0).toDouble(),
    );
  }
}

// ── Widgets ─────────────────────────────────────────────────────────────────

class _EarningsCard extends StatelessWidget {
  final double monthEarnings;
  const _EarningsCard({required this.monthEarnings});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthLabel = _kMonthNames[now.month];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.actionPrimary.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ganancias de $monthLabel',
            style: RedesignType.label
                .copyWith(color: RedesignColors.primario300, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _formatCurrency(monthEarnings),
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.secundario300,
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
        ],
      ),
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
  final VoidCallback onEditDate;
  final VoidCallback onEditFee;
  final VoidCallback onRecordPayment;

  const _StudentFinanceTile({
    required this.row,
    required this.onEditDate,
    required this.onEditFee,
    required this.onRecordPayment,
  });

  (Color, String) get _statusLabel {
    switch (row.status) {
      case _PayStatus.overdue:
        final d = (row.daysLeft ?? 0).abs();
        return (
          RedesignColors.danger,
          'Vencida hace $d día${d == 1 ? '' : 's'}'
        );
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

    final feeLabel =
        row.monthlyFee != null ? _formatCurrency(row.monthlyFee!) : 'Sin cuota';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: name + paid pill + actions menu ──────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              // Paid-this-month pill
              _PaidPill(paid: row.paidThisMonth),
              const SizedBox(width: 6),
              // Actions popup menu
              _ActionsMenu(
                onEditDate: onEditDate,
                onEditFee: onEditFee,
                onRecordPayment: onRecordPayment,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── Bottom row: renewal status + fee ─────────────────────────
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const Spacer(),
              Text(
                feeLabel,
                style: RedesignType.label.copyWith(
                  color: row.monthlyFee != null
                      ? RedesignColors.primario200
                      : RedesignColors.primario500,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaidPill extends StatelessWidget {
  final bool paid;
  const _PaidPill({required this.paid});

  @override
  Widget build(BuildContext context) {
    final color =
        paid ? RedesignColors.secundario300 : RedesignColors.primario400;
    final text = paid ? 'Pagó este mes' : 'Sin pago';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: RedesignType.label.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final VoidCallback onEditDate;
  final VoidCallback onEditFee;
  final VoidCallback onRecordPayment;

  const _ActionsMenu({
    required this.onEditDate,
    required this.onEditFee,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TileAction>(
      icon: const Icon(Icons.more_vert_rounded,
          color: RedesignColors.primario400, size: 20),
      color: RedesignColors.primario700,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.card)),
      onSelected: (action) {
        switch (action) {
          case _TileAction.recordPayment:
            onRecordPayment();
          case _TileAction.editFee:
            onEditFee();
          case _TileAction.editDate:
            onEditDate();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _TileAction.recordPayment,
          child: _MenuRow(
            icon: Icons.payments_outlined,
            label: 'Registrar pago',
            color: RedesignColors.secundario300,
          ),
        ),
        PopupMenuItem(
          value: _TileAction.editFee,
          child: _MenuRow(
            icon: Icons.attach_money_rounded,
            label: 'Editar cuota',
            color: RedesignColors.primario200,
          ),
        ),
        PopupMenuItem(
          value: _TileAction.editDate,
          child: _MenuRow(
            icon: Icons.edit_calendar_outlined,
            label: 'Editar fecha',
            color: RedesignColors.primario400,
          ),
        ),
      ],
    );
  }
}

enum _TileAction { recordPayment, editFee, editDate }

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MenuRow(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(label,
            style: RedesignType.label.copyWith(color: RedesignColors.primario50)),
      ],
    );
  }
}
