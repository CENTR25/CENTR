import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/intake_form.dart';
import '../../services/trainer_service.dart';

/// Provider for a single athlete's intake questionnaire (trainer/admin read).
final athleteIntakeProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, athleteId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getAthleteIntake(athleteId);
});

/// Read-only view of an athlete's "Formulario para conocer al Atleta",
/// rendered from [kIntakeSections] so it always matches the student form.
class IntakeViewScreen extends ConsumerWidget {
  final String athleteId;
  final String athleteName;

  const IntakeViewScreen({
    super.key,
    required this.athleteId,
    required this.athleteName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intakeAsync = ref.watch(athleteIntakeProvider(athleteId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ficha del Atleta'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: intakeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar: $e',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
        data: (intake) {
          final responses =
              (intake?['responses'] as Map?)?.cast<String, dynamic>() ?? {};
          if (intake == null || responses.isEmpty) {
            return _empty();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Text(
                athleteName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Respuestas del formulario inicial',
                style: TextStyle(color: AppColors.textLight, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ...kIntakeSections.map((s) => _section(s, responses)),
            ],
          );
        },
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 16),
          const Text(
            'El atleta aún no completó su ficha',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _section(IntakeSection section, Map<String, dynamic> responses) {
    // Only show fields that were answered.
    final answered = section.fields
        .where((f) => _hasValue(responses[f.key]))
        .toList();
    if (answered.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, color: AppColors.primaryLight, size: 20),
              const SizedBox(width: 10),
              Text(
                section.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...answered.map((f) => _answer(f, responses[f.key])),
        ],
      ),
    );
  }

  bool _hasValue(dynamic v) {
    if (v is List) return v.isNotEmpty;
    return v is String && v.trim().isNotEmpty;
  }

  Widget _answer(IntakeField field, dynamic value) {
    final text = value is List ? value.join(', ') : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
