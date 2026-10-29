/// A single FAQ / help-center entry shown in the trainer "Ayuda" screen.
class HelpArticle {
  final String id;

  /// Category slug: 'alumnos' | 'planes' | 'pagos' | null (uncategorised).
  final String? category;
  final String question;
  final String answer;
  final int orderIndex;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HelpArticle({
    required this.id,
    this.category,
    required this.question,
    required this.answer,
    this.orderIndex = 0,
    this.isPublished = true,
    this.createdAt,
    this.updatedAt,
  });

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    // Coerce rather than hard-cast — Supabase JS on web can hand back
    // non-String dynamics and a bare `as String` throws.
    String? asStr(Object? v) =>
        v == null ? null : (v is String ? v : v.toString());
    DateTime? asDate(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return HelpArticle(
      id: json['id']?.toString() ?? '',
      category: asStr(json['category']),
      question: asStr(json['question']) ?? '',
      answer: asStr(json['answer']) ?? '',
      orderIndex: (json['order_index'] as num?)?.toInt() ?? 0,
      isPublished: (json['is_published'] as bool?) ?? true,
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }
}
