import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for handling file uploads to Supabase Storage
class StorageService {
  final SupabaseClient _client;

  StorageService(this._client);

  static const String _bucketName = 'exercise-media';

  /// Upload exercise video (MP4)
  /// Returns the public URL of the uploaded video
  Future<String> uploadExerciseVideo(File file, String exerciseId) async {
    final fileName = '$exerciseId.mp4';
    final path = 'videos/$fileName';

    await _client.storage.from(_bucketName).upload(
          path,
          file,
          fileOptions: const FileOptions(
            contentType: 'video/mp4',
            upsert: true, // Overwrite if exists
          ),
        );

    final url = _client.storage.from(_bucketName).getPublicUrl(path);
    return url;
  }

  /// Upload exercise image (JPG/PNG)
  /// Returns the public URL of the uploaded image
  Future<String> uploadExerciseImage(
    File file,
    String exerciseId,
    int index,
  ) async {
    final extension = file.path.split('.').last;
    final fileName = '${exerciseId}_$index.$extension';
    final path = 'images/$fileName';

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

  /// Upload multiple images for an exercise
  /// Returns list of public URLs
  Future<List<String>> uploadExerciseImages(
    List<File> files,
    String exerciseId,
  ) async {
    final urls = <String>[];

    for (var i = 0; i < files.length; i++) {
      final url = await uploadExerciseImage(files[i], exerciseId, i);
      urls.add(url);
    }

    return urls;
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
      print('Error deleting exercise media: $e');
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
}

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return StorageService(client);
});
