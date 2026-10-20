import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/meal_times.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';
import 'student_routine_screen.dart';
import 'widgets/student_bottom_nav.dart';

/// Student "Mi plan alimenticio" — PRGS navy/teal redesign (Figma 291:2478 /
/// 300:1979). Days are pills (Día 1..7); meals are grouped by time-of-day with
/// a per-day progress card. Completions are logged against today regardless of
/// the day tab (same model as the old screen).
class StudentMealPlanScreen extends ConsumerStatefulWidget {
  const StudentMealPlanScreen({super.key});

  @override
  ConsumerState<StudentMealPlanScreen> createState() =>
      _StudentMealPlanScreenState();
}

class _StudentMealPlanScreenState
    extends ConsumerState<StudentMealPlanScreen> {
  static const int _daysCount = 7;

  // 1-based day (Día N). Default to today — plan "Día 1..7" maps to Mon..Sun
  // (Dart weekday: Mon=1..Sun=7).
  int _selectedDay = DateTime.now().weekday.clamp(1, _daysCount);

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(activeMealPlanProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        extendBody: true,
        bottomNavigationBar: StudentBottomNav(
          active: StudentNavTab.nutricion,
          onInicioTap: () =>
              Navigator.of(context).popUntil((r) => r.isFirst),
          onEntrenarTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentRoutineScreen(),
              fullscreenDialog: true,
            ),
          ),
          onNutricionTap: () {},
        ),
        body: planAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor:
                  AlwaysStoppedAnimation<Color>(RedesignColors.actionPrimary),
            ),
          ),
          error: (e, _) => _CenteredState(
            icon: Icons.error_outline_rounded,
            label: 'No se pudo cargar tu plan',
          ),
          data: (plan) => _buildPlan(plan),
        ),
      ),
    );
  }

  Widget _buildPlan(Map<String, dynamic>? plan) {
    final description = (plan?['description'] as String?)?.trim();
    final items = (plan?['meal_plan_items'] as List?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(badge: description),
        const SizedBox(height: 18),
        _DayPills(
          count: _daysCount,
          selected: _selectedDay,
          onSelect: (d) => setState(() => _selectedDay = d),
        ),
        const SizedBox(height: 14),
        const Divider(
          height: 1,
          thickness: 1,
          color: RedesignColors.primario700,
          indent: 22,
          endIndent: 22,
        ),
        Expanded(
          child: plan == null
              ? _CenteredState(
                  icon: Icons.restaurant_menu_rounded,
                  label: 'No tenés un plan activo',
                )
              : _DayView(
                  dayNumber: _selectedDay,
                  items: items,
                  targetCalories: (plan['target_calories'] as num?)?.toInt(),
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header — title + "Definición" badge
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String? badge;
  const _Header({this.badge});

  @override
  Widget build(BuildContext context) {
    // Clear the device status bar (time/battery) — on web this resolves to the
    // 24px floor so the title still gets breathing room from the top.
    final topInset = MediaQuery.of(context).padding.top.clamp(24.0, 100.0) + 14;
    return Padding(
      padding: EdgeInsets.fromLTRB(22, topInset, 22, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Mi plan alimenticio',
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario50,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ),
          ),
          if (badge != null && badge!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: RedesignColors.primario700,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario200,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day pills (Día 1..N)
// ---------------------------------------------------------------------------

class _DayPills extends StatelessWidget {
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;

  const _DayPills({
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final day = i + 1;
          final isActive = day == selected;
          return GestureDetector(
            onTap: () => onSelect(day),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              decoration: BoxDecoration(
                color: isActive
                    ? RedesignColors.secundario300
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: RedesignColors.secundario300
                      .withValues(alpha: isActive ? 1 : 0.55),
                  width: 1.5,
                ),
              ),
              child: Text(
                'Día $day',
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: isActive
                      ? RedesignColors.onActionPrimary
                      : RedesignColors.secundario300,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day view — progress card + meal groups, or "Día libre"
// ---------------------------------------------------------------------------

class _DayView extends ConsumerWidget {
  final int dayNumber;
  final List<dynamic> items;
  final int? targetCalories;

  const _DayView({
    required this.dayNumber,
    required this.items,
    required this.targetCalories,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayItems = items
        .where((i) => (i['day_number'] as num?)?.toInt() == dayNumber)
        .toList();

    if (dayItems.isEmpty) {
      return _CenteredState(
        icon: Icons.restaurant_rounded,
        label: 'Día libre',
      );
    }

    // Completions are logged against today; a tick on any day tab counts today.
    final completions =
        ref.watch(todayMealCompletionsProvider).valueOrNull ?? const <String>{};

    bool isDone(dynamic item) {
      final id = item['id'] as String?;
      return id != null && completions.contains(id);
    }

    int kcalOf(dynamic item) => (item['calories'] as num?)?.toInt() ?? 0;

    // Progress (per-item + plan target).
    final total = dayItems.length;
    final doneCount = dayItems.where(isDone).length;
    final consumed =
        dayItems.where(isDone).fold<int>(0, (s, i) => s + kcalOf(i));
    final hasTarget = targetCalories != null && targetCalories! > 0;
    final fraction = hasTarget
        ? (consumed / targetCalories!).clamp(0.0, 1.0)
        : (total > 0 ? doneCount / total : 0.0);

    // Group by time-of-day, ordered by the canonical meal-time order.
    final ordered = [...dayItems]..sort((a, b) {
        final ao = kMealTimeOrder[a['time_of_day']] ?? 99;
        final bo = kMealTimeOrder[b['time_of_day']] ?? 99;
        return ao.compareTo(bo);
      });
    final groups = <String, List<dynamic>>{};
    for (final item in ordered) {
      final key = (item['time_of_day'] as String?) ?? 'meal';
      groups.putIfAbsent(key, () => []).add(item);
    }

    Future<void> toggle(String id) async {
      await ref
          .read(studentServiceProvider)
          .toggleMealCompletion(id, !completions.contains(id));
      ref.invalidate(todayMealCompletionsProvider);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 120),
      children: [
        _ProgressCard(
          doneCount: doneCount,
          total: total,
          consumed: consumed,
          target: hasTarget ? targetCalories : null,
          fraction: fraction,
        ),
        const SizedBox(height: 24),
        for (final entry in groups.entries) ...[
          _GroupHeader(
            label: kMealTimeLabels[entry.key] ?? 'Comida',
            kcal: entry.value.fold<int>(0, (s, i) => s + kcalOf(i)),
          ),
          const SizedBox(height: 12),
          for (final item in entry.value) ...[
            _MealRow(
              title: (item['meal_title'] as String?) ?? '',
              description: (item['meal_description'] as String?)?.trim(),
              isDone: isDone(item),
              onTap: item['id'] is String
                  ? () => toggle(item['id'] as String)
                  : null,
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress card
// ---------------------------------------------------------------------------

class _ProgressCard extends StatelessWidget {
  final int doneCount;
  final int total;
  final int consumed;
  final int? target;
  final double fraction;

  const _ProgressCard({
    required this.doneCount,
    required this.total,
    required this.consumed,
    required this.target,
    required this.fraction,
  });

  @override
  Widget build(BuildContext context) {
    final kcalText =
        target != null ? '$consumed de $target kcal' : '$consumed kcal';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RedesignColors.primario700, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  '$doneCount de $total comidas',
                  style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario50,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                kcalText,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario400,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: RedesignColors.primario700,
              valueColor: const AlwaysStoppedAnimation<Color>(
                RedesignColors.actionPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Meal-time group header
// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  final String label;
  final int kcal;

  const _GroupHeader({required this.label, required this.kcal});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (kcal > 0)
          Text(
            '${kcal}kcal',
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario400,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Meal row — check circle + title/description
// ---------------------------------------------------------------------------

class _MealRow extends StatelessWidget {
  final String title;
  final String? description;
  final bool isDone;
  final VoidCallback? onTap;

  const _MealRow({
    required this.title,
    required this.description,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: isDone
              ? RedesignColors.secundario900
              : RedesignColors.primario700,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDone
                ? RedesignColors.secundario500
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CheckCircle(isDone: isDone),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description!,
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.primario300,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.3,
                      ),
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
}

class _CheckCircle extends StatelessWidget {
  final bool isDone;
  const _CheckCircle({required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? RedesignColors.actionPrimary : Colors.transparent,
        border: Border.all(
          color: isDone
              ? RedesignColors.actionPrimary
              : RedesignColors.primario400,
          width: 2,
        ),
      ),
      child: isDone
          ? const Icon(
              Icons.check_rounded,
              size: 18,
              color: RedesignColors.onActionPrimary,
            )
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Centered icon + label (empty / error / día libre)
// ---------------------------------------------------------------------------

class _CenteredState extends StatelessWidget {
  final IconData icon;
  final String label;

  const _CenteredState({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: RedesignColors.primario500),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario400,
              fontSize: 17,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
