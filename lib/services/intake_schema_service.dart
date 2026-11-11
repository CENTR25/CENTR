import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/intake_schema.dart';
import 'supabase_service.dart';

/// Riverpod provider for the service.
final intakeSchemaServiceProvider = Provider<IntakeSchemaService>(
  (ref) => IntakeSchemaService(ref.watch(supabaseClientProvider)),
);

/// Manages the `intake_form_schemas` table.
///
/// Resolution chain for student intake:
///   1. Trainer-specific row (if exists)
///   2. Admin-global row  (owner_type = 'admin', trainer_id IS NULL)
///   3. Hardcoded [kIntakeSectionsAsDto] fallback
class IntakeSchemaService {
  final SupabaseClient _client;

  IntakeSchemaService(this._client);

  // -------------------------------------------------------------------------
  // Student: resolve which schema to render
  // -------------------------------------------------------------------------

  /// Returns the schema the student should see: trainer override → admin global
  /// → hardcoded fallback.
  Future<List<IntakeSectionDto>> getSchemaForStudent(
      String? trainerId) async {
    try {
      // 1. Try trainer-specific row.
      if (trainerId != null && trainerId.isNotEmpty) {
        final trainerRow = await _client
            .from('intake_form_schemas')
            .select('sections')
            .eq('owner_type', 'trainer')
            .eq('trainer_id', trainerId)
            .maybeSingle();

        if (trainerRow != null) {
          return _parseSections(trainerRow['sections']);
        }
      }

      // 2. Try admin-global row.
      final adminRow = await _client
          .from('intake_form_schemas')
          .select('sections')
          .eq('owner_type', 'admin')
          .isFilter('trainer_id', null)
          .maybeSingle();

      if (adminRow != null) {
        return _parseSections(adminRow['sections']);
      }
    } catch (_) {
      // Fall through to hardcoded default on any DB error.
    }

    // 3. Hardcoded fallback.
    return kIntakeSectionsAsDto();
  }

  // -------------------------------------------------------------------------
  // Admin
  // -------------------------------------------------------------------------

  /// Returns the admin-global schema, or the hardcoded default if not set.
  Future<List<IntakeSectionDto>> getAdminSchema() async {
    final row = await _client
        .from('intake_form_schemas')
        .select('sections')
        .eq('owner_type', 'admin')
        .isFilter('trainer_id', null)
        .maybeSingle();

    if (row != null) return _parseSections(row['sections']);
    return kIntakeSectionsAsDto();
  }

  /// Saves the admin-global schema row. Can't use upsert(onConflict) here
  /// because the admin row has trainer_id IS NULL and Postgres treats NULLs as
  /// distinct — a conflict on (owner_type, trainer_id) would never match, so an
  /// upsert would keep inserting duplicate admin rows. Update-or-insert instead.
  Future<void> saveAdminSchema(List<IntakeSectionDto> sections) async {
    final payload = {
      'sections': sections.map((s) => s.toMap()).toList(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    final existing = await _client
        .from('intake_form_schemas')
        .select('id')
        .eq('owner_type', 'admin')
        .isFilter('trainer_id', null)
        .maybeSingle();
    if (existing != null) {
      await _client
          .from('intake_form_schemas')
          .update(payload)
          .eq('id', existing['id']);
    } else {
      await _client.from('intake_form_schemas').insert({
        'owner_type': 'admin',
        'trainer_id': null,
        ...payload,
      });
    }
  }

  /// Returns true if any athlete has submitted an intake response (globally).
  /// Used to determine whether to lock all existing field keys in the admin
  /// editor.
  Future<bool> anyAthleteHasSubmitted() async {
    final row = await _client
        .from('athlete_intake')
        .select('athlete_id')
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  // -------------------------------------------------------------------------
  // Trainer
  // -------------------------------------------------------------------------

  /// Returns the trainer's own schema (or the admin-global fallback if the
  /// trainer has not customized yet). Call this when opening the trainer's
  /// read-only intake view.
  Future<List<IntakeSectionDto>> getMySchema(String trainerId) async {
    // Try trainer-specific first.
    final trainerRow = await _client
        .from('intake_form_schemas')
        .select('sections')
        .eq('owner_type', 'trainer')
        .eq('trainer_id', trainerId)
        .maybeSingle();

    if (trainerRow != null) return _parseSections(trainerRow['sections']);

    // Fall back to admin-global.
    final adminRow = await _client
        .from('intake_form_schemas')
        .select('sections')
        .eq('owner_type', 'admin')
        .isFilter('trainer_id', null)
        .maybeSingle();

    if (adminRow != null) return _parseSections(adminRow['sections']);

    return kIntakeSectionsAsDto();
  }

  /// Upserts the trainer's own schema row.
  Future<void> saveMySchema(
      String trainerId, List<IntakeSectionDto> sections) async {
    await _client.from('intake_form_schemas').upsert(
      {
        'owner_type': 'trainer',
        'trainer_id': trainerId,
        'sections': sections.map((s) => s.toMap()).toList(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'owner_type,trainer_id',
    );
  }

  /// Resets the trainer's schema to the CURRENT admin-global schema (live
  /// fetch — reflects whatever the admin has at this moment, not a stale
  /// snapshot). Saves the result as the trainer's own row (overwrite).
  Future<void> resetMySchemaToAdminDefault(String trainerId) async {
    final adminSections = await getAdminSchema();
    await saveMySchema(trainerId, adminSections);
  }

  /// Returns true if any athlete trained under [trainerId] has submitted an
  /// intake response. Used to decide whether to lock existing field keys in
  /// the trainer editor.
  Future<bool> trainerAthleteHasSubmitted(String trainerId) async {
    // Fetch athlete IDs for this trainer, then check if any intake exists.
    final athletes = await _client
        .from('athletes')
        .select('id')
        .eq('trainer_id', trainerId);
    if (athletes.isEmpty) return false;
    final ids = (athletes as List).map((a) => a['id'] as String).toList();
    final row = await _client
        .from('athlete_intake')
        .select('athlete_id')
        .inFilter('athlete_id', ids)
        .limit(1)
        .maybeSingle();
    return row != null;
  }

  // -------------------------------------------------------------------------
  // Parsing helper
  // -------------------------------------------------------------------------

  List<IntakeSectionDto> _parseSections(dynamic raw) {
    if (raw == null) return kIntakeSectionsAsDto();
    final list = raw as List;
    return list
        .map((item) =>
            IntakeSectionDto.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }
}
