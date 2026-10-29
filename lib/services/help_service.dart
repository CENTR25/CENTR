import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/help_article_model.dart';
import 'supabase_service.dart';

/// Service for the help-center FAQ (trainer "Ayuda" screen + admin CRUD).
class HelpService {
  final SupabaseClient _client;

  HelpService(this._client);

  static const _columns =
      'id, category, question, answer, order_index, is_published, '
      'created_at, updated_at';

  /// Published articles (trainer-facing).
  Future<List<HelpArticle>> getPublishedArticles() async {
    try {
      final response = await _client
          .from('help_articles')
          .select(_columns)
          .eq('is_published', true)
          .order('order_index', ascending: true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HelpArticle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching help articles: $e');
      return [];
    }
  }

  /// All articles (admin).
  Future<List<HelpArticle>> getAllArticles() async {
    try {
      final response = await _client
          .from('help_articles')
          .select(_columns)
          .order('order_index', ascending: true)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => HelpArticle.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all help articles: $e');
      return [];
    }
  }

  Future<HelpArticle?> createArticle({
    required String question,
    required String answer,
    String? category,
    int orderIndex = 0,
    bool isPublished = true,
  }) async {
    try {
      final response = await _client
          .from('help_articles')
          .insert({
            'question': question,
            'answer': answer,
            'category': category,
            'order_index': orderIndex,
            'is_published': isPublished,
          })
          .select(_columns)
          .single();
      return HelpArticle.fromJson(response);
    } catch (e) {
      debugPrint('Error creating help article: $e');
      return null;
    }
  }

  Future<bool> updateArticle(
    String id, {
    String? question,
    String? answer,
    String? category,
    int? orderIndex,
    bool? isPublished,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (question != null) updates['question'] = question;
      if (answer != null) updates['answer'] = answer;
      updates['category'] = category; // nullable — allow clearing
      if (orderIndex != null) updates['order_index'] = orderIndex;
      if (isPublished != null) updates['is_published'] = isPublished;

      await _client.from('help_articles').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating help article: $e');
      return false;
    }
  }

  Future<bool> deleteArticle(String id) async {
    try {
      await _client.from('help_articles').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting help article: $e');
      return false;
    }
  }
}

final helpServiceProvider = Provider<HelpService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return HelpService(client);
});

/// Published articles (trainer Ayuda screen).
final publishedHelpArticlesProvider =
    FutureProvider<List<HelpArticle>>((ref) async {
  return ref.read(helpServiceProvider).getPublishedArticles();
});

/// All articles (admin CRUD).
final allHelpArticlesProvider =
    FutureProvider<List<HelpArticle>>((ref) async {
  return ref.read(helpServiceProvider).getAllArticles();
});
