import 'package:flutter/material.dart';

/// Meal time slots. Must match the DB check constraint on
/// meal_plan_items.time_of_day (6 values — supports up to 6 comidas/día).
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
