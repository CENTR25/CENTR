import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

// ---------------------------------------------------------------------------
// MiSuscripcionScreen
//
// Shows the trainer's current plan, student usage, and payment stubs.
// All payment actions (Cambiar, Historial, Cancelar) are stubs that show a
// "Próximamente" toast — Mercado Pago integration is pending.
// ---------------------------------------------------------------------------

class MiSuscripcionScreen extends ConsumerWidget {
  const MiSuscripcionScreen({super.key});

  /// Strip leading "Plan " prefix for display ("Plan Básico" → "Básico").
  static String _stripPlanPrefix(String name) {
    if (name.startsWith('Plan ')) return name.substring(5);
    return name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(myTrainerSubscriptionProvider);
    final studentsAsync = ref.watch(myStudentsProvider);

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
            final plan = sub?['subscription_plans'] as Map<String, dynamic>?;
            final planName = _stripPlanPrefix(
              (plan?['name'] as String?) ?? 'Básico',
            );
            final price = (plan?['price'] as num?) ?? 0;
            final maxStudents = plan?['max_students'] as int?;
            final isActive = (sub?['is_active'] as bool?) ?? false;
            final endsAt = sub?['ends_at'] as String?;

            final studentCount = studentsAsync.maybeWhen(
              data: (s) => s.length,
              orElse: () => 0,
            );

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                // ── Plan card ───────────────────────────────────────────────
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tu plan',
                                  style: RedesignType.label.copyWith(
                                    color: RedesignColors.primario300,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  planName,
                                  style: RedesignType.headingMd.copyWith(
                                    color: RedesignColors.primario50,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            _StatusPill(
                              label: 'Activo',
                              color: RedesignColors.success,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} / mes',
                        style: RedesignType.bodyMd.copyWith(
                          color: RedesignColors.actionPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (endsAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Próximo cobro: ${_formatDate(endsAt)}',
                          style: RedesignType.label.copyWith(
                            color: RedesignColors.primario300,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Usage ────────────────────────────────────────────────────
                Text(
                  'Uso del plan',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  child: _UsageRow(
                    label: 'Alumnos',
                    count: studentCount,
                    max: maxStudents,
                  ),
                ),

                const SizedBox(height: 16),

                // ── Payment section ──────────────────────────────────────────
                Text(
                  'Pago',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _SectionCard(
                  child: Column(
                    children: [
                      // Payment method row
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: RedesignColors.secundario300
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.credit_card_rounded,
                              color: RedesignColors.actionPrimary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Método de pago no configurado',
                              style: RedesignType.label.copyWith(
                                color: RedesignColors.primario300,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _stubSnackBar(context),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: RedesignColors.actionPrimaryDark,
                            ),
                            child: Text(
                              'Cambiar',
                              style: RedesignType.label.copyWith(
                                color: RedesignColors.actionPrimaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: RedesignColors.primario600),
                      // Payment history row
                      InkWell(
                        onTap: () => _stubSnackBar(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: RedesignColors.secundario300
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  color: RedesignColors.actionPrimary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Historial de pagos',
                                  style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.primario50,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: RedesignColors.primario400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Cancel ───────────────────────────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: () => _confirmCancel(context),
                    style: TextButton.styleFrom(
                      foregroundColor: RedesignColors.danger,
                    ),
                    child: Text(
                      'Cancelar suscripción',
                      style: RedesignType.buttonSm.copyWith(
                        color: RedesignColors.danger,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return isoDate;
    }
  }

  void _stubSnackBar(BuildContext context) {
    showRedesignToast(
      context,
      title: 'Próximamente',
      subtitle: 'Esta función estará disponible pronto.',
      icon: Icons.access_time_rounded,
    );
  }

  void _confirmCancel(BuildContext context) {
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
          'Tu plan seguirá activo hasta el final del período actual.',
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
              _stubSnackBar(context);
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
