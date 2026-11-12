import 'package:flutter/material.dart';

/// LEGACY meal time slots (plans with no `meal_slots`). The DB now only
/// enforces a key format on meal_plan_items.time_of_day (ADR-005); custom
/// plan slots use `slot_<8 hex>` keys. Prefer the plan-aware helpers below.
const kMealTimeOrder = {
  'breakfast': 0,
  'morning_snack': 1,
  'lunch': 2,
  'afternoon_snack': 3,
  'dinner': 4,
  'evening_snack': 5,
};

const kMealTimeLabels = {
  'breakfast': 'Desayuno',
  'morning_snack': 'Colación (mañana)',
  'lunch': 'Almuerzo',
  'afternoon_snack': 'Merienda',
  'dinner': 'Cena',
  'evening_snack': 'Colación (noche)',
  // legacy value kept for old rows
  'snack': 'Merienda',
};

const kMealTimeColors = {
  'breakfast': Colors.orange,
  'morning_snack': Colors.teal,
  'lunch': Colors.red,
  'afternoon_snack': Colors.green,
  'dinner': Colors.blue,
  'evening_snack': Colors.purple,
  'snack': Colors.green,
};

// ---------------------------------------------------------------------------
// Plan-aware helpers (ADR-005)
// ---------------------------------------------------------------------------

/// One meal moment of a plan. [key] is the stable id stored in
/// meal_plan_items.time_of_day; [label] is free text the trainer can rename.
class MealSlot {
  final String key;
  final String label;
  const MealSlot(this.key, this.label);

  MealSlot withLabel(String l) => MealSlot(key, l);
  Map<String, String> toJson() => {'key': key, 'label': label};
}

/// Default slots for a brand-new plan.
const kDefaultPlanSlots = [
  MealSlot('breakfast', 'Desayuno'),
  MealSlot('lunch', 'Almuerzo'),
  MealSlot('afternoon_snack', 'Merienda'),
  MealSlot('dinner', 'Cena'),
];

String newMealSlotKey() {
  final r = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  return 'slot_${r.substring(r.length - 8)}';
}

String _asStr(dynamic v) => v is String ? v : (v?.toString() ?? '');

/// Slots of [plan] in display order. Uses `meal_slots` when set; legacy plans
/// fall back to `meal_times` (or the 4 defaults) with the static labels.
/// Item keys not covered by the plan's slots are appended (never hidden).
List<MealSlot> mealSlotsOf(Map<String, dynamic>? plan, [List? items]) {
  final out = <MealSlot>[];
  final raw = plan?['meal_slots'];
  final configured = raw is List && raw.isNotEmpty;
  if (configured) {
    for (final e in raw) {
      if (e is Map) {
        final k = _asStr(e['key']);
        if (k.isEmpty || out.any((s) => s.key == k)) continue;
        final l = _asStr(e['label']).trim();
        out.add(MealSlot(k, l.isEmpty ? (kMealTimeLabels[k] ?? 'Comida') : l));
      }
    }
  } else {
    final mt = plan?['meal_times'];
    if (mt is List) {
      for (final k in mt.map(_asStr)) {
        if (kMealTimeLabels.containsKey(k) && !out.any((s) => s.key == k)) {
          out.add(MealSlot(k, kMealTimeLabels[k]!));
        }
      }
    }
    if (out.isEmpty) out.addAll(kDefaultPlanSlots);
  }
  for (final i in items ?? const []) {
    final k = i is Map ? _asStr(i['time_of_day']) : '';
    if (k.isNotEmpty && !out.any((s) => s.key == k)) {
      out.add(MealSlot(k, kMealTimeLabels[k] ?? 'Comida'));
    }
  }
  if (!configured) {
    out.sort((a, b) =>
        (kMealTimeOrder[a.key] ?? 99).compareTo(kMealTimeOrder[b.key] ?? 99));
  }
  return out;
}

/// Label for [key] in [plan] (plan label > legacy label > 'Comida').
String mealSlotLabel(Map<String, dynamic>? plan, String key) {
  for (final s in mealSlotsOf(plan)) {
    if (s.key == key) return s.label;
  }
  return kMealTimeLabels[key] ?? 'Comida';
}

/// Position of [key] within [slots]; unknown keys sort last.
int mealSlotIndex(List<MealSlot> slots, String? key) {
  final i = slots.indexWhere((s) => s.key == key);
  return i < 0 ? 999 : i;
}

const kWeekdayNames = [
  'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
];

/// Number of days a plan shows: stored `days` (fallback 7 for legacy) or the
/// furthest day holding meals, whichever is larger (max 7).
int planDayCount(Map<String, dynamic>? plan) {
  final stored = (plan?['days'] as num?)?.toInt() ?? 7;
  var maxItem = 0;
  for (final i in (plan?['meal_plan_items'] as List?) ?? const []) {
    final d = i is Map ? (i['day_number'] as num?)?.toInt() : null;
    if (d != null && d > maxItem) maxItem = d;
  }
  return (stored > maxItem ? stored : maxItem).clamp(1, 7);
}

/// Label for day [day] (1-based): custom `day_labels[day-1]` or "Día N".
String dayLabelOf(Map<String, dynamic>? plan, int day) {
  final raw = plan?['day_labels'];
  if (raw is List && day >= 1 && day <= raw.length) {
    final l = _asStr(raw[day - 1]).trim();
    if (l.isNotEmpty) return l;
  }
  return 'Día $day';
}
