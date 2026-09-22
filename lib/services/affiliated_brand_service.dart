import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/affiliated_brand_model.dart';
import 'supabase_service.dart';

/// Service for managing affiliated brands (discount store).
class AffiliatedBrandService {
  final SupabaseClient _client;

  AffiliatedBrandService(this._client);

  static const _columns =
      'id, name, discount_code, banner_text, website_url, instagram_url, '
      'logo_url, is_active, display_order, created_at, updated_at';

  /// Active brands (students).
  Future<List<AffiliatedBrand>> getActiveBrands() async {
    try {
      final response = await _client
          .from('affiliated_brands')
          .select(_columns)
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AffiliatedBrand.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching active brands: $e');
      return [];
    }
  }

  /// All brands (admin).
  Future<List<AffiliatedBrand>> getAllBrands() async {
    try {
      final response = await _client
          .from('affiliated_brands')
          .select(_columns)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => AffiliatedBrand.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all brands: $e');
      return [];
    }
  }

  Future<AffiliatedBrand?> createBrand({
    required String name,
    String? discountCode,
    String? bannerText,
    String? websiteUrl,
    String? instagramUrl,
    String? logoUrl,
    bool isActive = true,
    int displayOrder = 0,
  }) async {
    try {
      final response = await _client
          .from('affiliated_brands')
          .insert({
            'name': name,
            'discount_code': discountCode,
            'banner_text': bannerText,
            'website_url': websiteUrl,
            'instagram_url': instagramUrl,
            'logo_url': logoUrl,
            'is_active': isActive,
            'display_order': displayOrder,
          })
          .select(_columns)
          .single();

      return AffiliatedBrand.fromJson(response);
    } catch (e) {
      debugPrint('Error creating brand: $e');
      return null;
    }
  }

  Future<bool> updateBrand(
    String id, {
    String? name,
    String? discountCode,
    String? bannerText,
    String? websiteUrl,
    String? instagramUrl,
    String? logoUrl,
    bool? isActive,
    int? displayOrder,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Nullable text fields are always written so admins can clear them;
      // name/is_active/display_order only when provided.
      if (name != null) updates['name'] = name;
      updates['discount_code'] = discountCode;
      updates['banner_text'] = bannerText;
      updates['website_url'] = websiteUrl;
      updates['instagram_url'] = instagramUrl;
      updates['logo_url'] = logoUrl;
      if (isActive != null) updates['is_active'] = isActive;
      if (displayOrder != null) updates['display_order'] = displayOrder;

      await _client.from('affiliated_brands').update(updates).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating brand: $e');
      return false;
    }
  }

  Future<bool> deleteBrand(String id) async {
    try {
      await _client.from('affiliated_brands').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting brand: $e');
      return false;
    }
  }
}

final affiliatedBrandServiceProvider = Provider<AffiliatedBrandService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AffiliatedBrandService(client);
});

/// Active brands (students).
final activeBrandsProvider = FutureProvider<List<AffiliatedBrand>>((ref) async {
  return ref.read(affiliatedBrandServiceProvider).getActiveBrands();
});

/// All brands (admin).
final allBrandsProvider = FutureProvider<List<AffiliatedBrand>>((ref) async {
  return ref.read(affiliatedBrandServiceProvider).getAllBrands();
});
