import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../core/utils/billing_format.dart';
import '../../models/billing_subscription.dart';
import '../../models/mp_payment.dart';
import '../../services/billing_service.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';
import 'billing_return_screen.dart';
import 'elegir_plan_screen.dart';

// ---------------------------------------------------------------------------
// MiSuscripcionScreen
//
// The trainer's real subscription: status chip, plan, next charge, student
// usage, Mercado Pago payment history and cancellation (mp-manage). Plans
// assigned by PRGS (source = 'manual') are shown read-only.
// ---------------------------------------------------------------------------

class MiSuscripcionScreen extends ConsumerStatefulWidget {
  const MiSuscripcionScreen({super.key});

  @override
  ConsumerState<MiSuscripcionScreen> createState() =>
      _MiSuscripcionScreenState();
}

class _MiSuscripcionScreenState extends ConsumerState<MiSuscripcionScreen> {
  bool _cancelling = false;

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(billingSubscriptionProvider);
    final studentsAsync = ref.watch(myStudentsProvider);
    final paymentsAsync = ref.watch(billingPaymentsProvider);

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
            'Mi suscripción',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: subAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: RedesignColors.actionPrimary),
          ),
          error: (_, __) => const Center(
            child: Text(
              'No se pudo cargar la suscripción',
              style: TextStyle(color: RedesignColors.primario300),
            ),
          ),
          data: (sub) {
            final now = DateTime.now();
            final status = sub?.statusAt(now);
            final studentCount = studentsAsync.maybeWhen(
              data: (s) => s.length,
              orElse: () => 0,
            );
            final hasAccess = sub != null && sub.hasAccess(now);
            final maxStudents = studentCapFor(sub, now);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _SectionCard(child: _planCardBody(context, sub, status, now)),
                const SizedBox(height: 16),

                // ── Usage ────────────────────────────────────────────────
                _sectionTitle('Uso del plan'),
                const SizedBox(height: 10),
                _SectionCard(
                  child: _UsageRow(
                    label: 'Alumnos',
                    count: studentCount,
                    max: maxStudents,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Payment history ──────────────────────────────────────
                _sectionTitle('Historial de pagos'),
                const SizedBox(height: 10),
                _SectionCard(
                  child: paymentsAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: RedesignColors.actionPrimary,
                        ),
                      ),
                    ),
                    error: (_, __) => _mutedText('No se pudo cargar el historial'),
                    data: (payments) => payments.isEmpty
                        ? _mutedText('Todavía no hay pagos registrados')
                        : Column(
                            children: [
                              for (var i = 0; i < payments.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                      height: 20,
                                      color: RedesignColors.primario600),
                                _PaymentRow(payment: payments[i]),
                              ],
                            ],
                          ),
                  ),
                ),

                // ── Actions ──────────────────────────────────────────────
                const SizedBox(height: 24),
                if (sub != null && sub.canCancel(now)) ...[
                  _outlinedAction(
                    'Cambiar de plan',
                    () => _openPlans(context),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _cancelling ? null : () => _confirmCancel(sub),
                      style: TextButton.styleFrom(
                        foregroundColor: RedesignColors.danger,
                      ),
                      child: _cancelling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: RedesignColors.danger,
                              ),
                            )
                          : Text(
                              'Cancelar suscripción',
                              style: RedesignType.buttonSm
                                  .copyWith(color: RedesignColors.danger),
                            ),
                    ),
                  ),
                ] else if (status == BillingStatus.pending) ...[
                  _outlinedAction(
                    'Verificar pago',
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BillingReturnScreen(
                          subscriptionId: sub!.id,
                        ),
                      ),
                    ).then((_) => _refresh()),
                  ),
                ] else if (!hasAccess && !(sub?.isManual ?? false)) ...[
                  _outlinedAction('Elegir plan', () => _openPlans(context)),
                ],
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Plan card content per status ──────────────────────────────────────────

  Widget _planCardBody(BuildContext context, BillingSubscription? sub,
      BillingStatus? status, DateTime now) {
    if (sub == null || status == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu plan',
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300)),
          const SizedBox(height: 4),
          Text('Sin plan activo',
              style: RedesignType.headingMd
                  .copyWith(color: RedesignColors.primario50)),
          const SizedBox(height: 8),
          _mutedText(
              'Podés tener hasta $kFreeStudentCap alumnos. Elegí un plan para sumar más.'),
        ],
      );
    }

    final plan = sub.plan;
    final (chipLabel, chipColor) = _chip(sub, status, now);
    final lines = <String>[];
    final until = formatBillingDate(sub.accessUntil);
    switch (status) {
      case BillingStatus.active:
        lines.add(
            'Próximo cobro: ${formatBillingDate(sub.nextPaymentDate ?? sub.endsAt)}');
      case BillingStatus.pastDue:
        lines.add(
            'No pudimos cobrar tu último pago. Actualizá tu medio de pago en Mercado Pago para no perder el acceso.');
        lines.add('Acceso hasta: $until');
      case BillingStatus.paused:
        lines.add('Cobros pausados. Acceso hasta: $until');
      case BillingStatus.cancelled:
        final stillActive = sub.accessUntil != null && now.isBefore(sub.accessUntil!);
        lines.add(stillActive
            ? 'Tu acceso continúa hasta: $until'
            : 'Cancelada. Tu acceso terminó el $until');
      case BillingStatus.expired:
        lines.add('Venció el $until');
      case BillingStatus.pending:
        lines.add(
            'Esperando confirmación del pago. Si ya pagaste, puede tardar unos minutos.');
      case BillingStatus.manual:
        lines.add('Vigente hasta: ${formatBillingDate(sub.endsAt)}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tu plan',
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300)),
                  const SizedBox(height: 4),
                  Text(
                    plan?.displayName ?? 'Plan',
                    style: RedesignType.headingMd
                        .copyWith(color: RedesignColors.primario50),
                  ),
                ],
              ),
            ),
            _StatusPill(label: chipLabel, color: chipColor),
          ],
        ),
        if (plan != null && !sub.isManual) ...[
          const SizedBox(height: 12),
          Text(
            formatArsPerMonth(plan.price),
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.actionPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        for (final l in lines) ...[
          const SizedBox(height: 6),
          Text(l,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300)),
        ],
      ],
    );
  }

  (String, Color) _chip(
      BillingSubscription sub, BillingStatus status, DateTime now) {
    final label =
        billingStatusLabel(status, graceDays: sub.graceDaysLeft(now));
    switch (status) {
      case BillingStatus.active:
        return (label, RedesignColors.success);
      case BillingStatus.pending:
      case BillingStatus.pastDue:
        return (label, RedesignColors.advertencia400);
      case BillingStatus.manual:
        return (label, RedesignColors.actionPrimary);
      case BillingStatus.expired:
        return (label, RedesignColors.danger);
      case BillingStatus.paused:
      case BillingStatus.cancelled:
        return (label, RedesignColors.primario400);
    }
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  void _refresh() {
    ref.invalidate(billingSubscriptionProvider);
    ref.invalidate(billingPaymentsProvider);
    ref.invalidate(myTrainerSubscriptionProvider);
  }

  void _openPlans(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ElegirPlanScreen()),
    ).then((_) => _refresh());
  }

  void _confirmCancel(BillingSubscription sub) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.card),
        ),
        title: Text(
          '¿Cancelar suscripción?',
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'No se te volverá a cobrar. Tu plan seguirá activo hasta el final del período ya pagado (${formatBillingDate(sub.accessUntil)}).',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Volver',
              style: RedesignType.buttonSm.copyWith(
                color: RedesignColors.primario300,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cancel(sub);
            },
            child: Text(
              'Cancelar plan',
              style: RedesignType.buttonSm.copyWith(
                color: RedesignColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(BillingSubscription sub) async {
    setState(() => _cancelling = true);
    try {
      await ref.read(billingServiceProvider).cancel(sub.id);
      ref.invalidate(myTrainerSubscriptionProvider);
      ref.invalidate(billingPaymentsProvider);
      final fresh = await ref.refresh(billingSubscriptionProvider.future);
      if (!mounted) return;
      showRedesignToast(
        context,
        title: 'Suscripción cancelada',
        subtitle:
            'Seguís con acceso hasta el ${formatBillingDate(fresh?.accessUntil ?? sub.accessUntil)}.',
        duration: const Duration(milliseconds: 3200),
      );
    } on BillingException catch (e) {
      if (!mounted) return;
      showRedesignToast(
        context,
        title: 'No se pudo cancelar',
        subtitle: e.message,
        icon: Icons.error_outline_rounded,
        duration: const Duration(milliseconds: 3200),
      );
    } catch (_) {
      if (!mounted) return;
      showRedesignToast(
        context,
        title: 'No se pudo cancelar',
        subtitle: 'Probá de nuevo en unos minutos.',
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ── Small builders ────────────────────────────────────────────────────────

  Widget _sectionTitle(String t) => Text(
        t,
        style: RedesignType.bodySm.copyWith(
          color: RedesignColors.primario50,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _mutedText(String t) => Text(
        t,
        style: RedesignType.label.copyWith(color: RedesignColors.primario300),
      );

  Widget _outlinedAction(String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onTap,
            child: Text(
              label,
              style: RedesignType.buttonLg
                  .copyWith(color: RedesignColors.onActionPrimary),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// _PaymentRow
// ---------------------------------------------------------------------------

class _PaymentRow extends StatelessWidget {
  final MpPayment payment;

  const _PaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final color = payment.isApproved
        ? RedesignColors.success
        : (payment.status == 'rejected' || payment.status == 'cancelled')
            ? RedesignColors.danger
            : RedesignColors.advertencia400;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '\$ ${formatArs(payment.amount)}',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                formatBillingDate(payment.date),
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300),
              ),
            ],
          ),
        ),
        _StatusPill(label: payment.statusLabel, color: color),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _SectionCard
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusPill
// ---------------------------------------------------------------------------

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        label,
        style: RedesignType.label.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _UsageRow — alumnos count + teal progress bar
// ---------------------------------------------------------------------------

class _UsageRow extends StatelessWidget {
  final String label;
  final int count;
  final int? max; // null = unlimited

  const _UsageRow({
    required this.label,
    required this.count,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final isUnlimited = max == null;
    final ratio = isUnlimited ? 0.6 : (max! > 0 ? (count / max!).clamp(0.0, 1.0) : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: RedesignType.label.copyWith(color: RedesignColors.primario300),
            ),
            const Spacer(),
            Text(
              isUnlimited
                  ? '$count  ·  ilimitado'
                  : '$count de $max',
              style: RedesignType.label.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: RedesignColors.primario600,
            valueColor: const AlwaysStoppedAnimation<Color>(
              RedesignColors.actionPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
