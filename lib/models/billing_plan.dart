import '../core/utils/billing_format.dart';

/// A subscription plan a trainer can buy (subscription_plans, audience 'trainer').
class BillingPlan {
  final String id;
  final String name;
  final double price;
  final String currencyId;
  final int? maxStudents; // null = unlimited
  final List<String> featureLabels;

  const BillingPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currencyId,
    required this.maxStudents,
    required this.featureLabels,
  });

  /// "Plan Profesional" -> "Profesional".
  String get displayName =>
      name.startsWith('Plan ') ? name.substring(5) : name;

  factory BillingPlan.fromMap(Map<String, dynamic> m) => BillingPlan(
        id: asStr(m['id']) ?? '',
        name: asStr(m['name']) ?? '',
        price: asDouble(m['price']) ?? 0,
        currencyId: asStr(m['currency_id']) ?? 'ARS',
        maxStudents: asInt(m['max_students']),
        featureLabels: _featureLabels(m['features']),
      );

  /// Feature gating (Analytics / Marca personalizada / API) is pending Alan's
  /// definition, so the stored `features` jsonb is deliberately NOT shown to
  /// trainers: only the confirmed student cap and price are rendered. The DB
  /// data is kept untouched.
  static List<String> _featureLabels(Object? f) => const [];
}
