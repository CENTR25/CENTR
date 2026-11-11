import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../models/intake_schema.dart';
import '../../services/intake_schema_service.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

// ---------------------------------------------------------------------------
// Trainer intake form editor
// ---------------------------------------------------------------------------

class TrainerIntakeEditorScreen extends ConsumerStatefulWidget {
  const TrainerIntakeEditorScreen({super.key});

  @override
  ConsumerState<TrainerIntakeEditorScreen> createState() =>
      _TrainerIntakeEditorScreenState();
}

class _TrainerIntakeEditorScreenState
    extends ConsumerState<TrainerIntakeEditorScreen> {
  List<IntakeSectionDto> _sections = [];
  bool _loading = true;
  bool _saving = false;
  String? _trainerId;

  /// True when any athlete trained by this trainer has submitted a response.
  bool _keyLocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final trainerService = ref.read(trainerServiceProvider);
    final id = await trainerService.getTrainerId();
    if (!mounted) return;
    _trainerId = id;

    if (id == null) {
      setState(() => _loading = false);
      return;
    }

    final schemaService = ref.read(intakeSchemaServiceProvider);
    final sections = await schemaService.getMySchema(id);
    final anySubmitted = await schemaService.trainerAthleteHasSubmitted(id);
    if (!mounted) return;
    setState(() {
      _sections = sections
          .map(
            (s) => s.copyWith(
              fields: s.fields
                  .map((f) => f.copyWith(keyLocked: anySubmitted))
                  .toList(),
            ),
          )
          .toList();
      _keyLocked = anySubmitted;
      _loading = false;
    });
  }

  // -------------------------------------------------------------------------
  // Save / Reset
  // -------------------------------------------------------------------------

  Future<void> _save() async {
    final id = _trainerId;
    if (id == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(intakeSchemaServiceProvider).saveMySchema(id, _sections);
      if (!mounted) return;
      showRedesignToast(
        context,
        title: 'Formulario guardado',
        subtitle: 'Tus atletas verán el formulario actualizado.',
        icon: Icons.check_circle_outline_rounded,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      showRedesignToast(
        context,
        title: 'Error al guardar',
        subtitle: e.toString(),
        icon: Icons.error_outline_rounded,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        title: const Text('Restablecer al predeterminado',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Se reemplazará tu formulario personalizado con la versión actual '
          'del formulario global. ¿Continuar?',
          style: TextStyle(color: RedesignColors.primario300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: RedesignColors.primario300)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restablecer',
                style: TextStyle(color: RedesignColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _resetToAdmin();
  }

  Future<void> _resetToAdmin() async {
    final id = _trainerId;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      // Fetch current admin schema live and save as trainer's override.
      await ref
          .read(intakeSchemaServiceProvider)
          .resetMySchemaToAdminDefault(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'Error al restablecer',
        subtitle: e.toString(),
        icon: Icons.error_outline_rounded,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Section operations
  // -------------------------------------------------------------------------

  void _addSection() {
    setState(() {
      _sections.add(IntakeSectionDto(
        title: 'Nueva sección',
        iconName: 'badge_outlined',
        fields: [],
      ));
    });
  }

  void _removeSection(int sectionIndex) {
    final section = _sections[sectionIndex];
    final hasLocked = section.fields.any((f) => f.keyLocked);
    if (hasLocked) {
      _showLockedSectionWarning(() {
        setState(() => _sections.removeAt(sectionIndex));
      });
    } else {
      setState(() => _sections.removeAt(sectionIndex));
    }
  }

  void _showLockedSectionWarning(VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        title: const Text('Eliminar sección',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Esta sección contiene campos que ya tienen respuestas de atletas. '
          'Los datos existentes se conservarán en la base de datos pero '
          'dejarán de mostrarse en el formulario. ¿Continuar?',
          style: TextStyle(color: RedesignColors.primario300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: RedesignColors.primario300)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Eliminar',
                style: TextStyle(color: RedesignColors.danger)),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Field operations
  // -------------------------------------------------------------------------

  void _addField(int sectionIndex) {
    final key = 'campo_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      final updated = List<IntakeFieldDto>.from(_sections[sectionIndex].fields)
        ..add(IntakeFieldDto(
          key: key,
          label: 'Nuevo campo',
          type: IntakeFieldTypeDtoEnum.text,
          keyLocked: false,
        ));
      _sections[sectionIndex] =
          _sections[sectionIndex].copyWith(fields: updated);
    });
  }

  void _removeField(int sectionIndex, int fieldIndex) {
    final field = _sections[sectionIndex].fields[fieldIndex];
    if (field.keyLocked) {
      _showLockedFieldWarning(() {
        _doRemoveField(sectionIndex, fieldIndex);
      });
    } else {
      _doRemoveField(sectionIndex, fieldIndex);
    }
  }

  void _doRemoveField(int sectionIndex, int fieldIndex) {
    setState(() {
      final updated = List<IntakeFieldDto>.from(_sections[sectionIndex].fields)
        ..removeAt(fieldIndex);
      _sections[sectionIndex] =
          _sections[sectionIndex].copyWith(fields: updated);
    });
  }

  void _showLockedFieldWarning(VoidCallback onConfirm) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario700,
        title: const Text('Eliminar campo',
            style: TextStyle(color: Colors.white)),
        content: const Text(
          'Ya hay atletas que respondieron este campo. '
          'Los datos existentes se conservarán en la base de datos pero '
          'dejarán de mostrarse en el formulario. ¿Continuar?',
          style: TextStyle(color: RedesignColors.primario300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: RedesignColors.primario300)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Eliminar',
                style: TextStyle(color: RedesignColors.danger)),
          ),
        ],
      ),
    );
  }

  void _updateField(int si, int fi, IntakeFieldDto updated) {
    setState(() {
      final fields = List<IntakeFieldDto>.from(_sections[si].fields);
      fields[fi] = updated;
      _sections[si] = _sections[si].copyWith(fields: fields);
    });
  }

  void _updateSection(int si, IntakeSectionDto updated) {
    setState(() => _sections[si] = updated);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

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
            icon: const Icon(Icons.close_rounded,
                color: RedesignColors.primario50),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Personalizar formulario',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            if (!_loading) ...[
              IconButton(
                icon: const Icon(Icons.restart_alt_rounded,
                    color: RedesignColors.primario400),
                tooltip: 'Restablecer al predeterminado',
                onPressed: _confirmReset,
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.actionPrimary,
                          ),
                        )
                      : const Text(
                          'Guardar',
                          style: TextStyle(
                            color: RedesignColors.actionPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: RedesignColors.actionPrimary))
            : _trainerId == null
                ? const Center(
                    child: Text(
                      'No se pudo cargar el perfil de entrenador.',
                      style: TextStyle(color: RedesignColors.primario300),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _sections.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _sections.length) {
                        return _AddSectionButton(onTap: _addSection);
                      }
                      return _TrainerSectionCard(
                        sectionIndex: index,
                        section: _sections[index],
                        keyLocked: _keyLocked,
                        onSectionChanged: (s) => _updateSection(index, s),
                        onRemoveSection: () => _removeSection(index),
                        onAddField: () => _addField(index),
                        onRemoveField: (fi) => _removeField(index, fi),
                        onFieldChanged: (fi, f) => _updateField(index, fi, f),
                      );
                    },
                  ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section card (re-uses the same layout as the admin editor)
// ---------------------------------------------------------------------------

class _TrainerSectionCard extends StatefulWidget {
  final int sectionIndex;
  final IntakeSectionDto section;
  final bool keyLocked;
  final ValueChanged<IntakeSectionDto> onSectionChanged;
  final VoidCallback onRemoveSection;
  final VoidCallback onAddField;
  final ValueChanged<int> onRemoveField;
  final void Function(int, IntakeFieldDto) onFieldChanged;

  const _TrainerSectionCard({
    required this.sectionIndex,
    required this.section,
    required this.keyLocked,
    required this.onSectionChanged,
    required this.onRemoveSection,
    required this.onAddField,
    required this.onRemoveField,
    required this.onFieldChanged,
  });

  @override
  State<_TrainerSectionCard> createState() => _TrainerSectionCardState();
}

class _TrainerSectionCardState extends State<_TrainerSectionCard> {
  bool _expanded = true;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _subtitleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.section.title);
    _subtitleCtrl = TextEditingController(text: widget.section.subtitle ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                BorderRadius.vertical(top: const Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Icon(iconFromName(widget.section.iconName),
                      color: RedesignColors.actionPrimary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.section.title.isEmpty
                          ? 'Sin título'
                          : widget.section.title,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: RedesignColors.danger, size: 20),
                    onPressed: widget.onRemoveSection,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: RedesignColors.primario400,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: RedesignColors.primario600),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditorTextField(
                    label: 'Título de la sección',
                    controller: _titleCtrl,
                    onChanged: (v) => widget.onSectionChanged(
                        widget.section.copyWith(title: v)),
                  ),
                  const SizedBox(height: 10),
                  _EditorTextField(
                    label: 'Subtítulo (opcional)',
                    controller: _subtitleCtrl,
                    onChanged: (v) => widget.onSectionChanged(
                        widget.section.copyWith(
                            subtitle: v.isEmpty ? null : v)),
                  ),
                  const SizedBox(height: 10),
                  _IconPicker(
                    selected: widget.section.iconName,
                    onChanged: (name) => widget.onSectionChanged(
                        widget.section.copyWith(iconName: name)),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(widget.section.fields.length, (fi) {
                    return _TrainerFieldTile(
                      field: widget.section.fields[fi],
                      onRemove: () => widget.onRemoveField(fi),
                      onChanged: (f) => widget.onFieldChanged(fi, f),
                    );
                  }),
                  TextButton.icon(
                    onPressed: widget.onAddField,
                    icon: const Icon(Icons.add_circle_outline_rounded,
                        size: 18),
                    label: const Text('Agregar campo'),
                    style: TextButton.styleFrom(
                      foregroundColor: RedesignColors.actionPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Field tile (trainer version — identical logic to admin, separate class to
// avoid import coupling between feature directories)
// ---------------------------------------------------------------------------

class _TrainerFieldTile extends StatefulWidget {
  final IntakeFieldDto field;
  final VoidCallback onRemove;
  final ValueChanged<IntakeFieldDto> onChanged;

  const _TrainerFieldTile({
    required this.field,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_TrainerFieldTile> createState() => _TrainerFieldTileState();
}

class _TrainerFieldTileState extends State<_TrainerFieldTile> {
  bool _expanded = false;
  late final TextEditingController _labelCtrl;
  late final TextEditingController _keyCtrl;
  late final TextEditingController _helperCtrl;
  late final TextEditingController _placeholderCtrl;
  late final TextEditingController _optionsCtrl;

  @override
  void initState() {
    super.initState();
    _labelCtrl = TextEditingController(text: widget.field.label);
    _keyCtrl = TextEditingController(text: widget.field.key);
    _helperCtrl = TextEditingController(text: widget.field.helper ?? '');
    _placeholderCtrl =
        TextEditingController(text: widget.field.placeholder ?? '');
    _optionsCtrl =
        TextEditingController(text: widget.field.options.join('\n'));
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _keyCtrl.dispose();
    _helperCtrl.dispose();
    _placeholderCtrl.dispose();
    _optionsCtrl.dispose();
    super.dispose();
  }

  void _emit() {
    final options = _optionsCtrl.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    widget.onChanged(widget.field.copyWith(
      label: _labelCtrl.text.trim(),
      key: widget.field.keyLocked
          ? widget.field.key
          : _keyCtrl.text.trim(),
      helper: _helperCtrl.text.trim().isEmpty ? null : _helperCtrl.text.trim(),
      placeholder: _placeholderCtrl.text.trim().isEmpty
          ? null
          : _placeholderCtrl.text.trim(),
      options: options,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final showOptions = widget.field.type == IntakeFieldTypeDtoEnum.singleChoice ||
        widget.field.type == IntakeFieldTypeDtoEnum.multiChoice;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: RedesignColors.primario600,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.field.label.isEmpty
                          ? 'Campo sin nombre'
                          : widget.field.label,
                      style: const TextStyle(
                          color: RedesignColors.primario100, fontSize: 13),
                    ),
                  ),
                  if (widget.field.keyLocked)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: 'Clave bloqueada (ya tiene respuestas)',
                        child: Icon(Icons.lock_outline_rounded,
                            color: RedesignColors.primario400, size: 16),
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: RedesignColors.danger, size: 18),
                    onPressed: widget.onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: RedesignColors.primario400,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: RedesignColors.primario500),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EditorTextField(
                    label: 'Etiqueta',
                    controller: _labelCtrl,
                    onChanged: (_) => _emit(),
                  ),
                  const SizedBox(height: 8),
                  if (widget.field.keyLocked)
                    _ReadOnlyKeyRow(fieldKey: widget.field.key)
                  else
                    _EditorTextField(
                      label: 'Clave (key)',
                      controller: _keyCtrl,
                      onChanged: (_) => _emit(),
                      hint: 'snake_case único',
                    ),
                  const SizedBox(height: 8),
                  _TypeDropdown(
                    value: widget.field.type,
                    onChanged: (t) =>
                        widget.onChanged(widget.field.copyWith(type: t)),
                  ),
                  const SizedBox(height: 8),
                  if (showOptions) ...[
                    _EditorTextField(
                      label: 'Opciones (una por línea)',
                      controller: _optionsCtrl,
                      onChanged: (_) => _emit(),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 8),
                    _ToggleRow(
                      label: 'Permitir "Otro"',
                      value: widget.field.allowOther,
                      onChanged: (v) =>
                          widget.onChanged(widget.field.copyWith(allowOther: v)),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _EditorTextField(
                    label: 'Texto de ayuda (opcional)',
                    controller: _helperCtrl,
                    onChanged: (_) => _emit(),
                  ),
                  const SizedBox(height: 8),
                  _EditorTextField(
                    label: 'Placeholder (opcional)',
                    controller: _placeholderCtrl,
                    onChanged: (_) => _emit(),
                  ),
                  const SizedBox(height: 8),
                  _ToggleRow(
                    label: 'Obligatorio',
                    value: widget.field.required,
                    onChanged: (v) =>
                        widget.onChanged(widget.field.copyWith(required: v)),
                  ),
                  if (widget.field.type == IntakeFieldTypeDtoEnum.longText) ...[
                    const SizedBox(height: 8),
                    _ToggleRow(
                      label: 'Permite nota de voz',
                      value: widget.field.allowAudio,
                      onChanged: (v) =>
                          widget.onChanged(widget.field.copyWith(allowAudio: v)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper widgets (duplicated from admin editor to keep directories
// self-contained and avoid cross-feature imports)
// ---------------------------------------------------------------------------

class _AddSectionButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSectionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('Agregar sección'),
        style: OutlinedButton.styleFrom(
          foregroundColor: RedesignColors.actionPrimary,
          side: const BorderSide(color: RedesignColors.actionPrimary),
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

class _EditorTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? hint;
  final int maxLines;

  const _EditorTextField({
    required this.label,
    required this.controller,
    this.onChanged,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: RedesignColors.primario400, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: RedesignColors.primario500, fontSize: 13),
            filled: true,
            fillColor: RedesignColors.primario800,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: RedesignColors.actionPrimary),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyKeyRow extends StatelessWidget {
  final String fieldKey;
  const _ReadOnlyKeyRow({required this.fieldKey});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Clave (key)',
                style: TextStyle(
                    color: RedesignColors.primario400, fontSize: 11)),
            const SizedBox(width: 6),
            const Icon(Icons.lock_outline_rounded,
                color: RedesignColors.primario400, size: 12),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: RedesignColors.primario800.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Text(
            fieldKey,
            style: const TextStyle(
                color: RedesignColors.primario400, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _IconPicker extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _IconPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ícono',
            style: TextStyle(
                color: RedesignColors.primario400, fontSize: 11)),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: kIntakeIconNames.map((name) {
              final isSelected = name == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(name),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? RedesignColors.actionPrimary
                              .withValues(alpha: 0.2)
                          : RedesignColors.primario800,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? RedesignColors.actionPrimary
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Icon(
                      iconFromName(name),
                      color: isSelected
                          ? RedesignColors.actionPrimary
                          : RedesignColors.primario300,
                      size: 20,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TypeDropdown extends StatelessWidget {
  final IntakeFieldTypeDtoEnum value;
  final ValueChanged<IntakeFieldTypeDtoEnum> onChanged;

  const _TypeDropdown({required this.value, required this.onChanged});

  static const _labels = <IntakeFieldTypeDtoEnum, String>{
    IntakeFieldTypeDtoEnum.text: 'Texto corto',
    IntakeFieldTypeDtoEnum.longText: 'Texto largo',
    IntakeFieldTypeDtoEnum.number: 'Número',
    IntakeFieldTypeDtoEnum.singleChoice: 'Opción única',
    IntakeFieldTypeDtoEnum.multiChoice: 'Opción múltiple',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tipo',
            style: TextStyle(
                color: RedesignColors.primario400, fontSize: 11)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: RedesignColors.primario800,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<IntakeFieldTypeDtoEnum>(
              value: value,
              isExpanded: true,
              dropdownColor: RedesignColors.primario700,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
              items: IntakeFieldTypeDtoEnum.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(_labels[t] ?? t.name),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: RedesignColors.primario200, fontSize: 13)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: RedesignColors.actionPrimary,
          activeThumbColor: Colors.white,
          inactiveThumbColor: RedesignColors.primario400,
          inactiveTrackColor: RedesignColors.primario600,
        ),
      ],
    );
  }
}
