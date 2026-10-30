import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_plan_editor_sheet.dart';
import 'admin_plan_detail_screen.dart';

/// Admin Suscripciones — list of subscription plans with trainer counts.
class AdminSubscriptionsView extends ConsumerWidget {
  const AdminSubscriptionsView({super.key});

  void _openCreate(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminPlanEditorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final countsAsync = ref.watch(planTrainerCountsProvider);
    final counts = countsAsync.valueOrNull ?? const <String, int>{};

    return RefreshIndicator(
      color: RedesignColors.actionPrimary,
      backgroundColor: RedesignColors.primario800,
      onRefresh: () async {
        ref.invalidate(subscriptionPlansProvider);
        ref.invalidate(planTrainerCountsProvider);
        await ref.read(subscriptionPlansProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminGradientHeader(
              title: 'Suscripciones',
              trailing:
                  AdminAddPillButton(label: 'Crear', onTap: () => _openCreate(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
              child: plansAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(color: RedesignColors.danger),
                  ),
                ),
                data: (plans) {
                  if (plans.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No hay planes. Creá el primero.',
                          style: RedesignType.bodySm
                              .copyWith(color: RedesignColors.primario300),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final p in plans)
                        _PlanCard(
                          plan: p,
                          trainerCount: counts[p['id']] ?? 0,
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;
  final int trainerCount;

  const _PlanCard({required this.plan, required this.trainerCount});

  @override
  Widget build(BuildContext context) {
    final name = plan['name'] as String? ?? 'Plan';
    final price = (plan['price'] as num?) ?? 0;
    final max = plan['max_students'] as int?;
    final features = adminFeatureLabels(plan['features']);
    final subtitle = [
      if (max != null) 'Hasta $max alumnos',
      if (features.isNotEmpty) features.join(', '),
    ].join(' - ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: AdminCard(
        padding: const EdgeInsets.all(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminPlanDetailScreen(plan: plan),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: RedesignType.bodyMd.copyWith(
                      color: RedesignColors.primario50,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    trainerCount == 0
                        ? 'Sin entrenadores'
                        : '$trainerCount entrenador${trainerCount == 1 ? '' : 'es'}',
                    style: RedesignType.label.copyWith(
                      color: trainerCount == 0
                          ? RedesignColors.primario400
                          : RedesignColors.secundario300,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        adminFormatCurrency(price),
                        style: RedesignType.bodyMd.copyWith(
                          color: RedesignColors.primario50,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '/mes',
                        style: RedesignType.label
                            .copyWith(color: RedesignColors.primario400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario400, size: 20),
          ],
        ),
      ),
    );
  }
}
