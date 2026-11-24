// Pure helpers for billing display (es-AR). No Flutter / intl dependency so
// they are trivially unit-testable.

/// Coercing readers for Supabase map values. On Flutter web the values can
/// arrive as JS-backed types that fail hard casts, so never use a bare
/// `as String?` / `as int?` on a row value.
String? asStr(Object? v) => v == null ? null : (v is String ? v : v.toString());

double? asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? asInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool asBool(Object? v) => v == true || v == 'true';

DateTime? asDate(Object? v) {
  final s = asStr(v);
  if (s == null || s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// 40000 -> "40.000" (dot thousands separator, no decimals unless needed).
String formatArs(num value) {
  final negative = value < 0;
  final abs = value.abs();
  final hasCents = (abs - abs.truncate()).abs() >= 0.005;
  final fixed = abs.toStringAsFixed(hasCents ? 2 : 0);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  final decimals = parts.length > 1 ? ',${parts[1]}' : '';
  return '${negative ? '-' : ''}$buf$decimals';
}

/// 40000 -> "$ 40.000 / mes".
String formatArsPerMonth(num value) => '\$ ${formatArs(value)} / mes';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String v) => _emailRe.hasMatch(v.trim());

/// dd/MM/yyyy in local time, or "-" for null.
String formatBillingDate(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}
