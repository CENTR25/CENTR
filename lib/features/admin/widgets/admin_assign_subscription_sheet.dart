import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../shared/redesign_toast.dart';
import 'admin_common.dart';
import 'admin_redesign_sheet.dart';

/// "Asignar suscripción" modal (Figma Second Batch). Pick a plan + start date
/// and assign it to [trainerId].
class AdminAssignSubscriptionSheet extends ConsumerStatefulWidget {
  final String trainerId;
  final String trainerName;

  const AdminAssignSubscriptionSheet({
    super.key,
    required this.trainerId,
    required this.trainerName,
  });

  @override
  ConsumerState<AdminAssignSubscriptionSheet> createState() =>
      _AdminAssignSubscriptionSheetState();
}

class _AdminAssignSubscriptionSheetState
    extends ConsumerState<AdminAssignSubscriptionSheet> {
  String? _selectedPlanId;
  DateTime _startDate = DateTime.now();
  bool _loading = false;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: RedesignTheme.theme.copyWith(
          colorScheme: RedesignTheme.theme.colorScheme.copyWith(
            surface: RedesignColors.primario800,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _assign() async {
    final planId = _selectedPlanId;
    if (planId == null) return;
    setState(() => _loading = true);
    try {
      await ref.read(adminServiceProvider).assignSubscription(
            trainerId: widget.trainerId,
            planId: planId,
            startsAt: _startDate,
          );
      ref.invalidate(adminTrainersProvider);
      ref.invalidate(adminTrainerDetailProvider(widget.trainerId));
      ref.invalidate(adminPendientesProvider);
      ref.invalidate(adminDashboardMetricsProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop(true);
      showRedesignToast(
        nav.context,
        title: 'Suscripción asignada',
        subtitle: 'El plan se asignó correctamente.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
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
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final dateLabel = _isToday(_startDate)
        ? 'Hoy ${adminShortDate(_startDate.toIso8601String())}'
        : adminShortDate(_startDate.toIso8601String());

    return AdminRedesignSheet(
      children: [
        Text(
          'Asignar suscripción',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.trainerName,
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 18),
        plansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text(
            'No se pudieron cargar los planes',
            style: RedesignType.label
                .copyWith(color: RedesignColors.primario400),
          ),
          data: (plans) {
            if (plans.isEmpty) {
              return Text(
                'No hay planes disponibles.',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300),
              );
            }
            return Column(
              children: [
                for (final plan in plans) _planOption(plan),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _pickDate,
          child: Row(
            children: [
              Text(
                'Inicio',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300),
              ),
              const Spacer(),
              Text(
                dateLabel,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_rounded,
                  color: RedesignColors.primario300, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_selectedPlanId == null || _loading) ? null : _assign,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary,
                    ),
                  )
                : const Text('Asignar plan'),
          ),
        ),
      ],
    );
  }

  Widget _planOption(Map<String, dynamic> plan) {
    final id = plan['id'] as String;
    final selected = id == _selectedPlanId;
    final name = plan['name'] as String? ?? 'Plan';
    final maxStudents = plan['max_students'] as int?;
    final durationDays = plan['duration_days'] as int?;
    final subtitle = [
      if (maxStudents != null) 'Hasta $maxStudents alumnos',
      if (durationDays != null) '$durationDays días',
    ].join(' - ');

    return GestureDetector(
      onTap: () => setState(() => _selectedPlanId = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RedesignColors.primario900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? RedesignColors.actionPrimaryDark
                : RedesignColors.primario600,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? RedesignColors.actionPrimary
                  : RedesignColors.primario500,
              size: 24,
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
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}
