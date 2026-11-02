import 'package:flutter/material.dart';
import '../core/theme/theme_redesign.dart';
import '../models/athlete_schedule_slot.dart';

/// Frequency dropdown for "Días por semana" — picks how many times per week
/// (1–7). Shows "N veces" (or "1 vez").
class DaysPerWeekDropdown extends StatelessWidget {
  final int value; // 1–7
  final ValueChanged<int> onChanged;

  const DaysPerWeekDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: RedesignColors.primario300.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value.clamp(1, 7),
          isExpanded: true,
          dropdownColor: RedesignColors.primario800,
          borderRadius: BorderRadius.circular(16),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: RedesignColors.primario300),
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          items: [
            for (var n = 1; n <= 7; n++)
              DropdownMenuItem(
                value: n,
                child: Text(n == 1 ? '1 vez' : '$n veces'),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// A horizontal, multi-select set of weekday pills (Lunes … Domingo) used in the
/// create / edit routine sheets under "Selecciona qué días". Weekday numbers are
/// 1=Mon … 7=Sun (DateTime.weekday).
class WeekdayPills extends StatelessWidget {
  /// Selected weekday numbers (1–7).
  final Set<int> selected;

  /// Called with the tapped weekday number so the parent can toggle it.
  final ValueChanged<int> onToggle;

  const WeekdayPills({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(7, (i) {
        final weekday = i + 1; // 1=Mon … 7=Sun
        final isSelected = selected.contains(weekday);
        return GestureDetector(
          onTap: () => onToggle(weekday),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? RedesignColors.secundario300.withValues(alpha: 0.16)
                  : RedesignColors.primario800,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: isSelected
                    ? RedesignColors.secundario300
                    : RedesignColors.primario300.withValues(alpha: 0.25),
                width: isSelected ? 1.2 : 0.5,
              ),
            ),
            child: Text(
              kWeekdayNamesEs[i],
              style: RedesignType.bodySm.copyWith(
                color: isSelected
                    ? RedesignColors.secundario300
                    : RedesignColors.primario200,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      }),
    );
  }
}
