import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/theme_redesign.dart';
import '../services/affiliated_brand_service.dart';
import '../models/affiliated_brand_model.dart';

/// Read-only list of affiliated-brand discounts. Shared by the student
/// "Beneficio" tab and the trainer's benefits screen.
class BenefitsContent extends ConsumerStatefulWidget {
  const BenefitsContent({super.key});

  @override
  ConsumerState<BenefitsContent> createState() => _BenefitsContentState();
}

// Category filter chips — index 0 = "Todos" (show all).
// Slug at index N (1-based) maps to affiliated_brands.category.
const List<String> _kCategoryLabels = ['Todos', 'Ropa', 'Nutrición', 'Salud'];
// Corresponding DB slugs; null = no filter (Todos).
const List<String?> _kCategorySlugs = [null, 'ropa', 'nutricion', 'salud'];

class _BenefitsContentState extends ConsumerState<BenefitsContent> {
  int _selectedCategory = 0;

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
      color: RedesignColors.actionPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 120,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CTA banner ────────────────────────────────────────────────
            _CtaBanner(
              onTap: () => _openUrl(context, AppConstants.prgsBrandsWhatsappUrl),
            ),
            const SizedBox(height: 20),

            // ── Category filter chips ─────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _kCategoryLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = _selectedCategory == i;
                  return _FilterChip(
                    label: _kCategoryLabels[i],
                    selected: selected,
                    onTap: () => setState(() => _selectedCategory = i),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ── Brand cards ───────────────────────────────────────────────
            brandsAsync.when(
              data: (brands) {
                // Filter by selected category slug; null slug = show all.
                final slug = _kCategorySlugs[_selectedCategory];
                final filtered = slug == null
                    ? brands
                    : brands.where((b) => b.category == slug).toList();

                if (filtered.isEmpty) {
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
                  children: filtered
                      .map((b) => _BrandCard(
                            brand: b,
                            onOpenUrl: (url) => _openUrl(context, url),
                          ))
                      .toList(),
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(
                    color: RedesignColors.actionPrimary,
                  ),
                ),
              ),
              error: (e, _) => const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: Text(
                    'No se pudieron cargar los descuentos',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.actionPrimary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.actionPrimary,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Metropolis',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? RedesignColors.onActionPrimary
                : RedesignColors.actionPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Brand card — full-width stacked design per Figma
// ─────────────────────────────────────────────────────────────────────────────

/// Returns a capitalized display label for a category slug,
/// e.g. 'nutricion' → 'Nutrición'.
String _categoryDisplayLabel(String? slug) {
  switch (slug) {
    case 'ropa':
      return 'Ropa';
    case 'nutricion':
      return 'Nutrición';
    case 'salud':
      return 'Salud';
    default:
      return '';
  }
}

class _BrandCard extends StatelessWidget {
  final AffiliatedBrand brand;
  final void Function(String? url) onOpenUrl;

  const _BrandCard({required this.brand, required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    // "Categoría • Nombre de marca" subtitle — category portion only when set.
    final categoryLabel = _categoryDisplayLabel(brand.category);
    final subtitleText = categoryLabel.isNotEmpty
        ? '$categoryLabel • ${brand.name}'
        : brand.name;

    // Big headline: prefer discountLabel, fall back to benefitDescription, then name.
    final headlineText = brand.discountLabel?.isNotEmpty == true
        ? brand.discountLabel!
        : (brand.benefitDescription?.isNotEmpty == true
            ? brand.benefitDescription!
            : brand.name);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // Figma card surface: primario700 (#1E2A36) — dark but distinct from bg
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: icon tile + discount headline + code ───────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Square icon tile
              _IconTile(brand: brand),
              const SizedBox(width: 14),
              // Discount headline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Big bold discount headline (discountLabel > benefitDescription > name)
                    Text(
                      headlineText,
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Muted description line (benefitDescription, only when
                    // discountLabel is also set — otherwise it was used above).
                    if (brand.discountLabel?.isNotEmpty == true &&
                        brand.benefitDescription?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        brand.benefitDescription!,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario300,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (brand.bannerText?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        brand.bannerText!,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario300,
                          fontSize: 12,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Discount code — top-right in teal
              if (brand.discountCode?.isNotEmpty == true) ...[
                const SizedBox(width: 10),
                Text(
                  'Código: ${brand.discountCode}',
                  style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.actionPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),

          // ── Subtitle: Categoría • Nombre de marca ──────────────────────
          const SizedBox(height: 10),
          Text(
            subtitleText,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario300,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // ── Action buttons — full-width, stacked ───────────────────────
          if (brand.hasWebsite || brand.hasInstagram) ...[
            const SizedBox(height: 16),
            if (brand.hasWebsite)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => onOpenUrl(brand.websiteUrl),
                  icon: const Icon(Icons.storefront_rounded, size: 18),
                  label: const Text('Ver tienda'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RedesignColors.actionPrimary,
                    foregroundColor: RedesignColors.onActionPrimary,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RedesignRadius.buttonLg),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Metropolis',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            if (brand.hasWebsite && brand.hasInstagram)
              const SizedBox(height: 10),
            if (brand.hasInstagram)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onOpenUrl(brand.instagramDisplayUrl),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Instagram'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.white38, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(RedesignRadius.buttonLg),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Metropolis',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Icon tile — square, rounded, slightly lighter dark fill
// ─────────────────────────────────────────────────────────────────────────────

class _IconTile extends StatelessWidget {
  final AffiliatedBrand brand;
  const _IconTile({required this.brand});

  @override
  Widget build(BuildContext context) {
    // Use logo if available; otherwise show a contextual icon.
    final hasLogo = brand.logoUrl?.isNotEmpty == true;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(RedesignRadius.iconBadge),
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(brand.logoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: hasLogo
          ? null
          : const Icon(
              Icons.local_offer_rounded,
              color: RedesignColors.actionPrimary,
              size: 26,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA banner — redesign: dark pill, (i) icon, outlined teal "Contactar" button
// ─────────────────────────────────────────────────────────────────────────────

class _CtaBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _CtaBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RedesignSpacing.bannerPaddingH,
        vertical: RedesignSpacing.bannerPaddingV,
      ),
      decoration: BoxDecoration(
        color: RedesignColors.primario600, // #31363B — dark info banner
        borderRadius: BorderRadius.circular(RedesignRadius.banner),
      ),
      child: Row(
        children: [
          // Info circle icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: RedesignColors.primario500.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '¿Queres que tu marca/emprendimiento figure acá?',
              style: TextStyle(
                fontFamily: 'Metropolis',
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Outlined teal "Contactar" pill button
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
                border: Border.all(
                  color: RedesignColors.actionPrimary,
                  width: 1.2,
                ),
              ),
              child: const Text(
                'Contactar',
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.actionPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
