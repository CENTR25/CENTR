/// Categorías visibles en la interfaz y sus valores equivalentes en los
/// ejercicios seed o creados por un entrenador.
class ExerciseCategory {
  static const all = 'Todos';

  static const routineFilters = <String>[
    'Pecho',
    'Espalda',
    'Piernas',
    'Hombros',
    'Brazos',
    'Abdominales',
    'Cardio',
  ];

  static const Map<String, Set<String>> _aliases = {
    'pecho': {'chest', 'pectorals', 'pectoralis major', 'pecho'},
    'espalda': {
      'back',
      'upper back',
      'lower back',
      'lats',
      'latissimus dorsi',
      'traps',
      'trapezius',
      'rhomboids',
      'espalda',
    },
    'piernas': {
      'legs',
      'upper legs',
      'lower legs',
      'quadriceps',
      'hamstrings',
      'glutes',
      'calves',
      'soleus',
      'adductors',
      'abductors',
      'hip flexors',
      'piernas',
    },
    'hombros': {'shoulder', 'shoulders', 'deltoid', 'deltoids', 'hombros'},
    'brazos': {
      'arm',
      'arms',
      'upper arms',
      'biceps',
      'triceps',
      'forearms',
      'brazos',
    },
    'abdominales': {
      'waist',
      'abs',
      'abdominals',
      'core',
      'obliques',
      'abdominales',
    },
    'cardio': {'cardio', 'cardiovascular', 'cardiovascular system'},
  };

  /// Returns true when an exercise belongs to the visible category.
  ///
  /// Seed exercises use `category`/`body_part` (for example `upper legs`),
  /// while custom exercises generally only have `muscle_group` in Spanish.
  /// The primary category is preferred so a chest exercise whose secondary
  /// muscle is triceps is not incorrectly shown as an arm exercise.
  static bool matches(Map<String, dynamic> exercise, String? filter) {
    final normalizedFilter = normalize(filter);
    if (normalizedFilter.isEmpty || normalizedFilter == normalize(all)) {
      return true;
    }

    final aliases = _aliases[normalizedFilter];
    if (aliases == null) {
      return normalize(exercise['muscle_group']) == normalizedFilter;
    }

    final primaryCategory = firstValue([
      exercise['category'],
      exercise['body_part'],
    ]);
    if (primaryCategory.isNotEmpty) {
      return aliases.contains(normalize(primaryCategory));
    }

    return aliases.contains(normalize(exercise['muscle_group']));
  }

  static String firstValue(Iterable<Object?> values) {
    for (final value in values) {
      final normalized = normalize(value);
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  static String normalize(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }
}
