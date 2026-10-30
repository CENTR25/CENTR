import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../shared/redesign_toast.dart';
import 'admin_redesign_sheet.dart';

/// "Agregar ejercicio" modal (Figma Four Batch). Multi-select muscle groups:
/// the first selected becomes muscle_group, the rest secondary_muscles.
/// Pass [exercise] to edit an existing global exercise.
class AdminAddExerciseSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? exercise;

  const AdminAddExerciseSheet({super.key, this.exercise});

  @override
  ConsumerState<AdminAddExerciseSheet> createState() =>
      _AdminAddExerciseSheetState();
}

class _AdminAddExerciseSheetState
    extends ConsumerState<AdminAddExerciseSheet> {
  static const _muscles = [
    'Piernas',
    'Brazos',
    'Pecho',
    'Espalda',
    'Glúteos',
    'Abdominales',
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _equipmentCtrl;
  final _selected = <String>{};
  bool _loading = false;

  bool get _isEdit => widget.exercise != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    _nameCtrl = TextEditingController(text: e?['name']?.toString() ?? '');
    _categoryCtrl =
        TextEditingController(text: e?['category']?.toString() ?? '');
    final equipment = e?['equipment'];
    _equipmentCtrl = TextEditingController(
      text: equipment is List ? equipment.join(', ') : '',
    );
    // Prefill muscle selection: primary first, then secondaries.
    final primary = e?['muscle_group']?.toString();
    if (primary != null && primary.isNotEmpty) _selected.add(primary);
    final secondary = e?['secondary_muscles'];
    if (secondary is List) {
      for (final s in secondary) {
        _selected.add(s.toString());
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _equipmentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _selected.isEmpty) {
      showRedesignToast(context,
          title: 'Faltan datos',
          subtitle: 'Ingresá el nombre y al menos un grupo muscular.',
          icon: Icons.error_outline_rounded);
      return;
    }
    setState(() => _loading = true);
    // Preserve selection order: muscles list order, keeping only selected.
    final ordered = _muscles.where(_selected.contains).toList();
    final primary = ordered.first;
    final secondaries = ordered.skip(1).toList();
    final equipment = _equipmentCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final category =
        _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();
    try {
      final admin = ref.read(adminServiceProvider);
      if (_isEdit) {
        await admin.updateGlobalExercise(
          widget.exercise!['id'] as String,
          name: _nameCtrl.text.trim(),
          muscleGroup: primary,
          secondaryMuscles: secondaries,
          category: category,
          equipment: equipment,
        );
      } else {
        await admin.createGlobalExercise(
          name: _nameCtrl.text.trim(),
          muscleGroup: primary,
          secondaryMuscles: secondaries,
          category: category,
          equipment: equipment,
        );
      }
      ref.invalidate(globalExercisesProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: _isEdit ? 'Ejercicio actualizado' : 'Ejercicio creado',
        subtitle: 'Los cambios se guardaron.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(context,
          title: 'No se pudo guardar',
          subtitle: '$e',
          icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRedesignSheet(
      children: [
        Text(
          _isEdit ? 'Editar ejercicio' : 'Agregar ejercicio',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _nameCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(hintText: 'Nombre'),
        ),
        const SizedBox(height: 18),
        Text(
          'Grupo muscular',
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Podés marcar varios',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _muscles) _muscleChip(m),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _categoryCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(hintText: 'Categoría (opcional)'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _equipmentCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'Equipamiento (opcional)',
          ),
        ),
        const SizedBox(height: 20),
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
                : Text(_isEdit ? 'Guardar cambios' : 'Crear ejercicio'),
          ),
        ),
      ],
    );
  }

  Widget _muscleChip(String label) {
    final selected = _selected.contains(label);
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selected.remove(label);
        } else {
          _selected.add(label);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.actionPrimary
              : RedesignColors.primario700,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? RedesignColors.actionPrimary
                : RedesignColors.primario600,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.onActionPrimary
                : RedesignColors.primario50,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
