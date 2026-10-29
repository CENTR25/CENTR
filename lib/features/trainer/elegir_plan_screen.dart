import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

// ---------------------------------------------------------------------------
// ElegirPlanScreen
//
// Full-screen plan picker. Lets the trainer toggle Mensual / Anual, browse
// tiers, and tap to select. The "Pasar a <plan>" action is a payment stub
// (Mercado Pago integration pending) that shows a "Próximamente" toast.
// ---------------------------------------------------------------------------

class ElegirPlanScreen extends ConsumerStatefulWidget {
  const ElegirPlanScreen({super.key});

  @override
  ConsumerState<ElegirPlanScreen> createState() => _ElegirPlanScreenState();
}

class _ElegirPlanScreenState extends ConsumerState<ElegirPlanScreen> {
  bool _isAnual = false;
  String? _selectedPlanName; // stripped plan name of the currently selected card

  /// Strip leading "Plan " for display ("Plan Profesional" → "Profesional").
  static String _strip(String name) {
    if (name.startsWith('Plan ')) return name.substring(5);
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final subAsync = ref.watch(myTrainerSubscriptionProvider);

    final currentPlanName = subAsync.maybeWhen(
      data: (sub) {
        final raw = sub?['subscription_plans']?['name'] as String?;
        return raw != null ? _strip(raw) : null;
      },
      orElse: () => null,
    );

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded,
                color: RedesignColors.primario50, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Elegí tu plan',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: plansAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: RedesignColors.actionPrimary),
          ),
          error: (_, __) => const Center(
            child: Text(
              'No se pudieron cargar los planes',
              style: TextStyle(color: RedesignColors.primario300),
            ),
          ),
          data: (plans) {
            // Default-select Profesional, or trainer's current plan on first load.
            if (_selectedPlanName == null && plans.isNotEmpty) {
              final profIndex = plans.indexWhere(
                (p) => _strip(p['name'] as String? ?? '').toLowerCase() == 'profesional',
              );
              final defaultName = profIndex >= 0
                  ? _strip(plans[profIndex]['name'] as String? ?? '')
                  : _strip(plans.first['name'] as String? ?? '');
              // Set without triggering another build cycle — safe in the
              // data callback since we're inside `when()`.
              _selectedPlanName ??= defaultName;
            }

            return Column(
              children: [
                // ── Mensual / Anual toggle ────────────────────────────────
                const SizedBox(height: 8),
                _BillingToggle(
                  isAnual: _isAnual,
                  onChanged: (v) => setState(() => _isAnual = v),
                ),
                const SizedBox(height: 20),

                // ── Plan cards ────────────────────────────────────────────
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      final name = _strip(plan['name'] as String? ?? '');
                      final price = (plan['price'] as num?) ?? 0;
                      final maxStudents = plan['max_students'] as int?;
                      final features =
                          (plan['features'] as Map<String, dynamic>?) ?? {};
                      final durationDays = (plan['duration_days'] as num?) ?? 30;

                      final displayPrice = _isAnual
                          ? price * 12 * 0.8 // 20 % discount
                          : price.toDouble();

                      final isProfesional =
                          name.toLowerCase() == 'profesional';
                      final isSelected = _selectedPlanName == name;
                      final isCurrent = currentPlanName == name;

                      return _PlanCard(
                        name: name,
                        price: displayPrice,
                        isAnual: _isAnual,
                        maxStudents: maxStudents,
                        features: features,
                        durationDays: durationDays.toInt(),
                        isRecommended: isProfesional,
                        isSelected: isSelected,
                        isCurrent: isCurrent,
                        onTap: () => setState(() => _selectedPlanName = name),
                      );
                    },
                  ),
                ),

                // ── Bottom CTA ────────────────────────────────────────────
                _BottomCta(
                  planName: _selectedPlanName ?? '',
                  onTap: () => _handleUpgrade(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _handleUpgrade(BuildContext context) {
    showRedesignToast(
      context,
      title: 'Próximamente',
      subtitle: 'Los pagos estarán disponibles pronto.',
      icon: Icons.access_time_rounded,
    );
  }
}

// ---------------------------------------------------------------------------
// _BillingToggle — Mensual / Anual segmented toggle
// ---------------------------------------------------------------------------

class _BillingToggle extends StatelessWidget {
  final bool isAnual;
  final ValueChanged<bool> onChanged;

  const _BillingToggle({required this.isAnual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 44,
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _ToggleHalf(
            label: 'Mensual',
            selected: !isAnual,
            onTap: () => onChanged(false),
            isLeft: true,
          ),
          _ToggleHalf(
            label: 'Anual',
            badge: 'ahorrás 20%',
            selected: isAnual,
            onTap: () => onChanged(true),
            isLeft: false,
          ),
        ],
      ),
    );
  }
}

class _ToggleHalf extends StatelessWidget {
  final String label;
  final String? badge;
  final bool selected;
  final VoidCallback onTap;
  final bool isLeft;

  const _ToggleHalf({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isLeft,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.horizontal(
      left: Radius.circular(isLeft ? RedesignRadius.buttonSm : 0),
      right: Radius.circular(isLeft ? 0 : RedesignRadius.buttonSm),
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? RedesignColors.actionPrimary
                : Colors.transparent,
            borderRadius: radius,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: RedesignType.buttonSm.copyWith(
                  color: selected
                      ? RedesignColors.onActionPrimary
                      : RedesignColors.primario300,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: selected
                        ? RedesignColors.onActionPrimary.withValues(alpha: 0.15)
                        : RedesignColors.secundario300.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? RedesignColors.onActionPrimary
                          : RedesignColors.actionPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PlanCard
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final String name;
  final double price;
  final bool isAnual;
  final int? maxStudents;
  final Map<String, dynamic> features;
  final int durationDays;
  final bool isRecommended;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.name,
    required this.price,
    required this.isAnual,
    required this.maxStudents,
    required this.features,
    required this.durationDays,
    required this.isRecommended,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  List<_FeatureItem> _buildFeatures() {
    final items = <_FeatureItem>[];

    // Students capacity
    if (maxStudents == null) {
      items.add(const _FeatureItem('Alumnos ilimitados'));
    } else {
      items.add(_FeatureItem('Hasta $maxStudents alumnos'));
    }

    // Support tier
    final support = features['support'] as String?;
    if (support != null) {
      items.add(_FeatureItem('Soporte $support'));
    }

    // Analytics
    if (features['analytics'] == true) {
      items.add(const _FeatureItem('Analytics'));
    }

    // Custom branding
    if (features['custom_branding'] == true) {
      items.add(const _FeatureItem('Marca personalizada'));
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? RedesignColors.actionPrimary
        : isRecommended
            ? RedesignColors.secundario300.withValues(alpha: 0.5)
            : RedesignColors.secundario300.withValues(alpha: 0.18);

    final priceStr =
        '\$${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
    final perLabel = isAnual ? '/año' : '/mes';
    final featureItems = _buildFeatures();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: RedesignType.bodySm.copyWith(
                              color: RedesignColors.primario50,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isRecommended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: RedesignColors.actionPrimary
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    RedesignRadius.buttonSm),
                              ),
                              child: Text(
                                'Recomendado',
                                style: RedesignType.label.copyWith(
                                  color: RedesignColors.actionPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: RedesignColors.success
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    RedesignRadius.buttonSm),
                              ),
                              child: Text(
                                'Tu plan',
                                style: RedesignType.label.copyWith(
                                  color: RedesignColors.success,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                RichText(
                  textAlign: TextAlign.right,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: priceStr,
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.actionPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                      TextSpan(
                        text: perLabel,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.primario300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (featureItems.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...featureItems.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: isRecommended || isSelected
                            ? RedesignColors.actionPrimary
                            : RedesignColors.primario400,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        f.text,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.primario200,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Selected indicator ────────────────────────────────────────
            if (isSelected) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.radio_button_checked_rounded,
                      size: 16, color: RedesignColors.actionPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Seleccionado',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.actionPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeatureItem {
  final String text;

  const _FeatureItem(this.text);
}

// ---------------------------------------------------------------------------
// _BottomCta
// ---------------------------------------------------------------------------

class _BottomCta extends StatelessWidget {
  final String planName;
  final VoidCallback onTap;

  const _BottomCta({required this.planName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: RedesignColors.background,
        border: Border(
          top: BorderSide(color: RedesignColors.primario600, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: planName.isNotEmpty ? onTap : null,
          child: Text(
            planName.isNotEmpty ? 'Pasar a $planName' : 'Seleccioná un plan',
            style: RedesignType.buttonLg.copyWith(
              color: RedesignColors.onActionPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
