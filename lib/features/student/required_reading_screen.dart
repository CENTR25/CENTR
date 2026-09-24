import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Read-only view of the trainer's "Lectura Obligatoria" content.
class RequiredReadingScreen extends StatelessWidget {
  final String content;

  const RequiredReadingScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lectura Obligatoria'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: SelectableText(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
