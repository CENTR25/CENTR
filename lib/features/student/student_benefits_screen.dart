import 'package:flutter/material.dart';

import '../../core/theme/theme_redesign.dart';
import '../../widgets/benefits_content.dart';

/// Student "Beneficios" — affiliated-brand discounts. Reached from the home
/// quick-actions. Wraps the shared [BenefitsContent] in the redesign shell.
class StudentBenefitsScreen extends StatefulWidget {
  const StudentBenefitsScreen({super.key});

  @override
  State<StudentBenefitsScreen> createState() => _StudentBenefitsScreenState();
}

class _StudentBenefitsScreenState extends State<StudentBenefitsScreen> {
  bool _grid = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          // Left-aligned title (matches Figma — title is NOT centred)
          centerTitle: false,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          title: const Text(
            'Beneficios',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => setState(() => _grid = !_grid),
              tooltip: _grid ? 'Ver en lista' : 'Ver en cuadrícula',
              icon: Icon(
                _grid ? Icons.view_agenda_rounded : Icons.grid_view_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ),
        body: BenefitsContent(grid: _grid),
      ),
    );
  }
}
