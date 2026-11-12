import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

String _s(dynamic v) => v is String ? v : (v?.toString() ?? '');
String? _sn(dynamic v) {
  final t = v == null ? '' : _s(v).trim();
  return t.isEmpty ? null : t;
}

/// One quick-add catalog entry. category: 'natural' | 'quimica'.
class SupplementCatalogItem {
  final String id;
  final String name;
  final String category;
  final String? defaultDose;
  final String? defaultUnit;
  final List<String> defaultTiming;
  final String? note;
  final bool isActive;
  final int displayOrder;
  final String? createdByTrainer; // null = global

  const SupplementCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    this.defaultDose,
    this.defaultUnit,
    this.defaultTiming = const [],
    this.note,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdByTrainer,
  });

  bool get isGlobal => createdByTrainer == null;

  factory SupplementCatalogItem.fromMap(Map<String, dynamic> m) {
    final t = m['default_timing'];
    final order = m['display_order'];
    return SupplementCatalogItem(
      id: _s(m['id']),
      name: _s(m['name']),
      category: _s(m['category']) == 'quimica' ? 'quimica' : 'natural',
      defaultDose: _sn(m['default_dose']),
      defaultUnit: _sn(m['default_unit']),
      defaultTiming: t is List ? t.map(_s).toList() : const [],
      note: _sn(m['note']),
      isActive: m['is_active'] != false,
      displayOrder: order is num ? order.toInt() : 0,
      createdByTrainer: _sn(m['created_by_trainer']),
    );
  }
}

/// Last-resort quick-add list when the catalog fetch fails or is empty.
const fallbackSupplementCatalog = <SupplementCatalogItem>[
  SupplementCatalogItem(id: '', name: 'Omega 3', category: 'natural'),
  SupplementCatalogItem(id: '', name: 'Multivitamínico', category: 'natural'),
  SupplementCatalogItem(id: '', name: 'Cafeína', category: 'natural'),
];

/// Result of parsing a pasted list.
class ParsedSupplementLine {
  final String name;
  final String? dose;
  final String? unit;
  const ParsedSupplementLine(this.name, this.dose, this.unit);
}

/// Parses "name;dose;unit" (also accepts "," or tab as separator when no ";"),
/// one entry per line. Blank lines skipped, duplicate names (case-insens.) merged.
List<ParsedSupplementLine> parseSupplementLines(String raw) {
  final seen = <String>{};
  final out = <ParsedSupplementLine>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final t = line.trim();
    if (t.isEmpty) continue;
    final sep = t.contains(';') ? ';' : (t.contains('\t') ? '\t' : ',');
    final parts = t.split(sep).map((e) => e.trim()).toList();
    final name = parts[0];
    if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
    out.add(ParsedSupplementLine(
      name,
      parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null,
      parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
    ));
  }
  return out;
}

class SupplementCatalogService {
  final SupabaseClient _client;
  SupplementCatalogService(this._client);

  static const _cols =
      'id, name, category, default_dose, default_unit, default_timing, note, '
      'is_active, display_order, created_by_trainer';

  /// Active entries visible to the current user (RLS: globals + own).
  /// Never throws: falls back to the hardcoded list.
  Future<List<SupplementCatalogItem>> getActive() async {
    try {
      final res = await _client
          .from('supplement_catalog')
          .select(_cols)
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('name', ascending: true);
      final items = (res as List)
          .map((e) => SupplementCatalogItem.fromMap(
              Map<String, dynamic>.from(e as Map)))
          .toList();
      return items.isEmpty ? fallbackSupplementCatalog : items;
    } catch (e) {
      debugPrint('supplement_catalog fetch failed: $e');
      return fallbackSupplementCatalog;
    }
  }

  /// All entries visible to the current user, including inactive (management).
  Future<List<SupplementCatalogItem>> getAll() async {
    final res = await _client
        .from('supplement_catalog')
        .select(_cols)
        .order('display_order', ascending: true)
        .order('name', ascending: true);
    return (res as List)
        .map((e) =>
            SupplementCatalogItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<String?> _myTrainerId() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final r = await _client
        .from('trainers')
        .select('id')
        .eq('user_id', uid)
        .maybeSingle();
    return _sn(r?['id']);
  }

  /// [asAdmin] true => global entry (created_by_trainer null); false => owned
  /// by the current trainer.
  Future<void> save({
    String? id,
    required String name,
    required String category,
    String? dose,
    String? unit,
    List<String> timing = const [],
    String? note,
    bool isActive = true,
    required bool asAdmin,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'category': category,
      'default_dose': _sn(dose),
      'default_unit': _sn(unit),
      'default_timing': timing,
      'note': _sn(note),
      'is_active': isActive,
    };
    if (id != null) {
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _client.from('supplement_catalog').update(data).eq('id', id);
    } else {
      if (!asAdmin) {
        final tid = await _myTrainerId();
        if (tid == null) throw Exception('No se encontró el entrenador');
        data['created_by_trainer'] = tid;
      }
      await _client.from('supplement_catalog').insert(data);
    }
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('supplement_catalog').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('supplement_catalog').delete().eq('id', id);
  }

  /// Bulk import; skips names that already exist (same scope). Returns count added.
  Future<int> bulkImport(
    List<ParsedSupplementLine> lines, {
    required String category,
    required bool asAdmin,
  }) async {
    final existing = (await getAll())
        .where((e) => asAdmin ? e.isGlobal : !e.isGlobal)
        .map((e) => e.name.toLowerCase())
        .toSet();
    final fresh =
        lines.where((l) => !existing.contains(l.name.toLowerCase())).toList();
    if (fresh.isEmpty) return 0;
    String? tid;
    if (!asAdmin) {
      tid = await _myTrainerId();
      if (tid == null) throw Exception('No se encontró el entrenador');
    }
    await _client.from('supplement_catalog').insert([
      for (final l in fresh)
        {
          'name': l.name,
          'category': category,
          'default_dose': l.dose,
          'default_unit': l.unit,
          if (tid != null) 'created_by_trainer': tid,
        }
    ]);
    return fresh.length;
  }
}

final supplementCatalogServiceProvider =
    Provider<SupplementCatalogService>((ref) {
  return SupplementCatalogService(ref.watch(supabaseClientProvider));
});

/// Active quick-add entries (never errors; falls back to hardcoded).
final activeSupplementCatalogProvider =
    FutureProvider<List<SupplementCatalogItem>>((ref) {
  return ref.read(supplementCatalogServiceProvider).getActive();
});

/// All entries for management screens.
final allSupplementCatalogProvider =
    FutureProvider<List<SupplementCatalogItem>>((ref) {
  return ref.read(supplementCatalogServiceProvider).getAll();
});
