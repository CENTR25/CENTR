import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/theme_redesign.dart';
import '../../core/utils/billing_format.dart';
import '../../models/billing_plan.dart';
import '../../services/auth_service.dart';
import '../../services/billing_service.dart';
import 'billing_return_screen.dart';

// ---------------------------------------------------------------------------
// ElegirPlanScreen
//
// Full-screen plan picker (monthly ARS plans from subscription_plans). The
// "Suscribirme" action asks for the Mercado Pago account email, calls
// mp-subscribe and opens the returned checkout URL. The plan is NEVER
// activated here: BillingReturnScreen polls until the webhook confirms it.
// ---------------------------------------------------------------------------

class ElegirPlanScreen extends ConsumerStatefulWidget {
  const ElegirPlanScreen({super.key});

  @override
  ConsumerState<ElegirPlanScreen> createState() => _ElegirPlanScreenState();
}

class _ElegirPlanScreenState extends ConsumerState<ElegirPlanScreen> {
  String? _selectedPlanId;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(billingPlansProvider);
    final subAsync = ref.watch(billingSubscriptionProvider);

    final current = subAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final currentPlanId =
        current != null && current.hasAccess(DateTime.now()) && !current.isManual
            ? current.plan?.id
            : null;

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
            if (plans.isEmpty) {
              return const Center(
                child: Text(
                  'Todavía no hay planes disponibles',
                  style: TextStyle(color: RedesignColors.primario300),
                ),
              );
            }
            // Default selection: the recommended plan, else the first one.
            _selectedPlanId ??= (plans.firstWhere(
              (p) => p.displayName.toLowerCase() == 'profesional',
              orElse: () => plans.first,
            )).id;
            final selected = plans.firstWhere(
              (p) => p.id == _selectedPlanId,
              orElse: () => plans.first,
            );

            return Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: plans.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final plan = plans[index];
                      return _PlanCard(
                        plan: plan,
                        isRecommended:
                            plan.displayName.toLowerCase() == 'profesional',
                        isSelected: plan.id == selected.id,
                        isCurrent: plan.id == currentPlanId,
                        onTap: () => setState(() => _selectedPlanId = plan.id),
                      );
                    },
                  ),
                ),
                _BottomCta(
                  label: selected.id == currentPlanId
                      ? 'Es tu plan actual'
                      : 'Suscribirme',
                  busy: _busy,
                  enabled: selected.id != currentPlanId,
                  onTap: () => _subscribe(selected),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _subscribe(BillingPlan plan) async {
    final email = await _askPayerEmail();
    if (email == null || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      final res = await ref
          .read(billingServiceProvider)
          .subscribe(planId: plan.id, payerEmail: email);
      final launched = await launchUrl(
        Uri.parse(res.initPoint),
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: kIsWeb ? '_self' : null,
      );
      if (!launched) {
        throw const BillingException(
            'No pudimos abrir Mercado Pago. Probá de nuevo.');
      }
      if (!mounted) return;
      // "Esperando confirmación": polls until the webhook activates the plan.
      navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => BillingReturnScreen(subscriptionId: res.subscriptionId),
      ));
    } on BillingException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(
          content: Text('No pudimos iniciar el pago. Probá de nuevo.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Asks for the Mercado Pago account email (prefilled with the trainer's).
  Future<String?> _askPayerEmail() {
    final ctrl =
        TextEditingController(text: ref.read(currentUserProvider)?.email ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: RedesignColors.primario700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RedesignRadius.card),
            ),
            title: Text(
              'Email de Mercado Pago',
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresá el email de la cuenta de Mercado Pago con la que vas a pagar. Tiene que ser ese mismo email.',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario300),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  style: const TextStyle(color: RedesignColors.primario50),
                  decoration: InputDecoration(
                    hintText: 'tu@email.com',
                    errorText: error,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancelar',
                    style: RedesignType.buttonSm
                        .copyWith(color: RedesignColors.primario300)),
              ),
              TextButton(
                onPressed: () {
                  final v = ctrl.text.trim();
                  if (!isValidEmail(v)) {
                    setLocal(() => error = 'Ingresá un email válido');
                    return;
                  }
                  Navigator.of(ctx).pop(v);
                },
                child: Text('Continuar',
                    style: RedesignType.buttonSm
                        .copyWith(color: RedesignColors.actionPrimaryDark)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _PlanCard
// ---------------------------------------------------------------------------

class _PlanCard extends StatelessWidget {
  final BillingPlan plan;
  final bool isRecommended;
  final bool isSelected;
  final bool isCurrent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.isRecommended,
    required this.isSelected,
    required this.isCurrent,
    required this.onTap,
  });

  List<_FeatureItem> _buildFeatures() {
    final max = plan.maxStudents;
    return [
      _FeatureItem(max == null ? 'Alumnos ilimitados' : 'Hasta $max alumnos'),
      ...plan.featureLabels.map(_FeatureItem.new),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected
        ? RedesignColors.actionPrimary
        : isRecommended
            ? RedesignColors.secundario300.withValues(alpha: 0.5)
            : RedesignColors.secundario300.withValues(alpha: 0.18);

    final name = plan.displayName;
    final priceStr = '\$ ${formatArs(plan.price)}';
    const perLabel = ' / mes';
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
  final String label;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  const _BottomCta({
    required this.label,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

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
          onPressed: enabled && !busy ? onTap : null,
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: RedesignColors.onActionPrimary,
                  ),
                )
              : Text(
                  label,
                  style: RedesignType.buttonLg.copyWith(
                    color: RedesignColors.onActionPrimary,
                  ),
                ),
        ),
      ),
    );
  }
}
