import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';

/// Editor de formulario de check-in que el coach diseña para sus alumnos.
/// Los alumnos verán este formulario al hacer check-in semanal.
class CheckInFormEditorScreen extends ConsumerStatefulWidget {
  const CheckInFormEditorScreen({super.key});

  @override
  ConsumerState<CheckInFormEditorScreen> createState() => _CheckInFormEditorScreenState();
}

class _CheckInFormEditorScreenState extends ConsumerState<CheckInFormEditorScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isActive = true;
  List<_FormQuestion> _questions = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadForm() async {
    final formAsync = ref.watch(myCheckInFormProvider);
    formAsync.whenData((form) {
      if (form != null && mounted) {
        setState(() {
          _titleController.text = form['title'] as String? ?? '';
          _descriptionController.text = form['description'] as String? ?? '';
          _isActive = (form['is_active'] as bool?) ?? true;
          final questions = (form['questions'] as List?) ?? [];
          _questions = questions
              .map((q) => _FormQuestion.fromMap(q as Map<String, dynamic>))
              .toList();
        });
      }
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El título es obligatorio')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(trainerServiceProvider).saveCheckInForm(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        questions: _questions.map((q) => q.toMap()).toList(),
        isActive: _isActive,
      );
      ref.invalidate(myCheckInFormProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formulario guardado'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addQuestion(String type) {
    setState(() {
      _questions.add(_FormQuestion(
        label: 'Nueva pregunta',
        type: type,
        options: type == 'multiple_choice' ? ['Opción 1', 'Opción 2'] : [],
      ));
    });
  }

  void _removeQuestion(int index) {
    setState(() => _questions.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Formulario de Check-in'),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Guardar', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Título del formulario',
                hintText: 'Ej: ¿Cómo te sentiste este mes?',
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Ayudános a saber cómo va tu progreso…',
              ),
            ),
            const SizedBox(height: 12),

            // Active toggle
            SwitchListTile(
              title: const Text('Activo',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Los alumnos verán este formulario al hacer check-in',
                  style: TextStyle(color: Colors.white54, fontSize: 12)),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeColor: AppColors.success,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),

            // Questions header
            Row(
              children: [
                const Text(
                  'PREGUNTAS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                  onSelected: _addQuestion,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'text_short', child: Text('Texto corto')),
                    PopupMenuItem(value: 'text_long', child: Text('Texto largo')),
                    PopupMenuItem(value: 'scale_1_10', child: Text('Escala 1-10')),
                    PopupMenuItem(value: 'multiple_choice', child: Text('Opciones múltiples')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_questions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.quiz_outlined, color: Colors.white38, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'No hay preguntas todavía.\nTocá "+" para agregar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_questions.length, (index) {
                final q = _questions[index];
                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _questionTypeLabel(q.type),
                                style: const TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
                              onPressed: () => _removeQuestion(index),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'Texto de la pregunta',
                            hintText: 'Ej: ¿Del 1 al 10, cómo calificás tu energía?',
                            isDense: true,
                          ),
                          onChanged: (v) => _questions[index].label = v,
                          controller: TextEditingController(text: q.label),
                        ),
                        if (q.type == 'multiple_choice') ...[
                          const SizedBox(height: 12),
                          const Text('Opciones:',
                              style: TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 6),
                          ...List.generate(q.options.length, (oi) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text('${oi + 1}.',
                                        style: const TextStyle(color: Colors.white38, fontSize: 12)),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: const InputDecoration(isDense: true),
                                      onChanged: (v) => _questions[index].options[oi] = v,
                                      controller: TextEditingController(text: q.options[oi]),
                                    ),
                                  ),
                                  if (q.options.length > 1)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() => _questions[index].options.removeAt(oi));
                                      },
                                      child: const Icon(Icons.remove_circle_outline,
                                          color: Colors.redAccent, size: 18),
                                    ),
                                ],
                              ),
                            );
                          }),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _questions[index].options.add(
                                  'Opción ${_questions[index].options.length + 1}'));
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Agregar opción'),
                            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _questionTypeLabel(String type) {
    switch (type) {
      case 'text_short': return 'Texto corto';
      case 'text_long': return 'Texto largo';
      case 'scale_1_10': return 'Escala 1-10';
      case 'multiple_choice': return 'Opciones';
      default: return type;
    }
  }
}

class _FormQuestion {
  String label;
  String type;
  List<String> options;

  _FormQuestion({
    required this.label,
    required this.type,
    this.options = const [],
  });

  factory _FormQuestion.fromMap(Map<String, dynamic> map) => _FormQuestion(
    label: map['label'] as String? ?? '',
    type: map['type'] as String? ?? 'text_short',
    options: (map['options'] as List?)?.cast<String>() ?? [],
  );

  Map<String, dynamic> toMap() => {
    'label': label,
    'type': type,
    'options': options,
  };
}
