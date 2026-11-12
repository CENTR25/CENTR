import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/string_utils.dart';
import 'supabase_service.dart';

/// Allowed food categories (mirrors the CHECK constraint in create_foods.sql).
const kFoodCategories = <String>[
  'Proteínas',
  'Carbohidratos y cereales',
  'Frutas',
  'Verduras',
  'Grasas y aceites',
  'Frutos secos',
  'Lácteos',
  'Suplementos deportivos',
  'Preparados',
  'Productos argentinos',
  'Otros',
];

/// Hard caps for untrusted CSV input.
const kMaxImportRows = 2000;
const kMaxImportChars = 400000;
const kMaxFieldLength = 200;

String? _asStr(dynamic v) => v?.toString();

double _asNum(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

/// Duplicate key: name + state, case/accent-insensitive.
String foodKey(String? name, String? state) =>
    '${foldSearch((name ?? '').trim())}|${foldSearch((state ?? '').trim())}';

// ---------------------------------------------------------------------------
// CSV parsing (pure, unit-tested)
// ---------------------------------------------------------------------------

class FoodCsvRow {
  final int line;
  final Map<String, dynamic> data;
  final List<String> errors;
  bool duplicate;
  FoodCsvRow(this.line, this.data, this.errors, {this.duplicate = false});

  bool get isValid => errors.isEmpty;
  bool get willImport => isValid && !duplicate;
}

class FoodCsvResult {
  final List<FoodCsvRow> rows;
  final List<String> fileErrors;
  FoodCsvResult(this.rows, this.fileErrors);

  List<FoodCsvRow> get importable => rows.where((r) => r.willImport).toList();
  int get invalidCount => rows.where((r) => !r.isValid).length;
  int get duplicateCount =>
      rows.where((r) => r.isValid && r.duplicate).length;
}

/// Splits CSV [text] into records honoring quotes. Delimiter must be a single
/// character.
List<List<String>> splitCsv(String text, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  final d = delimiter.codeUnitAt(0);

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    if (row.any((f) => f.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (inQuotes) {
      if (c == 0x22) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x22) {
          field.writeCharCode(0x22);
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.writeCharCode(c);
      }
    } else if (c == 0x22) {
      inQuotes = true;
    } else if (c == d) {
      endField();
    } else if (c == 0x0A) {
      endRow();
    } else if (c == 0x0D) {
      // ignore (CRLF)
    } else {
      field.writeCharCode(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String detectDelimiter(String text) {
  final nl = text.indexOf('\n');
  final first = nl < 0 ? text : text.substring(0, nl);
  final semi = ';'.allMatches(first).length;
  final comma = ','.allMatches(first).length;
  final tab = '\t'.allMatches(first).length;
  if (tab > semi && tab > comma) return '\t';
  return semi > comma ? ';' : ',';
}

const _headerAliases = <String, String>{
  'name': 'name',
  'nombre': 'name',
  'alimento': 'name',
  'category': 'category',
  'categoria': 'category',
  'state': 'state',
  'estado': 'state',
  'calories': 'calories',
  'calorias': 'calories',
  'kcal': 'calories',
  'protein': 'protein',
  'proteina': 'protein',
  'proteinas': 'protein',
  'carbs': 'carbs',
  'carbohidratos': 'carbs',
  'hidratos': 'carbs',
  'fat': 'fat',
  'grasa': 'fat',
  'grasas': 'fat',
  'fiber': 'fiber',
  'fibra': 'fiber',
  'serving_size': 'serving_size',
  'porcion': 'serving_size',
  'serving_unit': 'serving_unit',
  'unidad': 'serving_unit',
  'source': 'source',
  'fuente': 'source',
  'verified': 'verified',
  'verificado': 'verified',
  'id': 'id',
};

/// Parses a numeric cell tolerating decimal comma. Returns null when invalid.
double? parseDecimal(String raw) {
  var s = raw.trim().replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;
  if (s.contains(',') && s.contains('.')) {
    // "1.234,5" -> 1234.5
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else {
    s = s.replaceAll(',', '.');
  }
  final v = double.tryParse(s);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

String _normalizeCategory(String raw) {
  final f = foldSearch(raw.trim());
  if (f.isEmpty) return 'Otros';
  for (final c in kFoodCategories) {
    if (foldSearch(c) == f) return c;
  }
  return 'Otros';
}

/// Parses pasted CSV text into validated rows. [existingKeys] holds foodKey()s
/// already in the database (scope the caller is importing into).
FoodCsvResult parseFoodsCsv(String text,
    {Set<String> existingKeys = const {}}) {
  final fileErrors = <String>[];
  if (text.trim().isEmpty) {
    return FoodCsvResult([], ['El texto está vacío.']);
  }
  if (text.length > kMaxImportChars) {
    return FoodCsvResult([], ['El texto es demasiado largo.']);
  }
  final clean = text.replaceFirst('﻿', '');
  final records = splitCsv(clean, detectDelimiter(clean));
  if (records.isEmpty) return FoodCsvResult([], ['No se encontraron filas.']);

  final header = records.first
      .map((h) => _headerAliases[foldSearch(h.trim())] ?? '')
      .toList();
  if (!header.contains('name')) {
    return FoodCsvResult([], ['Falta la columna "name" (nombre).']);
  }
  if (!header.contains('calories')) {
    return FoodCsvResult([], ['Falta la columna "calories" (calorías).']);
  }

  final body = records.skip(1).toList();
  if (body.length > kMaxImportRows) {
    fileErrors.add(
        'Máximo $kMaxImportRows filas por importación (se ignoran las restantes).');
  }

  final seen = <String>{};
  final out = <FoodCsvRow>[];
  for (var i = 0; i < body.length && i < kMaxImportRows; i++) {
    final rec = body[i];
    final line = i + 2;
    final cell = <String, String>{};
    for (var c = 0; c < header.length && c < rec.length; c++) {
      if (header[c].isNotEmpty && header[c] != 'id') {
        cell[header[c]] = rec[c].trim();
      }
    }
    final errors = <String>[];

    for (final e in cell.entries) {
      if (e.value.length > kMaxFieldLength) {
        errors.add('"${e.key}" supera $kMaxFieldLength caracteres');
      }
    }

    final name = cell['name'] ?? '';
    if (name.isEmpty) errors.add('Falta el nombre');
    final stateRaw = cell['state'] ?? '';

    double num0(String key, double max, {bool required = false}) {
      final raw = cell[key] ?? '';
      if (raw.isEmpty) {
        if (required) errors.add('Falta $key');
        return 0;
      }
      final v = parseDecimal(raw);
      if (v == null) {
        errors.add('$key no es un número');
        return 0;
      }
      if (v < 0 || v > max) {
        errors.add('$key fuera de rango (0–${max.toInt()})');
        return 0;
      }
      return v;
    }

    final calories = num0('calories', 2000, required: true);
    final protein = num0('protein', 200);
    final carbs = num0('carbs', 200);
    final fat = num0('fat', 200);
    final fiber = num0('fiber', 200);

    // serving: explicit serving_size, or "100g" / "100 ml" inside serving_unit.
    var servingSize = 100.0;
    var servingUnit = 'g';
    final unitRaw = cell['serving_unit'] ?? '';
    final sizeRaw = cell['serving_size'] ?? '';
    final m = RegExp(r'^(\d+(?:[.,]\d+)?)\s*([A-Za-zµ]+)$').firstMatch(unitRaw);
    if (m != null) {
      servingSize = parseDecimal(m.group(1)!) ?? 100;
      servingUnit = m.group(2)!.toLowerCase();
    } else if (unitRaw.isNotEmpty) {
      servingUnit = unitRaw.toLowerCase();
    }
    if (sizeRaw.isNotEmpty) {
      final v = parseDecimal(sizeRaw);
      if (v == null) {
        errors.add('serving_size no es un número');
      } else {
        servingSize = v;
      }
    }
    if (servingSize <= 0 || servingSize > 10000) {
      errors.add('serving_size fuera de rango (1–10000)');
      servingSize = 100;
    }
    if (servingUnit.length > 20) {
      errors.add('serving_unit demasiado largo');
      servingUnit = 'g';
    }

    final verifiedRaw = foldSearch(cell['verified'] ?? '');
    final verified = const ['true', '1', 'si', 'yes', 'x', 'verdadero']
        .contains(verifiedRaw);
    final source = (cell['source'] ?? '').isEmpty ? 'import' : cell['source']!;

    final key = foodKey(name, stateRaw);
    var dup = false;
    if (errors.isEmpty) {
      if (existingKeys.contains(key) || seen.contains(key)) dup = true;
      seen.add(key);
    }

    out.add(FoodCsvRow(
      line,
      {
        'name': name,
        'category': _normalizeCategory(cell['category'] ?? ''),
        'state': stateRaw.isEmpty ? null : stateRaw,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'serving_size': servingSize,
        'serving_unit': servingUnit,
        'source': source,
        'verified': verified,
      },
      errors,
      duplicate: dup,
    ));
  }
  return FoodCsvResult(out, fileErrors);
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class FoodAccess {
  final bool isAdmin;
  final String? trainerId;
  const FoodAccess({required this.isAdmin, required this.trainerId});

  bool get canWrite => isAdmin || trainerId != null;

  /// Owner id to stamp on new rows: null (global) for admin, trainer id else.
  String? get ownerId => isAdmin ? null : trainerId;

  bool canEdit(Map<String, dynamic> row) {
    final owner = row['created_by_trainer'];
    if (owner == null) return isAdmin;
    return owner == trainerId;
  }
}

class FoodService {
  final SupabaseClient _client;
  FoodService(this._client);

  static const _foodColumns =
      'id, name, category, state, calories, protein, carbs, fat, fiber, '
      'serving_size, serving_unit, source, verified, brand, barcode, '
      'created_by_trainer, created_at, updated_at';

  Future<FoodAccess> getAccess() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const FoodAccess(isAdmin: false, trainerId: null);
    final profile = await _client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    final trainer = await _client
        .from('trainers')
        .select('id')
        .eq('user_id', uid)
        .maybeSingle();
    return FoodAccess(
      isAdmin: _asStr(profile?['role']) == 'admin',
      trainerId: _asStr(trainer?['id']),
    );
  }

  /// All visible foods. A trainer's own row shadows a global with same key.
  Future<List<Map<String, dynamic>>> getFoods() async {
    final all = <Map<String, dynamic>>[];
    const page = 1000;
    for (var from = 0; from < 10000; from += page) {
      final res = await _client
          .from('foods')
          .select(_foodColumns)
          .order('name', ascending: true)
          .order('id', ascending: true)
          .range(from, from + page - 1);
      final list = List<Map<String, dynamic>>.from(res as List);
      all.addAll(list);
      if (list.length < page) break;
    }
    final owned = <String>{
      for (final f in all)
        if (f['created_by_trainer'] != null)
          foodKey(_asStr(f['name']), _asStr(f['state'])),
    };
    return all
        .where((f) =>
            f['created_by_trainer'] != null ||
            !owned.contains(foodKey(_asStr(f['name']), _asStr(f['state']))))
        .toList();
  }

  Map<String, dynamic> _foodPayload(Map<String, dynamic> d) => {
        'name': _asStr(d['name'])?.trim(),
        'category': d['category'],
        'state': (_asStr(d['state'])?.trim().isEmpty ?? true)
            ? null
            : _asStr(d['state'])!.trim(),
        'calories': _asNum(d['calories']),
        'protein': _asNum(d['protein']),
        'carbs': _asNum(d['carbs']),
        'fat': _asNum(d['fat']),
        'fiber': _asNum(d['fiber']),
        'serving_size': _asNum(d['serving_size']) <= 0
            ? 100
            : _asNum(d['serving_size']),
        'serving_unit': _asStr(d['serving_unit']) ?? 'g',
        'source': d['source'],
        'verified': d['verified'] == true,
      };

  /// Create (global for admin, own for trainer).
  Future<void> createFood(Map<String, dynamic> d, FoodAccess a) async {
    await _client
        .from('foods')
        .insert({..._foodPayload(d), 'created_by_trainer': a.ownerId});
  }

  /// Update in place when editable; otherwise copy-on-edit into own rows.
  Future<void> saveFood(
      Map<String, dynamic> existing, Map<String, dynamic> d, FoodAccess a) async {
    if (a.canEdit(existing)) {
      await _client
          .from('foods')
          .update({
            ..._foodPayload(d),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', existing['id'] as String);
    } else {
      await createFood({...d, 'source': 'custom'}, a);
    }
  }

  Future<void> deleteFood(String id) async {
    await _client.from('foods').delete().eq('id', id);
  }

  /// Batch insert in chunks. Returns (inserted, failed).
  Future<({int inserted, int failed})> importFoods(
      List<Map<String, dynamic>> rows, FoodAccess a) async {
    var inserted = 0;
    var failed = 0;
    const chunk = 100;
    for (var i = 0; i < rows.length; i += chunk) {
      final slice = rows
          .sublist(i, math.min(i + chunk, rows.length))
          .map((r) => {..._foodPayload(r), 'created_by_trainer': a.ownerId})
          .toList();
      try {
        await _client.from('foods').insert(slice);
        inserted += slice.length;
      } catch (_) {
        // Fallback row by row so one bad/duplicate row doesn't sink the chunk.
        for (final r in slice) {
          try {
            await _client.from('foods').insert(r);
            inserted++;
          } catch (_) {
            failed++;
          }
        }
      }
    }
    return (inserted: inserted, failed: failed);
  }

  // ── default_meals ("Comidas") ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMeals() async {
    final res = await _client
        .from('default_meals')
        .select()
        .order('meal_title', ascending: true);
    final all = List<Map<String, dynamic>>.from(res as List);
    final owned = <String>{
      for (final m in all)
        if (m['created_by_trainer'] != null)
          foldSearch(_asStr(m['meal_title']) ?? ''),
    };
    return all
        .where((m) =>
            m['created_by_trainer'] != null ||
            !owned.contains(foldSearch(_asStr(m['meal_title']) ?? '')))
        .toList();
  }

  Map<String, dynamic> _mealPayload(Map<String, dynamic> d) => {
        'meal_title': _asStr(d['meal_title'])?.trim(),
        'meal_description': _asStr(d['meal_description']),
        'calories': _asNum(d['calories']).round(),
        'macros': {
          'p': _asNum((d['macros'] as Map?)?['p']),
          'c': _asNum((d['macros'] as Map?)?['c']),
          'f': _asNum((d['macros'] as Map?)?['f']),
        },
        'image_url': d['image_url'],
        'time_of_day': d['time_of_day'],
      };

  Future<void> createMeal(Map<String, dynamic> d, FoodAccess a) async {
    await _client
        .from('default_meals')
        .insert({..._mealPayload(d), 'created_by_trainer': a.ownerId});
  }

  Future<void> saveMeal(
      Map<String, dynamic> existing, Map<String, dynamic> d, FoodAccess a) async {
    if (a.canEdit(existing)) {
      await _client
          .from('default_meals')
          .update(_mealPayload(d))
          .eq('id', existing['id'] as String);
    } else {
      await createMeal(d, a);
    }
  }

  Future<void> deleteMeal(String id) async {
    await _client.from('default_meals').delete().eq('id', id);
  }
}

final foodServiceProvider = Provider<FoodService>(
    (ref) => FoodService(ref.watch(supabaseClientProvider)));

final foodAccessProvider = FutureProvider<FoodAccess>(
    (ref) => ref.watch(foodServiceProvider).getAccess());

final foodsProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(foodServiceProvider).getFoods());

final mealsBankProvider = FutureProvider<List<Map<String, dynamic>>>(
    (ref) => ref.watch(foodServiceProvider).getMeals());
