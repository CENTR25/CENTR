import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_plan_editor_sheet.dart';
import '../widgets/admin_redesign_sheet.dart';
import 'admin_trainer_detail_screen.dart';

/// Admin plan detail (Figma Second Batch): plan info + chips, Entrenadores /
/// Ingreso-mes stats, the trainers on this plan, assign + deactivate + edit.
class AdminPlanDetailScreen extends ConsumerWidget {
  final Map<String, dynamic> plan;

  const AdminPlanDetailScreen({super.key, required this.plan});

  String get _planId => plan['id'] as String;

  void _openEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminPlanEditorSheet(plan: plan),
    );
  }

  void _openAssign(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignTrainerToPlanSheet(
        planId: _planId,
        planName: plan['name'] as String? ?? 'Plan',
      ),
    );
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            'Desactivar plan',
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'El plan dejará de estar disponible para nuevas asignaciones.',
            style:
                RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: RedesignType.buttonSm
                      .copyWith(color: RedesignColors.primario50)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Desactivar',
                  style: RedesignType.buttonSm
                      .copyWith(color: RedesignColors.danger)),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminServiceProvider).deactivatePlan(_planId);
      ref.invalidate(subscriptionPlansProvider);
      ref.invalidate(planTrainerCountsProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      showRedesignToast(
        context,
        title: 'Plan desactivado',
        subtitle: 'Ya no está disponible.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'No se pudo desactivar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = plan['name'] as String? ?? 'Plan';
    final price = (plan['price'] as num?) ?? 0;
    final duration = plan['duration_days'] as int?;
    final max = plan['max_students'] as int?;
    final features = adminFeatureLabels(plan['features']);
    final trainersAsync = ref.watch(trainersByPlanProvider(_planId));
    final trainers = trainersAsync.valueOrNull ?? const [];
    final count = trainers.length;
    final ingresoMes = count * price;

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
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _openEdit(context),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: RedesignColors.primario700,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color:
                          RedesignColors.secundario300.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_outlined,
                          color: RedesignColors.primario50, size: 16),
                      const SizedBox(width: 6),
                      Text('Editar',
                          style: RedesignType.buttonSm.copyWith(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              name,
              style: RedesignType.headingMd.copyWith(
                color: RedesignColors.primario50,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${adminFormatCurrency(price)} / mes'
              '${duration != null ? ' · $duration días' : ''}',
              style:
                  RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (max != null) _chip('Hasta $max alumnos'),
                for (final f in features) _chip(f),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _statCard('Entrenadores', '$count')),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                      'Ingreso / mes', adminFormatCurrency(ingresoMes)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            trainersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e',
                  style: const TextStyle(color: RedesignColors.danger)),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Ningún entrenador en este plan todavía.',
                      style: RedesignType.bodySm
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  );
                }
                return Column(
                  children: [for (final t in list) _TrainerOnPlanRow(trainer: t)],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAssign(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Asignar a un entrenador'),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () => _confirmDeactivate(context, ref),
                child: Text(
                  'Desactivar plan',
                  style: RedesignType.buttonLg.copyWith(
                    color: RedesignColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: RedesignColors.secundario300.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        label,
        style: RedesignType.buttonSm
            .copyWith(color: RedesignColors.secundario200),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerOnPlanRow extends StatelessWidget {
  final Map<String, dynamic> trainer;
  const _TrainerOnPlanRow({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final name = (trainer['name'] ?? 'Entrenador').toString();
    final photo = trainer['profile_photo'] as String?;
    final id = trainer['trainer_id'] as String;
    final alumnos = trainer['alumnos_count'] as int? ?? 0;
    final renueva = adminShortDate(trainer['ends_at'] as String?);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'E';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminTrainerDetailScreen(trainerId: id),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: RedesignColors.primario700,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? NetworkImage(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
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
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$alumnos alumnos · renueva $renueva',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
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

// ── Assign an existing trainer to this plan ───────────────────────────────
class _AssignTrainerToPlanSheet extends ConsumerStatefulWidget {
  final String planId;
  final String planName;

  const _AssignTrainerToPlanSheet({
    required this.planId,
    required this.planName,
  });

  @override
  ConsumerState<_AssignTrainerToPlanSheet> createState() =>
      _AssignTrainerToPlanSheetState();
}

class _AssignTrainerToPlanSheetState
    extends ConsumerState<_AssignTrainerToPlanSheet> {
  String? _busyTrainerId;

  Future<void> _assign(String trainerId) async {
    setState(() => _busyTrainerId = trainerId);
    try {
      await ref.read(adminServiceProvider).assignSubscription(
            trainerId: trainerId,
            planId: widget.planId,
          );
      ref.invalidate(trainersByPlanProvider(widget.planId));
      ref.invalidate(planTrainerCountsProvider);
      ref.invalidate(adminTrainersProvider);
      ref.invalidate(adminTrainerDetailProvider(trainerId));
      ref.invalidate(adminPendientesProvider);
      ref.invalidate(adminDashboardMetricsProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: 'Plan asignado',
        subtitle: 'Se asignó ${widget.planName}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyTrainerId = null);
      showRedesignToast(
        context,
        title: 'No se pudo asignar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainersAsync = ref.watch(adminTrainersProvider);
    return AdminRedesignSheet(
      children: [
        Text(
          'Asignar a un entrenador',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.planName,
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 16),
        trainersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Error: $e',
              style: const TextStyle(color: RedesignColors.danger)),
          data: (trainers) {
            if (trainers.isEmpty) {
              return Text(
                'No hay entrenadores.',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in trainers) _row(t),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _row(Map<String, dynamic> t) {
    final id = t['id'] as String;
    final name = (t['name'] ?? 'Entrenador').toString();
    final photo = t['profile_photo'] as String?;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'E';
    final busy = _busyTrainerId == id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: busy ? null : () => _assign(id),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RedesignColors.primario900.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: RedesignColors.primario600),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: RedesignColors.primario700,
                backgroundImage: (photo != null && photo.isNotEmpty)
                    ? NetworkImage(photo)
                    : null,
                child: (photo == null || photo.isEmpty)
                    ? Text(initial,
                        style: const TextStyle(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                        ))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: RedesignColors.actionPrimary,
                  ),
                )
              else
                const Icon(Icons.add_circle_outline_rounded,
                    color: RedesignColors.actionPrimaryDark, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
