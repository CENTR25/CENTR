import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/benefits_content.dart';

/// Trainer-facing view of the affiliated-brand benefits (same content students
/// see). Reached from the trainer profile menu, not the bottom nav.
class TrainerBenefitsScreen extends StatelessWidget {
  const TrainerBenefitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Beneficios'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const BenefitsContent(),
    );
  }
}
