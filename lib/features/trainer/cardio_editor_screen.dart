import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';
import 'student_detail_screen.dart';

// ---------------------------------------------------------------------------
// Cardio Editor Screen
// Full-screen editor for structured cardio assigned to one athlete.
// ---------------------------------------------------------------------------

class CardioEditorScreen extends ConsumerStatefulWidget {
  final String athleteId;
  final String studentName;
  final String? initialActivity;
  final String? initialDuration;
  final String? initialLevel;
  final String? initialNote;
  final List<int> initialDays;

  const CardioEditorScreen({
    super.key,
    required this.athleteId,
    required this.studentName,
    this.initialActivity,
    this.initialDuration,
    this.initialLevel,
    this.initialNote,
    this.initialDays = const [],
  });

  @override
  ConsumerState<CardioEditorScreen> createState() =>
      _CardioEditorScreenState();
}

class _CardioEditorScreenState extends ConsumerState<CardioEditorScreen> {
  static const _activities = [
    'Escaladora',
    'Cinta',
    'Bici',
    'Elíptica',
    'Caminata',
  ];

  // L M X J V S D → ints 1..7 (Mon=1, Sun=7)
  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  late String? _activity;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _levelCtrl;
  late final TextEditingController _noteCtrl;
  late Set<int> _selectedDays;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _activity = widget.initialActivity;
    _durationCtrl =
        TextEditingController(text: widget.initialDuration ?? '');
    _levelCtrl =
        TextEditingController(text: widget.initialLevel ?? '');
    _noteCtrl =
        TextEditingController(text: widget.initialNote ?? '');
    _selectedDays = Set<int>.from(widget.initialDays);
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    _levelCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(trainerServiceProvider).updateAthleteCardioFull(
            widget.athleteId,
            activity: _activity,
            duration: _durationCtrl.text.trim().isEmpty
                ? null
                : _durationCtrl.text.trim(),
            level: _levelCtrl.text.trim().isEmpty
                ? null
                : _levelCtrl.text.trim(),
            note: _noteCtrl.text.trim().isEmpty
                ? null
                : _noteCtrl.text.trim(),
            days: _selectedDays.toList()..sort(),
          );
      ref.invalidate(studentDetailProvider(widget.athleteId));
      if (!mounted) return;
      final overlay = Overlay.maybeOf(context);
      Navigator.of(context).pop();
      if (overlay != null) {
        showRedesignToast(
          overlay.context,
          title: '¡Guardado exitosamente!',
          subtitle: 'Se han guardado los cambios',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back,
                color: RedesignColors.primario50),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cardio',
                style: TextStyle(
                  color: RedesignColors.primario50,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Metropolis',
                ),
              ),
              Text(
                'Para ${widget.studentName}',
                style: const TextStyle(
                  color: RedesignColors.primario300,
                  fontSize: 12,
                  fontFamily: 'Metropolis',
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Actividad ──────────────────────────────────────────────
              _SectionLabel(label: 'Actividad'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _activities.map((act) {
                  final selected = _activity == act;
                  return _SelectPill(
                    label: act,
                    selected: selected,
                    onTap: () =>
                        setState(() => _activity = selected ? null : act),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // ── Duración + Nivel ───────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Duración'),
                        const SizedBox(height: 8),
                        _FrostedInput(
                          controller: _durationCtrl,
                          hint: 'Ej: 30 min',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel(label: 'Nivel'),
                        const SizedBox(height: 8),
                        _FrostedInput(
                          controller: _levelCtrl,
                          hint: 'Ej: 4',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // ── Días ───────────────────────────────────────────────────
              _SectionLabel(label: 'Días'),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(7, (i) {
                  final dayNum = i + 1; // Mon=1 … Sun=7
                  final selected = _selectedDays.contains(dayNum);
                  return Padding(
                    padding: EdgeInsets.only(right: i < 6 ? 8 : 0),
                    child: _SelectPill(
                      label: _dayLabels[i],
                      selected: selected,
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedDays.remove(dayNum);
                        } else {
                          _selectedDays.add(dayNum);
                        }
                      }),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 22),

              // ── Nota ───────────────────────────────────────────────────
              _SectionLabel(label: 'Nota para el alumno (opcional)'),
              const SizedBox(height: 8),
              _FrostedInput(
                controller: _noteCtrl,
                hint: 'Escribí una nota...',
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              // ── Guardar button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.onActionPrimary,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers (private to this file)
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: RedesignColors.primario300,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFamily: 'Metropolis',
        letterSpacing: 0.3,
      ),
    );
  }
}

class _FrostedInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType keyboardType;

  const _FrostedInput({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: RedesignColors.primario50,
        fontSize: 15,
        fontFamily: 'Metropolis',
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: RedesignColors.primario400,
          fontFamily: 'Metropolis',
        ),
      ),
    );
  }
}

class _SelectPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1.0 : 0.4),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? RedesignColors.secundario900
                : RedesignColors.secundario300,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Metropolis',
          ),
        ),
      ),
    );
  }
}
