import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/first_step_config.dart';
import 'supabase_service.dart';

/// Global key/value app settings (admin-managed). Currently backs the
/// `recipes_enabled` master switch for the student Recetario card.
class AppSettingsService {
  final SupabaseClient _client;

  AppSettingsService(this._client);

  /// Read a boolean flag; returns [fallback] when the row is missing or the
  /// read fails (e.g. offline). Never throws.
  Future<bool> getBool(String key, {bool fallback = false}) async {
    try {
      final row = await _client
          .from('app_settings')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      final value = row?['value'];
      return value is bool ? value : fallback;
    } catch (e) {
      debugPrint('Error reading app setting "$key": $e');
      return fallback;
    }
  }

  /// Read the trainer "Primeros pasos" config (defaults when unset/offline).
  Future<List<FirstStepConfig>> getFirstSteps() async {
    try {
      final row = await _client
          .from('app_settings')
          .select('value')
          .eq('key', 'trainer_first_steps')
          .maybeSingle();
      return FirstStepConfig.merge(row?['value']);
    } catch (e) {
      debugPrint('Error reading first steps config: $e');
      return FirstStepConfig.defaults;
    }
  }

  /// Save the trainer "Primeros pasos" config (admin only — enforced by RLS).
  Future<void> setFirstSteps(List<FirstStepConfig> steps) async {
    await _client.from('app_settings').upsert({
      'key': 'trainer_first_steps',
      'value': [for (final s in steps) s.toJson()],
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Upsert a boolean flag (admin only — enforced by RLS).
  Future<void> setBool(String key, bool value) async {
    await _client.from('app_settings').upsert({
      'key': key,
      'value': value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}

final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AppSettingsService(client);
});

/// Whether the student Recetario card is enabled (admin master switch).
/// Defaults to false so the half-built recetario stays hidden until ready.
final recipesEnabledProvider = FutureProvider<bool>((ref) async {
  return ref.read(appSettingsServiceProvider).getBool('recipes_enabled');
});

/// Admin-configured "Primeros pasos" checklist (labels, visibility, order).
final firstStepsConfigProvider =
    FutureProvider<List<FirstStepConfig>>((ref) async {
  return ref.read(appSettingsServiceProvider).getFirstSteps();
});
