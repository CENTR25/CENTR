import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../services/affiliated_brand_service.dart';
import '../models/affiliated_brand_model.dart';

/// Read-only list of affiliated-brand discounts. Shared by the student
/// "Beneficio" tab and the trainer's benefits screen.
class BenefitsContent extends ConsumerStatefulWidget {
  const BenefitsContent({super.key});

  @override
  ConsumerState<BenefitsContent> createState() => _BenefitsContentState();
}

class _BenefitsContentState extends ConsumerState<BenefitsContent> {
  bool _compact = false; // list/summary toggle

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
  Widget build(BuildContext context) {
    final brandsAsync = ref.watch(activeBrandsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(activeBrandsProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + view toggle
            Row(
              children: [
                const Icon(Icons.star_rounded,
                    size: 22, color: Color(0xFFFFD700)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Beneficios Exclusivos',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                // List/card toggle
                IconButton(
                  tooltip: _compact ? 'Ver como tarjetas' : 'Vista compacta',
                  onPressed: () => setState(() => _compact = !_compact),
                  icon: Icon(
                    _compact
                        ? Icons.view_agenda_rounded
                        : Icons.view_list_rounded,
                    color: AppColors.textLight,
                    size: 22,
                  ),
                ),
              ],
            ),

            // CTA banner
            const SizedBox(height: 16),
            _CtaBanner(onTap: () => _openUrl(
              context,
              AppConstants.prgsBrandsWhatsappUrl,
            )),
            const SizedBox(height: 20),

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
                  children: _compact
                      ? brands
                          .map((b) => _buildCompactRow(context, b))
                          .toList()
                      : brands
                          .map((b) => _buildBrandCard(context, b))
                          .toList(),
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

  // ────────────── Compact row ──────────────
  Widget _buildCompactRow(BuildContext context, AffiliatedBrand brand) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
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
                    color: Color(0xFFFFD700), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  brand.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (brand.discountCode?.isNotEmpty ?? false)
                  Text(
                    'Código: ${brand.discountCode}',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (brand.hasWebsite)
            IconButton(
              onPressed: () => _openUrl(context, brand.websiteUrl),
              icon: const Icon(Icons.storefront,
                  color: AppColors.primary, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          if (brand.instagramDisplayUrl != null)
            IconButton(
              onPressed: () =>
                  _openUrl(context, brand.instagramDisplayUrl),
              icon: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white54, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  // ────────────── Full card ──────────────
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

          // Discount code chip
          if (brand.discountCode?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            Wrap(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4)),
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
            ),
          ],

          // Benefit description chip (below code)
          if (brand.benefitDescription?.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Wrap(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.redeem_rounded,
                          color: AppColors.accent, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          brand.benefitDescription!,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          // Banner text
          if (brand.bannerText?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text(
              brand.bannerText!,
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ],

          // Action buttons
          if (brand.hasWebsite || brand.instagramDisplayUrl != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (brand.hasWebsite)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _openUrl(context, brand.websiteUrl),
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
                if (brand.hasWebsite && brand.instagramDisplayUrl != null)
                  const SizedBox(width: 12),
                if (brand.instagramDisplayUrl != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _openUrl(context, brand.instagramDisplayUrl),
                      icon: const Icon(Icons.camera_alt_outlined,
                          size: 18),
                      label: const Text('Instagram'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3)),
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

class _CtaBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CtaBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF25D366).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF25D366).withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront_rounded,
                color: Color(0xFF25D366), size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                '¿Quieres que tu marca/emprendimiento figure acá?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Contactar',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
