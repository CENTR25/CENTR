/// One entry of the trainer home "Primeros pasos" checklist, as configured by
/// the admin. `id` ties the entry to its auto-detection logic in the app, so
/// the admin edits wording / visibility / order but never the completion rule.
class FirstStepConfig {
  final String id;
  final String label;
  final bool enabled;

  const FirstStepConfig({
    required this.id,
    required this.label,
    this.enabled = true,
  });

  FirstStepConfig copyWith({String? label, bool? enabled}) => FirstStepConfig(
        id: id,
        label: label ?? this.label,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'label': label, 'enabled': enabled};

  /// Built-in steps, in default order. Also the source of truth for which ids
  /// exist: stored entries with unknown ids are ignored.
  static const defaults = <FirstStepConfig>[
    FirstStepConfig(id: 'student', label: 'Invita a tu primer alumno'),
    FirstStepConfig(id: 'routine', label: 'Crea tu primera rutina'),
    FirstStepConfig(id: 'mealplan', label: 'Crea tu primer plan alimenticio'),
    FirstStepConfig(id: 'intake', label: 'Revisa el formulario de atleta'),
    FirstStepConfig(
        id: 'reading', label: 'Completa la sección de lectura obligatoria'),
    FirstStepConfig(
        id: 'video', label: 'Agrega tus propios videos al listado de ejercicios'),
  ];

  /// Merge the stored admin config over [defaults]: stored order and edits
  /// win, unknown ids are dropped, steps missing from storage are appended.
  static List<FirstStepConfig> merge(Object? stored) {
    final byId = {for (final d in defaults) d.id: d};
    final result = <FirstStepConfig>[];
    if (stored is List) {
      for (final raw in stored) {
        if (raw is! Map) continue;
        final id = raw['id'];
        final base = byId.remove(id);
        if (base == null) continue;
        final label = raw['label'];
        result.add(FirstStepConfig(
          id: base.id,
          label: label is String && label.trim().isNotEmpty
              ? label.trim()
              : base.label,
          enabled: raw['enabled'] is bool ? raw['enabled'] as bool : true,
        ));
      }
    }
    result.addAll(byId.values);
    return result;
  }
}
