import 'package:flutter/material.dart';

/// Official PRGS brand lockup — teal gradient ring stacked above the white
/// "prgs" wordmark. PNG exports from Figma (Circulo + Logo blanco); PNG avoids
/// flutter_svg dropping the Figma gradients / drop-shadow to black.
class PrgsLogoLockup extends StatelessWidget {
  const PrgsLogoLockup({
    super.key,
    this.ringHeight = 83, // Figma: ring 84.5 × 83
    this.wordmarkHeight = 47, // Figma: wordmark 88 × 47
    this.gap = 34, // Figma: ring-bottom Y220 → wordmark-top Y254
  });

  final double ringHeight;
  final double wordmarkHeight;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/prgs_ring.png', height: ringHeight),
          SizedBox(height: gap),
          Image.asset('assets/images/prgs_logo.png', height: wordmarkHeight),
        ],
      );
}
