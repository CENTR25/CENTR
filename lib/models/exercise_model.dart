/// Modelo tipado para ejercicios.
///
/// Compatible con dos fuentes:
/// - `source: 'seed'`   → ejercicios importados del dataset hasaneyldrm/exercises-dataset
/// - `source: 'trainer'` → ejercicios creados manualmente por trainers
///
/// Para 'seed' los campos extras (equipment, target, media_id, gif_url etc.)
/// están dentro de `instructionsI18n` como keys planas.
class ExerciseModel {
  final String id;
  final String name;
  final String? category;
  final String? bodyPart;
  final List<String> equipment;
  final String? target;
  final String? muscleGroup;
  final List<String> secondaryMuscles;
  final String? instructions;
  final Map<String, dynamic>
  instructionsI18n; // jsonb: es + steps_es + metadata
  final String? mediaId;
  final String? gifUrl;
  final String? videoUrl;
  final List<String> imageUrls;
  final String? createdByTrainer;
  final bool isPublic;
  final String source;
  final DateTime? createdAt;

  ExerciseModel({
    required this.id,
    required this.name,
    this.category,
    this.bodyPart,
    this.equipment = const [],
    this.target,
    this.muscleGroup,
    this.secondaryMuscles = const [],
    this.instructions,
    this.instructionsI18n = const {},
    this.mediaId,
    this.gifUrl,
    this.videoUrl,
    this.imageUrls = const [],
    this.createdByTrainer,
    this.isPublic = true,
    this.source = 'trainer',
    this.createdAt,
  });

  bool get isSeed => source == 'seed';
  bool get hasGif => gifUrl != null && gifUrl!.isNotEmpty;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasImages => imageUrls.isNotEmpty;

  /// Converts the relative paths produced by the source dataset into the
  /// public ExerciseDB URL. Absolute URLs are preserved as-is.
  String? get normalizedGifUrl => normalizeGifUrl(gifUrl, mediaId: mediaId);

  static String? normalizeGifUrl(String? rawUrl, {String? mediaId}) {
    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return value;
    }

    final path = value.replaceFirst(RegExp(r'^/+'), '');
    final fileName = path.split('/').last;
    final embeddedId = RegExp(
      r'-(?<id>[^./]+)\.gif$',
      caseSensitive: false,
    ).firstMatch(fileName)?.namedGroup('id');
    final resolvedId = (mediaId?.trim().isNotEmpty ?? false)
        ? mediaId!.trim()
        : embeddedId;

    if (resolvedId != null && resolvedId.isNotEmpty) {
      return 'https://static.exercisedb.dev/media/$resolvedId.gif';
    }

    return null;
  }

  /// Instrucciones localizadas al español.
  String get instructionsEs {
    final es = instructionsI18n['es'];
    if (es is String && es.isNotEmpty) return es;
    if (instructions != null && instructions!.isNotEmpty) return instructions!;
    return 'Sin instrucciones disponibles.';
  }

  /// Pasos en español.
  List<String> get stepsEs {
    final steps = instructionsI18n['steps_es'];
    if (steps is List && steps.isNotEmpty) return steps.cast<String>();
    return [instructionsEs];
  }

  factory ExerciseModel.fromMap(Map<String, dynamic> map) {
    List<String> asList(Object? v) =>
        (v is List) ? List<String>.from(v) : <String>[];

    // Safe string cast — on Flutter web JSArray/JSObject types from Supabase JS
    // can fail a bare `as String?` cast even if the column is conceptually text.
    String? asStr(Object? v) => v == null ? null : (v is String ? v : v.toString());

    // Parse instructions_i18n (always present, stores rich metadata for seed)
    Map<String, dynamic> i18n = {};
    final rawI18n = map['instructions_i18n'];
    if (rawI18n is Map) {
      i18n = Map<String, dynamic>.from(rawI18n);
    }

    return ExerciseModel(
      id: map['id']?.toString() ?? '',
      name: asStr(map['name']) ?? 'Ejercicio',
      category: asStr(map['category']) ?? asStr(i18n['category']),
      bodyPart:
          asStr(map['body_part']) ??
          asStr(map['category']) ??
          asStr(i18n['body_part']),
      equipment: asList(map['equipment'] ?? i18n['equipment']),
      target: asStr(map['target']) ?? asStr(i18n['target']),
      muscleGroup: asStr(map['muscle_group']),
      secondaryMuscles: asList(
        (map['secondary_muscles'] is List
                ? map['secondary_muscles']
                : null) ??
            (i18n['secondary_muscles'] is List
                ? i18n['secondary_muscles']
                : null),
      ),
      instructions: asStr(map['instructions']),
      instructionsI18n: i18n,
      mediaId: asStr(map['media_id']) ?? asStr(i18n['media_id']),
      gifUrl: asStr(map['gif_url']) ?? asStr(i18n['gif_url']),
      videoUrl: asStr(map['video_url']),
      imageUrls: asList(map['image_urls']),
      createdByTrainer: map['created_by_trainer']?.toString(),
      isPublic: (map['is_public'] as bool?) ?? true,
      source: asStr(map['source']) ?? 'trainer',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category,
    'body_part': bodyPart,
    'equipment': equipment,
    'target': target,
    'muscle_group': muscleGroup,
    'secondary_muscles': secondaryMuscles,
    'instructions': instructions,
    'instructions_i18n': instructionsI18n,
    'media_id': mediaId,
    'gif_url': gifUrl,
    'video_url': videoUrl,
    'image_urls': imageUrls,
    'created_by_trainer': createdByTrainer,
    'is_public': isPublic,
    'source': source,
    'created_at': createdAt?.toIso8601String(),
  };
}
