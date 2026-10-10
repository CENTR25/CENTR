import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/news_model.dart';
import 'supabase_service.dart';

/// Service for managing news articles
class NewsService {
  final SupabaseClient _client;

  NewsService(this._client);

  /// Get all published news articles (for students and trainers)
  Future<List<NewsArticle>> getPublishedNews() async {
    try {
      final response = await _client
          .from('news_articles')
          .select()
          .eq('is_published', true)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NewsArticle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching published news: $e');
      return [];
    }
  }

  /// Get all news articles (for admin)
  Future<List<NewsArticle>> getAllNews() async {
    try {
      final response = await _client
          .from('news_articles')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => NewsArticle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all news: $e');
      return [];
    }
  }

  /// Create a new news article.
  /// [trainerId]: pass the caller's trainers.id for trainer-scoped news;
  /// leave null (default) for global/admin news.
  Future<NewsArticle?> createNews({
    required String title,
    required String content,
    String? imageUrl,
    String accentColor = '#9C27B0',
    String iconName = 'newspaper',
    bool isPublished = true,
    int displayOrder = 0,
    String? trainerId,
  }) async {
    try {
      final response = await _client.from('news_articles').insert({
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'accent_color': accentColor,
        'icon_name': iconName,
        'is_published': isPublished,
        'display_order': displayOrder,
        'created_at': DateTime.now().toIso8601String(),
        if (trainerId != null) 'trainer_id': trainerId,
      }).select().single();

      return NewsArticle.fromJson(response);
    } catch (e) {
      debugPrint('Error creating news: $e');
      return null;
    }
  }

  /// Update an existing news article
  Future<bool> updateNews(String id, {
    String? title,
    String? content,
    String? imageUrl,
    String? accentColor,
    String? iconName,
    bool? isPublished,
    int? displayOrder,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (imageUrl != null) updates['image_url'] = imageUrl;
      if (accentColor != null) updates['accent_color'] = accentColor;
      if (iconName != null) updates['icon_name'] = iconName;
      if (isPublished != null) updates['is_published'] = isPublished;
      if (displayOrder != null) updates['display_order'] = displayOrder;

      await _client.from('news_articles').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating news: $e');
      return false;
    }
  }

  /// Delete a news article
  Future<bool> deleteNews(String id) async {
    try {
      await _client.from('news_articles').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting news: $e');
      return false;
    }
  }
}

/// Provider for NewsService
final newsServiceProvider = Provider<NewsService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NewsService(client);
});

/// Provider for published news (students and trainers)
final publishedNewsProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final service = ref.read(newsServiceProvider);
  return service.getPublishedNews();
});

/// Provider for all news (admin)
final allNewsProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final service = ref.read(newsServiceProvider);
  return service.getAllNews();
});

/// Student feed: global news (trainer_id IS NULL) UNION the signed-in student's
/// trainer news (trainer_id = their assigned trainer).
/// If the student has no trainer assigned, only global articles are returned.
final studentNewsProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final client = ref.read(supabaseClientProvider);

  // 1. Look up the student's assigned trainer_id from athletes table.
  final uid = client.auth.currentUser?.id;
  if (uid == null) return [];

  final athleteRow = await client
      .from('athletes')
      .select('trainer_id')
      .eq('user_id', uid)
      .maybeSingle();

  final studentTrainerId = athleteRow?['trainer_id'] as String?;

  // 2. Fetch published articles: global OR assigned trainer.
  //    Using .or() with a column filter for the two cases.
  final List<dynamic> response;
  if (studentTrainerId != null) {
    response = await client
        .from('news_articles')
        .select()
        .eq('is_published', true)
        .or('trainer_id.is.null,trainer_id.eq.$studentTrainerId')
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);
  } else {
    // No trainer assigned — show only global news.
    response = await client
        .from('news_articles')
        .select()
        .eq('is_published', true)
        .isFilter('trainer_id', null)
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);
  }

  return response.map((json) => NewsArticle.fromJson(json as Map<String, dynamic>)).toList();
});
