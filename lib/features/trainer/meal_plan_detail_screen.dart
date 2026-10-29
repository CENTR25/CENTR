import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_redesign.dart';
import '../../core/constants/meal_times.dart';
import '../../services/trainer_service.dart';
import '../../services/storage_service.dart';
import '../shared/redesign_toast.dart';
import 'banco_alimentos_screen.dart';
import 'student_detail_screen.dart' show studentDetailProvider;

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final mealPlanDetailProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, planId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMealPlan(planId);
});

// ---------------------------------------------------------------------------
// MealPlanDetailScreen
// ---------------------------------------------------------------------------

class MealPlanDetailScreen extends ConsumerStatefulWidget {
  final String planId;
  final String planName;
  /// Set when opened in a student context. Triggers copy-on-edit logic.
  final String? athleteId;
  final String? studentName;

  const MealPlanDetailScreen({
    super.key,
    required this.planId,
    required this.planName,
    this.athleteId,
    this.studentName,
  });

  @override
  ConsumerState<MealPlanDetailScreen> createState() =>
      _MealPlanDetailScreenState();
}

class _MealPlanDetailScreenState extends ConsumerState<MealPlanDetailScreen> {
  int _currentDay = 1;

  // How many days to show. Null = derive from the data (max day with meals).
  // The "+" pill bumps this so the trainer can build out empty days before
  // adding meals to them (there is no days column on meal_plans).
  int? _dayCountOverride;

  // After personalizing, we work on the COPY's id.
  late String _activePlanId;

  @override
  void initState() {
    super.initState();
    _activePlanId = widget.planId;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  List<int> _distinctDays(List items) {
    final days = <int>{};
    for (final item in items) {
      final d = item['day_number'];
      if (d is int) days.add(d);
    }
    final sorted = days.toList()..sort();
    return sorted.isEmpty ? [1] : sorted;
  }

  Map<String, List<Map<String, dynamic>>> _groupByTime(
      List items, int dayNum) {
    final dayItems = items
        .where((i) => i['day_number'] == dayNum)
        .map((i) => Map<String, dynamic>.from(i as Map))
        .toList();

    dayItems.sort((a, b) {
      final ao = kMealTimeOrder[a['time_of_day']] ?? 99;
      final bo = kMealTimeOrder[b['time_of_day']] ?? 99;
      final oc = ao.compareTo(bo);
      if (oc != 0) return oc;
      final ai =
          (a['order_index'] as int?) ?? (a['sort_order'] as int?) ?? 0;
      final bi =
          (b['order_index'] as int?) ?? (b['sort_order'] as int?) ?? 0;
      return ai.compareTo(bi);
    });

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final item in dayItems) {
      final time = (item['time_of_day'] as String?) ?? 'breakfast';
      grouped.putIfAbsent(time, () => []).add(item);
    }
    return grouped;
  }

  // ── Copy-on-edit gate ──────────────────────────────────────────────────────
  //
  // When in student context and the plan is a shared TEMPLATE (cloned_from == null),
  // ask the trainer before the first edit whether to personalise or update the
  // template in place.
  // Returns true if the edit should proceed; mutates _activePlanId if a copy
  // was created.

  Future<bool> _checkEditGate(
      BuildContext context, Map<String, dynamic> plan) async {
    // No student context or already a copy → edit directly
    if (widget.athleteId == null) return true;
    if (plan['cloned_from'] != null) return true;
    if (_activePlanId != widget.planId) return true; // already personalized

    // It's a shared template in student context → show the sheet
    final result = await _showWhereToApplySheet(context, plan);
    return result == true;
  }

  // Returns true to proceed, false/null to cancel.
  Future<bool?> _showWhereToApplySheet(
      BuildContext context, Map<String, dynamic> plan) async {
    final title = (plan['title'] as String?) ?? 'Plan';
    final name = widget.studentName ?? 'este alumno';

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhereToApplySheet(
        planTitle: title,
        studentName: name,
        onPersonalize: () async {
          Navigator.pop(context, true); // close sheet first
          // Perform personalization
          try {
            final newId = await ref
                .read(trainerServiceProvider)
                .personalizeMealPlanForStudent(
                  athleteId: widget.athleteId!,
                  mealPlanId: widget.planId,
                  newTitle: '$title — $name',
                );
            if (mounted) {
              setState(() => _activePlanId = newId);
              ref.invalidate(mealPlanDetailProvider(newId));
              ref.invalidate(studentDetailProvider(widget.athleteId!));
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error al personalizar: $e'),
                    backgroundColor: RedesignColors.danger),
              );
            }
          }
        },
        onUpdateTemplate: () => Navigator.pop(context, true),
      ),
    );
  }

  // ── Sheet launchers ────────────────────────────────────────────────────────

  void _showAddMealSheet(
      BuildContext context, Map<String, dynamic> plan, int day, String time) {
    _checkEditGate(context, plan).then((allowed) {
      if (!allowed || !context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NuevaComidaSheet(
          planId: _activePlanId,
          dayNumber: day,
          initialTime: time,
          onSaved: () {
            ref.invalidate(mealPlanDetailProvider(_activePlanId));
            ref.invalidate(myMealPlansProvider);
          },
        ),
      );
    });
  }

  void _showEditMealSheet(BuildContext context, Map<String, dynamic> plan,
      Map<String, dynamic> item) {
    _checkEditGate(context, plan).then((allowed) {
      if (!allowed || !context.mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NuevaComidaSheet(
          planId: _activePlanId,
          dayNumber: (item['day_number'] as int?) ?? 1,
          initialTime:
              (item['time_of_day'] as String?) ?? 'breakfast',
          editItem: item,
          onSaved: () {
            ref.invalidate(mealPlanDetailProvider(_activePlanId));
            ref.invalidate(myMealPlansProvider);
          },
        ),
      );
    });
  }

  Future<void> _deleteItem(
      BuildContext context, Map<String, dynamic> plan, String itemId) async {
    final allowed = await _checkEditGate(context, plan);
    if (!allowed || !context.mounted) return;
    try {
      await ref.read(trainerServiceProvider).removeMealPlanItem(itemId);
      ref.invalidate(mealPlanDetailProvider(_activePlanId));
      ref.invalidate(myMealPlansProvider);
      if (context.mounted) {
        showRedesignToast(context,
            title: 'Comida eliminada', icon: Icons.delete_rounded);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: RedesignColors.danger),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(mealPlanDetailProvider(_activePlanId));

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
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: planAsync.when(
            data: (plan) {
              final title = (plan?['title'] as String?) ?? widget.planName;
              final kcal = plan?['target_calories'] as int?;
              final prefix = widget.studentName != null
                  ? 'Plan de ${widget.studentName}'
                  : null;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prefix ?? title,
                    style: const TextStyle(
                      color: RedesignColors.primario50,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                  if (kcal != null)
                    Text(
                      '$kcal kcal',
                      style: const TextStyle(
                        color: RedesignColors.primario300,
                        fontSize: 12,
                        fontFamily: 'Metropolis',
                      ),
                    ),
                ],
              );
            },
            loading: () => Text(
              widget.planName,
              style: const TextStyle(
                color: RedesignColors.primario50,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Metropolis',
              ),
            ),
            error: (_, __) => Text(widget.planName),
          ),
        ),
        body: planAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: RedesignColors.actionPrimary),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: const TextStyle(color: RedesignColors.danger)),
          ),
          data: (plan) {
            if (plan == null) {
              return const Center(child: Text('Plan no encontrado'));
            }

            final items = (plan['meal_plan_items'] as List?) ?? [];
            // Show a CONTIGUOUS run of days (1..N). Base = the plan's stored
            // `days` (from the Nuevo plan flow) or the furthest day with meals,
            // whichever is larger; the "+" pill can extend it further.
            final maxDataDay = _distinctDays(items).last;
            final storedDays = (plan['days'] as int?) ?? 1;
            final baseDays = storedDays > maxDataDay ? storedDays : maxDataDay;
            final dayCount =
                (_dayCountOverride ?? baseDays).clamp(baseDays, 999);
            final days = List<int>.generate(dayCount, (i) => i + 1);

            // Keep _currentDay valid after refresh
            if (!days.contains(_currentDay)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _currentDay = days.first);
              });
            }

            final isClone = plan['cloned_from'] != null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── "Copia personalizada" banner ──────────────────────────
                if (isClone)
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: RedesignColors.primario600,
                        borderRadius:
                            BorderRadius.circular(RedesignRadius.banner),
                        border: Border.all(
                          color: RedesignColors.secundario300
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.copy_rounded,
                              color: RedesignColors.secundario300,
                              size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Copia personalizada. La plantilla no cambia.',
                              style: RedesignType.label.copyWith(
                                  color: RedesignColors.secundario300),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Day pills ─────────────────────────────────────────────
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    itemCount: days.length + 1,
                    itemBuilder: (context, index) {
                      // Trailing "+" pill: add a new (empty) day.
                      if (index == days.length) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _dayCountOverride = dayCount + 1;
                              _currentDay = dayCount + 1;
                            }),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 9),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                    RedesignRadius.buttonSm),
                                border: Border.all(
                                  color: RedesignColors.secundario300
                                      .withValues(alpha: 0.5),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(Icons.add_rounded,
                                  color: RedesignColors.secundario300,
                                  size: 20),
                            ),
                          ),
                        );
                      }
                      final day = days[index];
                      final isSelected = day == _currentDay;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _currentDay = day),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 22, vertical: 11),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? RedesignColors.secundario300
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                  RedesignRadius.buttonSm),
                              border: Border.all(
                                color: RedesignColors.secundario300
                                    .withValues(
                                        alpha: isSelected ? 1 : 0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'Día $day',
                              style: RedesignType.buttonSm.copyWith(
                                color: isSelected
                                    ? RedesignColors.secundario900
                                    : RedesignColors.secundario300,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Day content ───────────────────────────────────────────
                Expanded(
                  child: _DayContent(
                    plan: plan,
                    items: items,
                    currentDay: _currentDay,
                    groupedByTime: _groupByTime(items, _currentDay),
                    onAddMeal: (time) =>
                        _showAddMealSheet(context, plan, _currentDay, time),
                    onEditMeal: (item) =>
                        _showEditMealSheet(context, plan, item),
                    onDeleteMeal: (itemId) =>
                        _deleteItem(context, plan, itemId),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DayContent
// ---------------------------------------------------------------------------

class _DayContent extends StatelessWidget {
  final Map<String, dynamic> plan;
  final List items;
  final int currentDay;
  final Map<String, List<Map<String, dynamic>>> groupedByTime;
  final void Function(String time) onAddMeal;
  final void Function(Map<String, dynamic> item) onEditMeal;
  final void Function(String itemId) onDeleteMeal;

  const _DayContent({
    required this.plan,
    required this.items,
    required this.currentDay,
    required this.groupedByTime,
    required this.onAddMeal,
    required this.onEditMeal,
    required this.onDeleteMeal,
  });

  // The four canonical time slots used as a fallback when the plan has no
  // meal_times set. These keys must match kMealTimeOrder / kMealTimeLabels.
  static const _defaultSlots = [
    'breakfast',
    'lunch',
    'afternoon_snack',
    'dinner',
  ];

  /// Resolve which slots to render for this plan.
  /// Uses plan['meal_times'] (List) when present and non-empty,
  /// ordered by kMealTimeOrder so sections always appear top-to-bottom.
  List<String> _resolveSlots() {
    final raw = plan['meal_times'];
    if (raw is List && raw.isNotEmpty) {
      final keys = raw
          .whereType<String>()
          .where((k) => kMealTimeOrder.containsKey(k))
          .toList();
      if (keys.isNotEmpty) {
        keys.sort((a, b) =>
            (kMealTimeOrder[a] ?? 99).compareTo(kMealTimeOrder[b] ?? 99));
        return keys;
      }
    }
    return _defaultSlots;
  }

  @override
  Widget build(BuildContext context) {
    final dayItems = items.where((i) => i['day_number'] == currentDay);
    final isEmpty  = dayItems.isEmpty;
    final slots    = _resolveSlots();
    final firstSlot = slots.isNotEmpty ? slots.first : 'breakfast';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEmpty) ...[
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(Icons.restaurant_menu_rounded,
                      size: 52,
                      color: RedesignColors.primario300
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'Sin comida para este día',
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario300),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => onAddMeal(firstSlot),
                    child: Text(
                      '+ Agregar comida',
                      style: RedesignType.buttonSm.copyWith(
                        color: RedesignColors.actionPrimaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            for (final slot in slots) ...[
              _TimeSection(
                timeOfDay: slot,
                items: groupedByTime[slot] ?? [],
                onAdd: () => onAddMeal(slot),
                onEdit: onEditMeal,
                onDelete: onDeleteMeal,
              ),
              const SizedBox(height: 16),
            ],
            // Any items in slots not covered by the plan's meal_times list
            // (e.g. legacy items, morning_snack, evening_snack, snack).
            for (final entry in groupedByTime.entries)
              if (!slots.contains(entry.key) &&
                  entry.value.isNotEmpty) ...[
                _TimeSection(
                  timeOfDay: entry.key,
                  items: entry.value,
                  onAdd: () => onAddMeal(entry.key),
                  onEdit: onEditMeal,
                  onDelete: onDeleteMeal,
                ),
                const SizedBox(height: 16),
              ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TimeSection — one meal slot (e.g. Desayuno)
// ---------------------------------------------------------------------------

class _TimeSection extends StatelessWidget {
  final String timeOfDay;
  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;

  const _TimeSection({
    required this.timeOfDay,
    required this.items,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final label = kMealTimeLabels[timeOfDay] ?? timeOfDay;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              label,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onAdd,
              child: Text(
                'Agregar',
                style: RedesignType.buttonSm.copyWith(
                  color: RedesignColors.actionPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: RedesignColors.primario700.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(RedesignRadius.card),
              border: Border.all(
                color: RedesignColors.secundario300.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              'Sin comidas en este horario',
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario400),
            ),
          ),
        ] else
          for (int i = 0; i < items.length; i++) ...[
            _OptionCard(
              item: items[i],
              opNumber: i + 1,
              onEdit: () => onEdit(items[i]),
              onDelete: () => onDelete(items[i]['id'] as String),
            ),
            if (i < items.length - 1) const SizedBox(height: 8),
          ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _OptionCard — expandable item card
// ---------------------------------------------------------------------------

class _OptionCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final int opNumber;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OptionCard({
    required this.item,
    required this.opNumber,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final title = (item['meal_title'] as String?) ?? 'Comida';
    final kcal = item['calories'] as int?;
    final desc = item['meal_description'] as String?;
    final imageUrl = item['image_url'] as String?;

    return Container(
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
          // ── Header row ──────────────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(RedesignRadius.card),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // "Op N" badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: RedesignColors.primario900
                          .withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Op ${widget.opNumber}',
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario200,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Thumbnail (optional)
                  if (imageUrl != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox(
                            width: 36, height: 36),
                        errorWidget: (_, __, ___) =>
                            const SizedBox(width: 36, height: 36),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  // Title + kcal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (kcal != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '$kcal kcal',
                            style: RedesignType.label.copyWith(
                                color: RedesignColors.primario300),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Expand chevron
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: RedesignColors.primario400,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded content ────────────────────────────────────────────
          if (_expanded) ...[
            const Divider(height: 1, color: RedesignColors.primario600),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (desc != null && desc.trim().isNotEmpty) ...[
                    Text(
                      desc,
                      style: RedesignType.label.copyWith(
                          color: RedesignColors.primario200),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: RedesignColors.primario600,
                          borderRadius: BorderRadius.circular(
                              RedesignRadius.buttonLg),
                          child: InkWell(
                            onTap: widget.onEdit,
                            borderRadius: BorderRadius.circular(
                                RedesignRadius.buttonLg),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.edit_rounded,
                                      size: 16,
                                      color: RedesignColors.primario50),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Editar',
                                    style: RedesignType.buttonSm
                                        .copyWith(
                                      color: RedesignColors.primario50,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        onPressed: widget.onDelete,
                        tooltip: 'Eliminar',
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: RedesignColors.danger, size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _WhereToApplySheet — copy-on-edit decision
// ---------------------------------------------------------------------------
//
// Shown when editing a shared template in a student context.
// Two options: "Solo a X" (personalize) or "Actualizar la plantilla".
// Simplification: no "N alumnos" count. Flagged.

class _WhereToApplySheet extends StatefulWidget {
  final String planTitle;
  final String studentName;
  final Future<void> Function() onPersonalize;
  final VoidCallback onUpdateTemplate;

  const _WhereToApplySheet({
    required this.planTitle,
    required this.studentName,
    required this.onPersonalize,
    required this.onUpdateTemplate,
  });

  @override
  State<_WhereToApplySheet> createState() => _WhereToApplySheetState();
}

class _WhereToApplySheetState extends State<_WhereToApplySheet> {
  // 0 = solo a X (default), 1 = update template
  int _choice = 0;
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RedesignColors.primario900,
              RedesignColors.secundario900,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color:
                          RedesignColors.primario50.withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '¿Dónde aplicar los cambios?',
                  style: RedesignType.headingMd.copyWith(
                    color: RedesignColors.primario50,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 18),

                // Option 0: Solo a X
                _ChoiceCard(
                  selected: _choice == 0,
                  title: 'Solo a ${widget.studentName}',
                  description:
                      'Se guarda como "${widget.planTitle} — ${widget.studentName}". '
                      'La plantilla queda igual.',
                  onTap: () => setState(() => _choice = 0),
                ),
                const SizedBox(height: 10),

                // Option 1: Update template
                _ChoiceCard(
                  selected: _choice == 1,
                  title: 'Actualizar la plantilla',
                  description:
                      'Cambia el plan "${widget.planTitle}" para todos los alumnos '
                      'que lo usan.',
                  onTap: () => setState(() => _choice = 1),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            setState(() => _isSaving = true);
                            if (_choice == 0) {
                              await widget.onPersonalize();
                            } else {
                              widget.onUpdateTemplate();
                            }
                          },
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RedesignColors.onActionPrimary,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.selected,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(
            color: selected
                ? RedesignColors.secundario300
                : RedesignColors.secundario300.withValues(alpha: 0.18),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? RedesignColors.actionPrimary
                  : RedesignColors.primario400,
              size: 20,
            ),
            const SizedBox(width: 12),
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
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _NuevaComidaSheet — add or edit a meal item
// ---------------------------------------------------------------------------

class _NuevaComidaSheet extends ConsumerStatefulWidget {
  final String planId;
  final int dayNumber;
  final String initialTime;
  final Map<String, dynamic>? editItem; // non-null → EDIT mode
  final VoidCallback onSaved;

  const _NuevaComidaSheet({
    required this.planId,
    required this.dayNumber,
    required this.initialTime,
    this.editItem,
    required this.onSaved,
  });

  @override
  ConsumerState<_NuevaComidaSheet> createState() =>
      _NuevaComidaSheetState();
}

class _NuevaComidaSheetState extends ConsumerState<_NuevaComidaSheet> {
  final _nameController = TextEditingController();
  final _calController = TextEditingController();
  final _descController = TextEditingController();

  late String _selectedTime;
  String? _uploadedImageUrl;
  bool _isUploading = false;
  bool _isSaving = false;

  // The 4 canonical slots shown as pills
  static const _timeSlots = [
    'breakfast',
    'lunch',
    'afternoon_snack',
    'dinner',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;

    // Prefill from edit item
    final item = widget.editItem;
    if (item != null) {
      _nameController.text = (item['meal_title'] as String?) ?? '';
      _calController.text =
          (item['calories'] as int?)?.toString() ?? '';
      _descController.text = (item['meal_description'] as String?) ?? '';
      _uploadedImageUrl = item['image_url'] as String?;
      final t = item['time_of_day'] as String?;
      if (t != null) _selectedTime = t;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _calController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // ── Prefill from Banco de alimentos ────────────────────────────────────────

  Future<void> _openBanco() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const BancoAlimentosScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      _nameController.text = (result['meal_title'] as String?) ?? '';
      _calController.text =
          (result['calories'] as int?)?.toString() ?? '';
      _descController.text =
          (result['meal_description'] as String?) ?? '';
      _uploadedImageUrl = result['image_url'] as String?;
      final t = result['time_of_day'] as String?;
      if (t != null && kMealTimeOrder.containsKey(t)) {
        _selectedTime = t;
      }
    });
  }

  // ── Photo upload ───────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;
    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.path.split('.').last.toLowerCase();
      final url = await ref
          .read(storageServiceProvider)
          .uploadMealImageBytes(bytes, ext, widget.planId);
      if (mounted) setState(() => _uploadedImageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al subir foto: $e'),
              backgroundColor: RedesignColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El nombre es requerido.'),
            backgroundColor: RedesignColors.danger),
      );
      return;
    }
    final overlay = Overlay.maybeOf(context);
    final nav = Navigator.of(context);
    setState(() => _isSaving = true);

    try {
      final service = ref.read(trainerServiceProvider);
      final kcal = int.tryParse(_calController.text.trim());
      final desc = _descController.text.trim();

      if (widget.editItem != null) {
        // EDIT mode
        await service.updateMealPlanItem(widget.editItem!['id'] as String, {
          'meal_title': name,
          'calories': kcal,
          'meal_description': desc.isEmpty ? null : desc,
          'time_of_day': _selectedTime,
          if (_uploadedImageUrl != null) 'image_url': _uploadedImageUrl,
        });
      } else {
        // ADD mode
        await service.addMealPlanItem(
          mealPlanId: widget.planId,
          dayNumber: widget.dayNumber,
          timeOfDay: _selectedTime,
          name: name,
          description: desc.isEmpty ? null : desc,
          calories: kcal,
          imageUrl: _uploadedImageUrl,
        );
      }

      widget.onSaved();
      if (!mounted) return;
      nav.pop();
      if (overlay != null) {
        final toastCtx = overlay.context; // ignore: use_build_context_synchronously
        showRedesignToast(toastCtx, // ignore: use_build_context_synchronously
          title: widget.editItem != null
              ? '¡Guardado exitosamente!'
              : '¡Agregado exitosamente!',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: RedesignColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editItem != null;
    final timeLabel = kMealTimeLabels[_selectedTime] ?? _selectedTime;

    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RedesignColors.primario900,
              RedesignColors.secundario900,
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: RedesignColors.primario50
                          .withValues(alpha: 0.30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit ? 'Editar comida' : 'Nueva comida',
                            style: RedesignType.headingMd.copyWith(
                              color: RedesignColors.primario50,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            'Día ${widget.dayNumber} — $timeLabel',
                            style: RedesignType.label.copyWith(
                                color: RedesignColors.primario300),
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
                const SizedBox(height: 18),

                // ── Banco de alimentos CTA ──────────────────────────────
                if (!isEdit) ...[
                  GestureDetector(
                    onTap: _openBanco,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: RedesignColors.secundario300
                            .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(RedesignRadius.card),
                        border: Border.all(
                          color: RedesignColors.secundario300
                              .withValues(alpha: 0.4),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.storefront_rounded,
                              color: RedesignColors.secundario300,
                              size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Elegir del banco de alimentos',
                              style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.secundario300,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: RedesignColors.secundario300,
                              size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Divider ──────────────────────────────────────────
                  Row(
                    children: [
                      const Expanded(
                          child: Divider(
                              color: RedesignColors.primario600,
                              height: 1)),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'Cargá de manera manual',
                          style: RedesignType.label.copyWith(
                              color: RedesignColors.primario400),
                        ),
                      ),
                      const Expanded(
                          child: Divider(
                              color: RedesignColors.primario600,
                              height: 1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Foto (izq) + Nombre/Calorías (der) ──────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _isUploading ? null : _pickPhoto,
                      child: SizedBox(
                        width: 116,
                        height: 118,
                        child: CustomPaint(
                          painter: _uploadedImageUrl == null
                              ? _DashedRRectPainter(
                                  color: RedesignColors.secundario300
                                      .withValues(alpha: 0.55),
                                  radius: 18,
                                )
                              : null,
                          child: Container(
                            decoration: BoxDecoration(
                              color: RedesignColors.primario700
                                  .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(18),
                              image: _uploadedImageUrl != null
                                  ? DecorationImage(
                                      image:
                                          NetworkImage(_uploadedImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _isUploading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color:
                                            RedesignColors.actionPrimary))
                                : _uploadedImageUrl == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                              Icons.add_a_photo_rounded,
                                              color: RedesignColors
                                                  .secundario300,
                                              size: 26),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Añadir\nfotos',
                                            textAlign: TextAlign.center,
                                            style: RedesignType.label
                                                .copyWith(
                                                    color: RedesignColors
                                                        .secundario300),
                                          ),
                                        ],
                                      )
                                    : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          TextField(
                            controller: _nameController,
                            style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.primario50),
                            decoration: const InputDecoration(
                              hintText: 'Nombre de la comida',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _calController,
                            keyboardType: TextInputType.number,
                            style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.primario50),
                            decoration: const InputDecoration(
                              hintText: 'Calorías (aprox.)',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Momento del día pills ──────────────────────────────
                Text(
                  'Momento del día',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario300),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _timeSlots.map((slot) {
                    final selected = _selectedTime == slot;
                    final lbl = kMealTimeLabels[slot] ?? slot;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTime = slot),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected
                              ? RedesignColors.secundario300
                              : RedesignColors.secundario300
                                  .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                              RedesignRadius.buttonSm),
                          border: Border.all(
                            color: RedesignColors.secundario300
                                .withValues(
                                    alpha: selected ? 1 : 0.4),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          lbl,
                          style: RedesignType.buttonSm.copyWith(
                            color: selected
                                ? RedesignColors.secundario900
                                : RedesignColors.secundario300,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // ── Descripción / indicaciones ─────────────────────────
                TextField(
                  controller: _descController,
                  maxLines: 3,
                  style: RedesignType.bodySm
                      .copyWith(color: RedesignColors.primario50),
                  decoration: const InputDecoration(
                    hintText: 'Ingredientes / indicaciones',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(Icons.notes_rounded,
                          color: RedesignColors.primario400),
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Save button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RedesignColors.onActionPrimary,
                            ),
                          )
                        : Text(isEdit
                            ? 'Guardar cambios'
                            : '+ Agregar a $timeLabel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Dashed rounded-rect border — meal photo "Añadir fotos" box (Figma).
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({required this.color, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 5.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
