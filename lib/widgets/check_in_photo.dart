import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// Renders a check-in photo with [Image.network] instead of CachedNetworkImage.
///
/// On Flutter web / CanvasKit (the client runs the web PWA) CachedNetworkImage
/// intermittently repaints black after route transitions — swiping the
/// full-screen viewer, then popping back, left both the viewer pages and the
/// grid/detail thumbnails black. Check-in photos are small (<1 MB), so the
/// browser's own HTTP cache covers caching and Image.network — the most
/// battle-tested path on CanvasKit — sidesteps the bug entirely.
class CheckInPhoto extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final double errorIconSize;

  const CheckInPhoto({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.errorIconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      cacheWidth: cacheWidth,
      // Keep the last frame while a swipe reloads, so pages never flash black.
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        );
      },
      errorBuilder: (_, __, ___) => Icon(
        Icons.broken_image_rounded,
        color: Colors.white24,
        size: errorIconSize,
      ),
    );
  }
}
