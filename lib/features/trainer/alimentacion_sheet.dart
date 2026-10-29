import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';
import 'meal_plan_detail_screen.dart';
import 'cambiar_plan_screen.dart';
import 'student_detail_screen.dart' show studentDetailProvider;

// ---------------------------------------------------------------------------
// AlimentacionSheet
//
// Gradient bottom sheet opened from the student-detail Plan tab.
// Shows the active meal plan (if any) with actions: Editar, Cambiar, Quitar.
// If no plan: shows a single "Asignar plan" CTA.
// ---------------------------------------------------------------------------

class AlimentacionSheet extends ConsumerStatefulWidget {
  final String athleteId;
  final String studentName;
  /// Active assignment row from athlete_meal_plans (or null).
  /// Shape: { meal_plan_id: String, meal_plans: { id, title, target_calories, image_url, cloned_from, ... }, ... }
  final Map<String, dynamic>? activeMealPlan;

  const AlimentacionSheet({
    super.key,
    required this.athleteId,
    required this.studentName,
    required this.activeMealPlan,
  });

  @override
  ConsumerState<AlimentacionSheet> createState() => _AlimentacionSheetState();
}

class _AlimentacionSheetState extends ConsumerState<AlimentacionSheet> {
  bool _isRemoving = false;

  // Derive distinct-day count from meal_plan_items.
  int _daysCount(Map<String, dynamic>? plan) {
    if (plan == null) return 0;
    final items = (plan['meal_plan_items'] as List?) ?? [];
    final days = <int>{};
    for (final item in items) {
      final d = item['day_number'];
      if (d is int) days.add(d);
    }
    return days.isEmpty ? 1 : days.length;
  }

  Future<void> _quitarPlan() async {
    final nav = Navigator.of(context);
    final overlay = Overlay.maybeOf(context);
    setState(() => _isRemoving = true);
    try {
      await ref
          .read(trainerServiceProvider)
          .unassignMealPlanFromStudent(widget.athleteId);
      ref.invalidate(studentDetailProvider(widget.athleteId));
      if (!mounted) return;
      nav.pop();
      if (overlay != null) {
        showRedesignToast(
          overlay.context,
          title: 'Plan quitado',
          subtitle: 'El alumno ya no tiene plan asignado.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRemoving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: RedesignColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.activeMealPlan?['meal_plans'] as Map<String, dynamic>?;
    final planId = widget.activeMealPlan?['meal_plan_id'] as String?;

    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RedesignColors.primario900, RedesignColors.secundario900],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Handle + header ─────────────────────────────────────────────
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 14, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alimentación',
                            style: RedesignType.headingMd.copyWith(
                              color: RedesignColors.primario50,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.studentName,
                            style: RedesignType.bodySm
                                .copyWith(color: RedesignColors.primario300),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            color: RedesignColors.primario300, size: 24),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ─────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  child: plan != null && planId != null
                      ? _WithPlan(
                          plan: plan,
                          planId: planId,
                          daysCount: _daysCount(plan),
                          athleteId: widget.athleteId,
                          studentName: widget.studentName,
                          isRemoving: _isRemoving,
                          onQuitar: _quitarPlan,
                        )
                      : _NoPlan(
                          athleteId: widget.athleteId,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WithPlan — plan is assigned; show card + 3 action rows
// ---------------------------------------------------------------------------

class _WithPlan extends StatelessWidget {
  final Map<String, dynamic> plan;
  final String planId;
  final int daysCount;
  final String athleteId;
  final String studentName;
  final bool isRemoving;
  final VoidCallback onQuitar;

  const _WithPlan({
    required this.plan,
    required this.planId,
    required this.daysCount,
    required this.athleteId,
    required this.studentName,
    required this.isRemoving,
    required this.onQuitar,
  });

  @override
  Widget build(BuildContext context) {
    final title = (plan['title'] as String?) ?? 'Plan';
    final kcal = plan['target_calories'] as int?;
    final imageUrl = plan['image_url'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ── Plan thumbnail card ───────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: RedesignColors.primario700,
            borderRadius: BorderRadius.circular(RedesignRadius.card),
            border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const _ThumbPlaceholder(),
                        errorWidget: (_, __, ___) => const _ThumbPlaceholder(),
                      )
                    : const _ThumbPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${kcal != null ? '$kcal kcal · ' : ''}$daysCount ${daysCount == 1 ? 'día' : 'días'}',
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Action rows ───────────────────────────────────────────────────
        _ActionRow(
          icon: Icons.edit_rounded,
          title: 'Editar plan',
          subtitle: 'Ajusta las comidas',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MealPlanDetailScreen(
                  planId: planId,
                  planName: title,
                  athleteId: athleteId,
                  studentName: studentName,
                ),
              ),
            );
          },
        ),
        const _ActionDivider(),
        _ActionRow(
          icon: Icons.swap_horiz_rounded,
          title: 'Cambiar plan',
          subtitle: 'Elegir otro de la biblioteca',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CambiarPlanScreen(athleteId: athleteId),
              ),
            );
          },
        ),
        const _ActionDivider(),
        _ActionRow(
          icon: Icons.remove_circle_outline_rounded,
          title: isRemoving ? 'Quitando...' : 'Quitar plan',
          subtitle: null,
          isDanger: true,
          trailing: isRemoving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: RedesignColors.danger,
                  ),
                )
              : null,
          onTap: isRemoving ? null : onQuitar,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _NoPlan — no plan assigned; single CTA button
// ---------------------------------------------------------------------------

class _NoPlan extends StatelessWidget {
  final String athleteId;

  const _NoPlan({required this.athleteId});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: RedesignColors.primario700,
            borderRadius: BorderRadius.circular(RedesignRadius.card),
            border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.restaurant_menu_rounded,
                  size: 48,
                  color: RedesignColors.primario300.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Sin plan asignado',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CambiarPlanScreen(athleteId: athleteId),
                ),
              );
            },
            child: const Text('Asignar plan'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared small widgets
// ---------------------------------------------------------------------------

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: RedesignColors.primario800,
      child: const Icon(Icons.restaurant_rounded,
          size: 24, color: RedesignColors.primario400),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isDanger;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isDanger = false,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDanger ? RedesignColors.danger : RedesignColors.primario50;
    final subColor = isDanger
        ? RedesignColors.danger.withValues(alpha: 0.7)
        : RedesignColors.primario300;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: RedesignType.bodySm.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style:
                          RedesignType.label.copyWith(color: subColor),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: RedesignColors.primario400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ActionDivider extends StatelessWidget {
  const _ActionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      color: RedesignColors.primario700,
    );
  }
}
