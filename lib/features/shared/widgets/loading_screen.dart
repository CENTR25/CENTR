import 'package:flutter/material.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../auth/presentation/widgets/prgs_brand.dart';

/// Splash / loading screen shown during initialization and auth resolution.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RedesignColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.0,
            colors: [
              Color(0x1A01D2B2), // subtle teal glow
              RedesignColors.background,
            ],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PrgsLogoLockup(
                  ringHeight: 124,
                  wordmarkHeight: 70,
                  gap: 50,
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          RedesignColors.actionPrimaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Iniciando sesión',
                      style: RedesignType.bodySm
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
