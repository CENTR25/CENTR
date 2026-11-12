import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// One row of `muscle_groups`. `trainerId == null` means a global group
/// (managed by admin); otherwise it belongs to that trainer.
class MuscleGroup {
  final String id;
  final String name;
  final int displayOrder;
  final bool isActive;
  final String? trainerId;

  const MuscleGroup({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.isActive,
    required this.trainerId,
  });

  bool get isGlobal => trainerId == null;

  static String _str(Object? v) => v?.toString() ?? '';

  factory MuscleGroup.fromMap(Map<String, dynamic> m) => MuscleGroup(
        id: _str(m['id']),
        name: _str(m['name']),
        displayOrder: (m['display_order'] as num?)?.toInt() ?? 0,
        isActive: m['is_active'] != false,
        trainerId: m['created_by_trainer']?.toString(),
      );
}

/// Data access for the muscle-group catalog (ADR-007).
///
/// Exercises keep their text value in `muscle_group`/`category`; this table
/// only drives chips and pickers. Renames go through the
/// `rename_muscle_group` RPC so matching exercises are updated, not orphaned.
class MuscleGroupService {
  final SupabaseClient _client;
  MuscleGroupService(this._client);

  Future<List<MuscleGroup>> fetchAll() async {
    final rows = await _client
        .from('muscle_groups')
        .select(
            'id,name,display_order,is_active,created_by_trainer')
        .order('display_order', ascending: true)
        .order('name', ascending: true);
    return (rows as List)
        .map((r) => MuscleGroup.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> add(String name, {String? trainerId, required int order}) async {
    await _client.from('muscle_groups').insert({
      'name': name.trim(),
      'display_order': order,
      'created_by_trainer': trainerId,
    });
  }

  Future<void> rename(String id, String newName) async {
    await _client.rpc('rename_muscle_group',
        params: {'p_id': id, 'p_new_name': newName.trim()});
  }

  Future<void> setActive(String id, bool active) async {
    await _client.from('muscle_groups').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Persists the given order (index becomes display_order).
  Future<void> reorder(List<MuscleGroup> ordered) async {
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].displayOrder == i + 1) continue;
      await _client
          .from('muscle_groups')
          .update({'display_order': i + 1}).eq('id', ordered[i].id);
    }
  }

  /// Distinct values already used by exercises (fallback when the table is
  /// empty or unreadable).
  Future<List<String>> distinctExerciseGroups() async {
    final rows = await _client
        .from('exercises')
        .select('muscle_group')
        .not('muscle_group', 'is', null);
    final seen = <String>{};
    final out = <String>[];
    for (final r in rows as List) {
      final g = (r as Map)['muscle_group']?.toString().trim() ?? '';
      if (g.isNotEmpty && seen.add(g.toLowerCase())) out.add(g);
    }
    out.sort();
    return out;
  }
}

final muscleGroupServiceProvider = Provider<MuscleGroupService>(
    (ref) => MuscleGroupService(ref.watch(supabaseClientProvider)));

/// Full rows visible to the current user (admin sees everything).
final muscleGroupRowsProvider = FutureProvider<List<MuscleGroup>>((ref) {
  return ref.watch(muscleGroupServiceProvider).fetchAll();
});

/// Active group names, deduped case-insensitively, in display order.
/// Falls back to distinct exercise values if the table is empty/unavailable.
final muscleGroupNamesProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(muscleGroupServiceProvider);
  try {
    final rows = await ref.watch(muscleGroupRowsProvider.future);
    final seen = <String>{};
    final names = <String>[];
    for (final g in rows.where((g) => g.isActive)) {
      if (seen.add(g.name.toLowerCase())) names.add(g.name);
    }
    if (names.isNotEmpty) return names;
  } catch (_) {}
  return service.distinctExerciseGroups();
});
