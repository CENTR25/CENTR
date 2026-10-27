// Shared constants/helpers for the student profile view + edit screens.

/// Objetivo options (design's 5 chips). Stored in athletes.goal.
const kObjetivoOptions = [
  'Déficit',
  'Ganar masa muscular',
  'Rendimiento',
  'Salud',
  'Mantener',
];

/// Training level options. Stored in athletes.training_level.
const kNivelOptions = ['Principiante', 'Intermedio', 'Avanzado'];

/// Format a numeric value stripping a trailing ".0" (78.0 -> "78").
String fmtNum(dynamic v) {
  if (v == null) return '';
  if (v is num) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }
  return v.toString();
}
