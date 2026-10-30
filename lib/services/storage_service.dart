import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for handling file uploads to Supabase Storage
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  static const String _bucketName = 'exercise-media';

  /// Upload exercise video from raw bytes (web-safe). Keeps the gallery file's
  /// extension so iOS .mov picks keep a playable content type.
  /// Returns the public URL of the uploaded video.
  Future<String> uploadExerciseVideoBytes(
    Uint8List bytes,
    String extension,
    String exerciseId,
  ) async {
    final path = 'videos/$exerciseId.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getVideoContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  /// Upload one exercise image from raw bytes (web-safe). Timestamped name so
  /// newly added images never overwrite ones the exercise already has.
  /// Returns the public URL of the uploaded image.
  Future<String> uploadExerciseImageBytes(
    Uint8List bytes,
    String extension,
    String exerciseId,
    int index,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'images/${exerciseId}_${timestamp}_$index.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  /// Delete file from storage
  Future<void> deleteFile(String path) async {
    await _client.storage.from(_bucketName).remove([path]);
  }

  /// Delete all media for an exercise
  Future<void> deleteExerciseMedia(String exerciseId) async {
    try {
      // List all files for this exercise
      final videoPath = 'videos/$exerciseId.mp4';
      final imagePaths = await _listExerciseImages(exerciseId);

      // Delete video if exists
      try {
        await deleteFile(videoPath);
      } catch (e) {
        // Video might not exist, continue
      }

      // Delete all images
      if (imagePaths.isNotEmpty) {
        await _client.storage.from(_bucketName).remove(imagePaths);
      }
    } catch (e) {
      debugPrint('Error deleting exercise media: $e');
    }
  }

  /// List all image paths for an exercise
  Future<List<String>> _listExerciseImages(String exerciseId) async {
    try {
      final files = await _client.storage
          .from(_bucketName)
          .list(path: 'images', searchOptions: const SearchOptions(
            search: '',
          ));

      return files
          .where((file) => file.name.startsWith(exerciseId))
          .map((file) => 'images/${file.name}')
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get video content type from file extension
  String _getVideoContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4v':
        return 'video/x-m4v';
      default:
        return 'video/mp4';
    }
  }

  /// Get content type from file extension
  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Upload meal plan item image
  /// Returns the public URL of the uploaded image
  Future<String> uploadMealImage(File file, String mealPlanId) async {
    final extension = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${mealPlanId}_$timestamp.$extension';
    final path = 'meals/$fileName';

    await _client.storage.from(_bucketName).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return url;
  }
  Future<String> uploadRoutineImage(File file, String userId) async {
    final extension = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_$timestamp.$extension';
    final path = 'routines/$fileName';

    await _client.storage.from(_bucketName).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return url;
  }

  /// Upload meal plan cover image
  /// Returns the public URL of the uploaded image
  Future<String> uploadMealPlanCover(File file, String userId) async {
    final extension = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_$timestamp.$extension';
    final path = 'meal_plans/$fileName';

    await _client.storage.from(_bucketName).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return url;
  }

  /// Upload check-in photo (File - mobile)
  Future<String> uploadCheckInPhoto(File file, String userId) async {
    final extension = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_$timestamp.$extension';
    final path = 'check_ins/$fileName';

    await _client.storage.from(_bucketName).upload(
          path,
          file,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return url;
  }

  /// Upload check-in photo from bytes (web-compatible)
  Future<String> uploadCheckInPhotoBytes(Uint8List bytes, String extension, String userId) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = '${userId}_$timestamp.$extension';
    final path = 'check_ins/$fileName';

    // uploadBinary is the web-safe path for raw bytes. upload() takes a
    // dart:io File and calls postFile on it, so passing a Uint8List there
    // (as the old `bytes as dynamic` did) throws at runtime on web — which
    // broke every check-in photo submit from the browser.
    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return url;
  }

  /// Upload a profile avatar from raw bytes (web-safe). Returns the public URL
  /// to store in athletes.avatar_url.
  Future<String> uploadAvatarBytes(
    Uint8List bytes,
    String extension,
    String userId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'avatars/${userId}_$timestamp.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  /// Upload an affiliated-brand logo from raw bytes (web-safe). Returns the
  /// public URL to store in affiliated_brands.logo_url.
  Future<String> uploadBrandLogoBytes(
    Uint8List bytes,
    String extension,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'brand_logos/logo_$timestamp.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  /// Upload a routine cover image from raw bytes (web-safe). Returns the
  /// public URL to store in routines.image_url.
  Future<String> uploadRoutineImageBytes(
    Uint8List bytes,
    String extension,
    String userId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'routine_images/${userId}_$timestamp.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  /// Upload a meal plan cover from raw bytes (web-safe). Returns the public URL
  /// to store in meal_plans.image_url.
  Future<String> uploadMealPlanCoverBytes(
    Uint8List bytes,
    String extension,
    String userId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'meal_plans/${userId}_$timestamp.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }

  /// Upload a meal photo from raw bytes (web-safe). Returns the public URL
  /// to store in meal_plan_items.image_url.
  Future<String> uploadMealImageBytes(
    Uint8List bytes,
    String extension,
    String mealPlanId,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'meal_images/${mealPlanId}_$timestamp.$extension';

    await _client.storage.from(_bucketName).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _getContentType(extension),
            upsert: true,
          ),
        );

    return _client.storage.from(_bucketName).getPublicUrl(path);
  }
}

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StorageService(client);
});
