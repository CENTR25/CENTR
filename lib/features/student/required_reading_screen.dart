import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/rich_text/mini_markdown.dart';
import '../../core/theme/theme_redesign.dart';
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

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          title: Text(
            'Lectura Obligatoria',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          foregroundColor: RedesignColors.primario50,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MiniMarkdownView(source: content),
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
                'Podés volver a leer esta información cuando quieras tocando '
                'tu avatar (arriba a la derecha) → Lectura Obligatoria.',
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
      height: 54,
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
                  color: RedesignColors.onActionPrimary,
                ),
              )
            : const Icon(Icons.check_circle_outline),
        label: const Text(
          'Acepto haberlo leído',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
