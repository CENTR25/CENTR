/// Affiliated brand offering a discount, shown in the student "Beneficios" tab.
class AffiliatedBrand {
  final String id;
  final String name;
  final String? discountCode;
  final String? bannerText;
  final String? websiteUrl;
  final String? instagramUrl;
  final String? logoUrl;
  final bool isActive;
  final int displayOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AffiliatedBrand({
    required this.id,
    required this.name,
    this.discountCode,
    this.bannerText,
    this.websiteUrl,
    this.instagramUrl,
    this.logoUrl,
    this.isActive = true,
    this.displayOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasWebsite => (websiteUrl?.trim().isNotEmpty ?? false);
  bool get hasInstagram => (instagramUrl?.trim().isNotEmpty ?? false);

  factory AffiliatedBrand.fromJson(Map<String, dynamic> json) {
    // Coerce instead of bare `as String` — Supabase JS on web can hand back
    // non-String dynamics and a hard cast throws (see the exercise-list crash).
    String? asStr(Object? v) =>
        v == null ? null : (v is String ? v : v.toString());
    DateTime? asDate(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    return AffiliatedBrand(
      id: json['id']?.toString() ?? '',
      name: asStr(json['name']) ?? '',
      discountCode: asStr(json['discount_code']),
      bannerText: asStr(json['banner_text']),
      websiteUrl: asStr(json['website_url']),
      instagramUrl: asStr(json['instagram_url']),
      logoUrl: asStr(json['logo_url']),
      isActive: (json['is_active'] as bool?) ?? true,
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      createdAt: asDate(json['created_at']),
      updatedAt: asDate(json['updated_at']),
    );
  }

  AffiliatedBrand copyWith({
    String? name,
    String? discountCode,
    String? bannerText,
    String? websiteUrl,
    String? instagramUrl,
    String? logoUrl,
    bool? isActive,
    int? displayOrder,
  }) {
    return AffiliatedBrand(
      id: id,
      name: name ?? this.name,
      discountCode: discountCode ?? this.discountCode,
      bannerText: bannerText ?? this.bannerText,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
