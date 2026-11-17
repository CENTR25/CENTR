import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/string_utils.dart';
import 'food_service.dart' show splitCsv, detectDelimiter;

// ---------------------------------------------------------------------------
// Exercise CSV import + image-bank matching (pure parts are unit-tested in
// test/exercise_import_test.dart) and the small DB helpers shared by the admin
// (global catalog) and trainer (own exercises) screens.
// ---------------------------------------------------------------------------

/// Hard caps for untrusted CSV input.
const kMaxExerciseImportRows = 1000;
const kMaxExerciseImportChars = 1000000;
const kMaxExerciseFieldLength = 200;
const kMaxExerciseInstructionsLength = 4000;
const kMaxExerciseUrlLength = 1000;
const kMaxExerciseListItems = 20;

/// Header line shown in "Ver formato" / copied by "Copiar plantilla".
const kExerciseCsvHeader =
    'nombre;grupo_muscular;musculos_secundarios;categoria;equipamiento;'
    'instrucciones;video_url;gif_url;imagen;imagen_archivo';

const kExerciseCsvTemplate = '$kExerciseCsvHeader\n'
    'Sentadilla búlgara;Piernas;Glúteos|Isquiotibiales;Fuerza;'
    'Mancuernas|Banco;Pie trasero apoyado en el banco, bajar controlado.;'
    ';;;sentadilla_bulgara.jpg';

/// Normalized key for matching names: accent/case-insensitive, `_`/`-` as
/// spaces, collapsed whitespace.
String exerciseNameKey(String? name) => foldSearch(name ?? '')
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Normalized key for an image file name: drops any folder and the extension,
/// then applies [exerciseNameKey]. "fotos/Press_Banca-Plano.JPG" -> "press banca plano".
String imageFileKey(String fileName) {
  var base = fileName.split(RegExp(r'[\\/]')).last.trim();
  final dot = base.lastIndexOf('.');
  if (dot > 0 && RegExp(r'^[A-Za-z0-9]{2,5}$').hasMatch(base.substring(dot + 1))) {
    base = base.substring(0, dot);
  }
  return exerciseNameKey(base);
}

/// Lower-case extension of [fileName] ('' when none).
String fileExtension(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

const kImageExtensions = {'jpg', 'jpeg', 'png', 'webp', 'gif'};

bool isHttpUrl(String s) {
  final u = Uri.tryParse(s.trim());
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.isNotEmpty;
}

class ExerciseCsvRow {
  final int line;

  /// Payload-ready columns (name, muscle_group, secondary_muscles, category,
  /// equipment, instructions, video_url, gif_url, image_urls).
  final Map<String, dynamic> data;
  final List<String> errors;

  /// Optional `imagen_archivo` value, normalized with [imageFileKey].
  final String? imageFileKey;
  bool duplicate;
  ExerciseCsvRow(this.line, this.data, this.errors,
      {this.imageFileKey, this.duplicate = false});

  bool get isValid => errors.isEmpty;
  bool get willImport => isValid && !duplicate;
}

class ExerciseCsvResult {
  final List<ExerciseCsvRow> rows;
  final List<String> fileErrors;
  ExerciseCsvResult(this.rows, this.fileErrors);

  List<ExerciseCsvRow> get importable =>
      rows.where((r) => r.willImport).toList();
  int get invalidCount => rows.where((r) => !r.isValid).length;
  int get duplicateCount =>
      rows.where((r) => r.isValid && r.duplicate).length;
}

const _headerAliases = <String, String>{
  'name': 'name',
  'nombre': 'name',
  'ejercicio': 'name',
  'muscle_group': 'muscle_group',
  'grupo_muscular': 'muscle_group',
  'grupo': 'muscle_group',
  'musculo': 'muscle_group',
  'musculo_principal': 'muscle_group',
  'secondary_muscles': 'secondary_muscles',
  'musculos_secundarios': 'secondary_muscles',
  'secundarios': 'secondary_muscles',
  'category': 'category',
  'categoria': 'category',
  'equipment': 'equipment',
  'equipamiento': 'equipment',
  'implemento': 'equipment',
  'implementos': 'equipment',
  'instructions': 'instructions',
  'instrucciones': 'instructions',
  'descripcion': 'instructions',
  'video_url': 'video_url',
  'video': 'video_url',
  'gif_url': 'gif_url',
  'gif': 'gif_url',
  'image_url': 'image_urls',
  'image_urls': 'image_urls',
  'imagen': 'image_urls',
  'imagenes': 'image_urls',
  'imagen_url': 'image_urls',
  'foto': 'image_urls',
  'imagen_archivo': 'image_file',
  'archivo_imagen': 'image_file',
  'image_file': 'image_file',
  'archivo': 'image_file',
};

String _headerKey(String raw) => foldSearch(raw.trim())
    .replaceAll(RegExp(r'[\s\-]+'), '_')
    .replaceAll(RegExp(r'[^a-z0-9_]'), '');

List<String> _splitList(String raw) => raw
    .split('|')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// Parses pasted CSV text into validated exercise rows. [existingNameKeys]
/// holds [exerciseNameKey]s of VISIBLE exercises in the target scope — hidden
/// rows must not be passed, so a re-import can replace hidden ones.
ExerciseCsvResult parseExercisesCsv(String text,
    {Set<String> existingNameKeys = const {}}) {
  if (text.trim().isEmpty) {
    return ExerciseCsvResult([], ['El texto está vacío.']);
  }
  if (text.length > kMaxExerciseImportChars) {
    return ExerciseCsvResult([], ['El texto es demasiado largo.']);
  }
  final clean = text.replaceFirst('﻿', '');
  final records = splitCsv(clean, detectDelimiter(clean));
  if (records.isEmpty) {
    return ExerciseCsvResult([], ['No se encontraron filas.']);
  }

  final header =
      records.first.map((h) => _headerAliases[_headerKey(h)] ?? '').toList();
  if (!header.contains('name')) {
    return ExerciseCsvResult([], ['Falta la columna "nombre".']);
  }
  if (!header.contains('muscle_group')) {
    return ExerciseCsvResult([], ['Falta la columna "grupo_muscular".']);
  }

  final fileErrors = <String>[];
  final body = records.skip(1).toList();
  if (body.length > kMaxExerciseImportRows) {
    fileErrors.add('Máximo $kMaxExerciseImportRows filas por importación '
        '(se ignoran las restantes).');
  }

  final seen = <String>{};
  final out = <ExerciseCsvRow>[];
  for (var i = 0; i < body.length && i < kMaxExerciseImportRows; i++) {
    final rec = body[i];
    final cell = <String, String>{};
    for (var c = 0; c < header.length && c < rec.length; c++) {
      if (header[c].isEmpty) continue;
      final v = rec[c].trim();
      // First non-empty wins when two columns alias to the same key.
      if ((cell[header[c]] ?? '').isEmpty) cell[header[c]] = v;
    }
    final errors = <String>[];

    for (final e in cell.entries) {
      final max = switch (e.key) {
        'instructions' => kMaxExerciseInstructionsLength,
        'video_url' || 'gif_url' || 'image_urls' => kMaxExerciseUrlLength * 5,
        _ => kMaxExerciseFieldLength,
      };
      if (e.value.length > max) errors.add('"${e.key}" supera $max caracteres');
    }

    final name = (cell['name'] ?? '').replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) errors.add('Falta el nombre');
    final muscle = cell['muscle_group'] ?? '';
    if (muscle.isEmpty) errors.add('Falta el grupo muscular');

    List<String> list(String key) {
      final l = _splitList(cell[key] ?? '');
      if (l.length > kMaxExerciseListItems) {
        errors.add('$key: máximo $kMaxExerciseListItems valores');
        return l.take(kMaxExerciseListItems).toList();
      }
      return l;
    }

    String? url(String key) {
      final raw = cell[key] ?? '';
      if (raw.isEmpty) return null;
      if (raw.length > kMaxExerciseUrlLength || !isHttpUrl(raw)) {
        errors.add('$key no es un link http(s) válido');
        return null;
      }
      return raw;
    }

    final images = list('image_urls');
    for (final u in images) {
      if (u.length > kMaxExerciseUrlLength || !isHttpUrl(u)) {
        errors.add('imagen "$u" no es un link http(s) válido');
      }
    }

    final fileRaw = cell['image_file'] ?? '';
    final key = exerciseNameKey(name);
    var dup = false;
    if (errors.isEmpty) {
      if (existingNameKeys.contains(key) || seen.contains(key)) dup = true;
      seen.add(key);
    }

    final instructions = cell['instructions'] ?? '';
    final category = cell['category'] ?? '';
    out.add(ExerciseCsvRow(
      i + 2,
      {
        'name': name,
        'muscle_group': muscle,
        'secondary_muscles': list('secondary_muscles'),
        'category': category.isEmpty ? null : category,
        'equipment': list('equipment'),
        'instructions': instructions.isEmpty ? null : instructions,
        'video_url': url('video_url'),
        'gif_url': url('gif_url'),
        'image_urls': images,
      },
      errors,
      imageFileKey: fileRaw.isEmpty ? null : imageFileKey(fileRaw),
      duplicate: dup,
    ));
  }
  return ExerciseCsvResult(out, fileErrors);
}

/// Matches image files to exercises by file name. Returns, per file name, the
/// matched exercise id or null. [exercises] needs `id` and `name`; optional
/// [fileKeyToName] maps a CSV `imagen_archivo` key to an exercise name key.
Map<String, String?> matchImagesToExercises(
  Iterable<String> fileNames,
  Iterable<Map<String, dynamic>> exercises, {
  Map<String, String> fileKeyToName = const {},
}) {
  final byName = <String, String>{};
  for (final e in exercises) {
    final id = e['id']?.toString();
    final k = exerciseNameKey(e['name']?.toString());
    if (id != null && k.isNotEmpty) byName.putIfAbsent(k, () => id);
  }
  String? match(String f) {
    final fk = imageFileKey(f);
    final viaCsv = fileKeyToName[fk];
    return (viaCsv != null ? byName[viaCsv] : null) ?? byName[fk];
  }

  return {for (final f in fileNames) f: match(f)};
}

// ---------------------------------------------------------------------------
// DB helpers (shared by admin + trainer)
// ---------------------------------------------------------------------------

typedef DeleteOrHideResult = ({int deleted, int hidden, int skipped});

/// Deletes exercises that no routine uses and HIDES the ones that are used
/// (routine_exercises cascades on delete). Ownership is enforced server-side
/// by the `delete_or_hide_exercises` RPC (admin: globals, trainer: own rows).
Future<DeleteOrHideResult> deleteOrHideExercises(
    SupabaseClient client, List<String> ids) async {
  var deleted = 0, hidden = 0, skipped = 0;
  const chunk = 500;
  for (var i = 0; i < ids.length; i += chunk) {
    final res = await client.rpc('delete_or_hide_exercises', params: {
      'p_ids': ids.sublist(i, math.min(i + chunk, ids.length)),
    });
    final m = res is Map ? res : const {};
    deleted += (m['deleted'] as num?)?.toInt() ?? 0;
    hidden += (m['hidden'] as num?)?.toInt() ?? 0;
    skipped += (m['skipped'] as num?)?.toInt() ?? 0;
  }
  return (deleted: deleted, hidden: hidden, skipped: skipped);
}

/// Chunked insert with row-by-row fallback. [rows] must already carry the
/// ownership columns. Returns the inserted rows (`id`, `name`) and the
/// number of failures.
Future<({List<Map<String, dynamic>> inserted, int failed})>
    insertExercisesChunked(
        SupabaseClient client, List<Map<String, dynamic>> rows) async {
  final inserted = <Map<String, dynamic>>[];
  var failed = 0;
  const chunk = 100;
  for (var i = 0; i < rows.length; i += chunk) {
    final slice = rows.sublist(i, math.min(i + chunk, rows.length));
    try {
      final res = await client.from('exercises').insert(slice).select('id, name');
      inserted.addAll(List<Map<String, dynamic>>.from(res as List));
    } catch (_) {
      for (final r in slice) {
        try {
          final res =
              await client.from('exercises').insert(r).select('id, name').single();
          inserted.add(res);
        } catch (_) {
          failed++;
        }
      }
    }
  }
  return (inserted: inserted, failed: failed);
}

/// Insert payload for a parsed CSV row. [ownerTrainerId] null = global
/// (admin catalog), otherwise the trainer's own private exercise.
Map<String, dynamic> exerciseInsertPayload(Map<String, dynamic> d,
    {String? ownerTrainerId}) {
  final isGlobal = ownerTrainerId == null;
  List<String> strs(dynamic v) =>
      v is List ? v.map((e) => e.toString()).toList() : const <String>[];
  return {
    'name': d['name'],
    'muscle_group': d['muscle_group'],
    'secondary_muscles': strs(d['secondary_muscles']),
    'category': d['category'],
    'equipment': strs(d['equipment']),
    'instructions': d['instructions'],
    'video_url': d['video_url'],
    'gif_url': d['gif_url'],
    'image_urls': strs(d['image_urls']),
    'created_by_trainer': ownerTrainerId,
    'is_public': isGlobal,
    'is_hidden': false,
    'source': isGlobal ? 'global' : 'trainer',
  };
}

/// Replace an exercise's photos. RLS limits it to admin (globals) / owner;
/// returns false when no row was updated (not allowed / gone).
Future<bool> setExerciseImageUrls(
    SupabaseClient client, String exerciseId, List<String> urls) async {
  final res = await client
      .from('exercises')
      .update({'image_urls': urls})
      .eq('id', exerciseId)
      .select('id');
  return (res as List).isNotEmpty;
}
