/// News article model for blog/news system
class NewsArticle {
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String accentColor; // Hex color code
  final String iconName; // Material icon name
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isPublished;
  final int displayOrder;
  /// Null = global/admin news visible to all students.
  /// Non-null = scoped to that trainer's athletes only.
  final String? trainerId;

  /// Target audience: 'all' | 'trainers' | 'students'.
  final String audience;

  /// Optional external link (e.g. a brand's Instagram). When set, tapping the
  /// news card opens it instead of the in-app detail sheet.
  final String? linkUrl;

  bool get hasLink => linkUrl != null && linkUrl!.trim().isNotEmpty;

  NewsArticle({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.accentColor = '#9C27B0', // Default purple
    this.iconName = 'newspaper',
    required this.createdAt,
    this.updatedAt,
    this.isPublished = true,
    this.displayOrder = 0,
    this.trainerId,
    this.audience = 'all',
    this.linkUrl,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      accentColor: json['accent_color'] as String? ?? '#9C27B0',
      iconName: json['icon_name'] as String? ?? 'newspaper',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
      isPublished: json['is_published'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      trainerId: json['trainer_id'] as String?,
      audience: json['audience'] as String? ?? 'all',
      linkUrl: json['link_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'accent_color': accentColor,
      'icon_name': iconName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_published': isPublished,
      'display_order': displayOrder,
      'trainer_id': trainerId,
      'audience': audience,
      'link_url': linkUrl,
    };
  }

  NewsArticle copyWith({
    String? id,
    String? title,
    String? content,
    String? imageUrl,
    String? accentColor,
    String? iconName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublished,
    int? displayOrder,
    String? trainerId,
    String? audience,
    String? linkUrl,
  }) {
    return NewsArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      accentColor: accentColor ?? this.accentColor,
      iconName: iconName ?? this.iconName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isPublished: isPublished ?? this.isPublished,
      displayOrder: displayOrder ?? this.displayOrder,
      trainerId: trainerId ?? this.trainerId,
      audience: audience ?? this.audience,
      linkUrl: linkUrl ?? this.linkUrl,
    );
  }
}
