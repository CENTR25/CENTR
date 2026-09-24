import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';

/// Lets a trainer write/edit the "Lectura Obligatoria" their athletes see on
/// their home screen. Leaving it empty removes the banner for all athletes.
class RequiredReadingEditorScreen extends ConsumerStatefulWidget {
  const RequiredReadingEditorScreen({super.key});

  @override
  ConsumerState<RequiredReadingEditorScreen> createState() =>
      _RequiredReadingEditorScreenState();
}

class _RequiredReadingEditorScreenState
    extends ConsumerState<RequiredReadingEditorScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await ref.read(trainerServiceProvider).getRequiredReading();
    if (!mounted) return;
    setState(() {
      _controller.text = text ?? '';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(trainerServiceProvider)
          .updateRequiredReading(_controller.text);
      ref.invalidate(myRequiredReadingProvider);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lectura obligatoria guardada'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lectura Obligatoria'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Este texto le aparecerá a todos tus alumnos como un aviso '
                    'de lectura obligatoria en su inicio. Escribí acá tu '
                    'metodología, cómo se hacen los chequeos, obligaciones, etc. '
                    'Dejalo vacío si no querés mostrar nada.',
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.8),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(color: Colors.white, height: 1.4),
                      decoration: InputDecoration(
                        hintText: 'Escribí acá la información...',
                        alignLabelWithHint: true,
                        filled: true,
                        fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Guardar',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
