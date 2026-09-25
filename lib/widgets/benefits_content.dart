import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';
import '../services/affiliated_brand_service.dart';
import '../models/affiliated_brand_model.dart';

/// Read-only list of affiliated-brand discounts. Shared by the student
/// "Beneficio" tab and the trainer's benefits screen.
class BenefitsContent extends ConsumerWidget {
  const BenefitsContent({super.key});

  Future<void> _openUrl(BuildContext context, String? rawUrl) async {
    final value = rawUrl?.trim() ?? '';
    if (value.isEmpty) return;
    final url = value.startsWith('http') ? value : 'https://$value';
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(activeBrandsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(activeBrandsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.star_rounded, size: 22, color: Color(0xFFFFD700)),
                SizedBox(width: 10),
                Text(
                  'Beneficios Exclusivos',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            brandsAsync.when(
              data: (brands) {
                if (brands.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'Pronto tendrás descuentos exclusivos aquí',
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return Column(
                  children:
                      brands.map((b) => _buildBrandCard(context, b)).toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: Text('No se pudieron cargar los descuentos',
                      style: TextStyle(color: Colors.white54)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCard(BuildContext context, AffiliatedBrand brand) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  image: (brand.logoUrl?.isNotEmpty ?? false)
                      ? DecorationImage(
                          image: NetworkImage(brand.logoUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (brand.logoUrl?.isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.local_offer_rounded,
                        color: Color(0xFFFFD700), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  brand.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (brand.discountCode?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.confirmation_number_outlined,
                      color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Código: ${brand.discountCode}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (brand.bannerText?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              brand.bannerText!,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],
          if (brand.hasWebsite || brand.hasInstagram) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (brand.hasWebsite)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openUrl(context, brand.websiteUrl),
                      icon: const Icon(Icons.storefront, size: 18),
                      label: const Text('Ver tienda'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                if (brand.hasWebsite && brand.hasInstagram)
                  const SizedBox(width: 12),
                if (brand.hasInstagram)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openUrl(context, brand.instagramUrl),
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: const Text('Instagram'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side:
                            BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
