import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';

/// Read-only view of the trainer's "Lectura Obligatoria" content.
///
/// If the student hasn't acknowledged it yet, shows an "Acepto haberlo leído"
/// button that hides the home banner. The reading stays reachable from the
/// menu afterwards.
class RequiredReadingScreen extends ConsumerWidget {
  final String content;

  const RequiredReadingScreen({super.key, required this.content});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accepted =
        ref.watch(trainerRequiredReadingProvider).valueOrNull?.accepted ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lectura Obligatoria'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              content,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            if (!accepted) ...[
              _AcceptButton(
                onAccepted: () {
                  ref.invalidate(trainerRequiredReadingProvider);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Podés volver a leer esta información cuando quieras desde el '
              'menú (ícono ☰ arriba a la derecha) → Lectura Obligatoria.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptButton extends ConsumerStatefulWidget {
  final VoidCallback onAccepted;

  const _AcceptButton({required this.onAccepted});

  @override
  ConsumerState<_AcceptButton> createState() => _AcceptButtonState();
}

class _AcceptButtonState extends ConsumerState<_AcceptButton> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _saving
            ? null
            : () async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _saving = true);
                try {
                  await ref
                      .read(studentServiceProvider)
                      .acceptRequiredReading();
                  if (mounted) widget.onAccepted();
                } catch (_) {
                  if (mounted) setState(() => _saving = false);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('No se pudo guardar. Intentá de nuevo.'),
                    ),
                  );
                }
              },
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.check_circle_outline),
        label: const Text(
          'Acepto haberlo leído',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
