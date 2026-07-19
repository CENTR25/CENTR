import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise_model.dart';
import 'supabase_service.dart';

/// Resolves exercise GIFs from the dataset CDN or the exercise-media bucket.
class ExerciseMediaService {
  static const String bucketName = 'exercise-media';

  final SupabaseClient _client;

  ExerciseMediaService(this._client);

  String? resolveGifUrl(String? rawUrl, {String? mediaId}) {
    final datasetUrl = ExerciseModel.normalizeGifUrl(rawUrl, mediaId: mediaId);
    if (datasetUrl != null) return datasetUrl;

    final value = rawUrl?.trim();
    if (value == null || value.isEmpty) return null;

    final path = value.replaceFirst(RegExp(r'^/+'), '');
    try {
      return _client.storage.from(bucketName).getPublicUrl(path);
    } catch (_) {
      return null;
    }
  }
}

final exerciseMediaServiceProvider = Provider<ExerciseMediaService>((ref) {
  return ExerciseMediaService(ref.watch(supabaseClientProvider));
});
