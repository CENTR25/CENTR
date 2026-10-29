import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';
import 'student_detail_screen.dart';

// ---------------------------------------------------------------------------
// Supplements List Screen
// Trainer-facing list + editor for structured supplements.
// ---------------------------------------------------------------------------

class SupplementsListScreen extends ConsumerStatefulWidget {
  final String athleteId;
  final String studentName;

  const SupplementsListScreen({
    super.key,
    required this.athleteId,
    required this.studentName,
  });

  @override
  ConsumerState<SupplementsListScreen> createState() =>
      _SupplementsListScreenState();
}

class _SupplementsListScreenState
    extends ConsumerState<SupplementsListScreen> {
  // 0 = Diaria, 1 = Química
  int _categoryIndex = 0;

  String get _currentCategory =>
      _categoryIndex == 0 ? 'diaria' : 'quimica';

  // Quick-add preset names (always use current category).
  static const _quickNames = ['Omega 3', 'Multivitamínico', 'Cafeína'];

  void _openEditor({Map<String, dynamic>? existing, String? prefillName}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SupplementEditorSheet(
        athleteId: widget.athleteId,
        category: _currentCategory,
        existing: existing,
        prefillName: prefillName,
        onSaved: () {
          ref.invalidate(athleteSupplementsProvider(widget.athleteId));
          ref.invalidate(studentDetailProvider(widget.athleteId));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplementsAsync =
        ref.watch(athleteSupplementsProvider(widget.athleteId));

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
                'Editar suplementación',
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Category pill toggle ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  _FilterPill(
                    label: 'Diaria',
                    selected: _categoryIndex == 0,
                    onTap: () =>
                        setState(() => _categoryIndex = 0),
                  ),
                  const SizedBox(width: 10),
                  _FilterPill(
                    label: 'Química',
                    selected: _categoryIndex == 1,
                    onTap: () =>
                        setState(() => _categoryIndex = 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── List ─────────────────────────────────────────────────
            Expanded(
              child: supplementsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: RedesignColors.actionPrimary,
                  ),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: const TextStyle(
                      color: RedesignColors.danger,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                ),
                data: (all) {
                  final filtered = all
                      .where((s) => s['category'] == _currentCategory)
                      .toList();

                  return ListView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 0, 20, 120),
                    children: [
                      if (filtered.isEmpty)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'Sin suplementos',
                            style: TextStyle(
                              color: RedesignColors.primario400,
                              fontFamily: 'Metropolis',
                              fontStyle: FontStyle.italic,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      for (final supp in filtered) ...[
                        _SupplementCard(
                          supplement: supp,
                          onTap: () => _openEditor(existing: supp),
                        ),
                        const SizedBox(height: 10),
                      ],

                      const SizedBox(height: 18),

                      // "+ Agregar suplemento"
                      OutlinedButton.icon(
                        onPressed: () => _openEditor(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Agregar suplemento'),
                      ),

                      const SizedBox(height: 20),

                      // Quick-add chips
                      Text(
                        'Agregar rápido',
                        style: TextStyle(
                          color: RedesignColors.primario300,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickNames.map((name) {
                          return GestureDetector(
                            onTap: () =>
                                _openEditor(prefillName: name),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: RedesignColors.secundario300
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                    RedesignRadius.buttonSm),
                                border: Border.all(
                                  color: RedesignColors.secundario300
                                      .withValues(alpha: 0.4),
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      color:
                                          RedesignColors.secundario300,
                                      size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      color:
                                          RedesignColors.secundario300,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Metropolis',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),

        // ── Bottom mint "Guardar" button (pops — data persisted individually) ──
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Guardar'),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single supplement card
// ---------------------------------------------------------------------------

class _SupplementCard extends StatelessWidget {
  final Map<String, dynamic> supplement;
  final VoidCallback onTap;

  const _SupplementCard({
    required this.supplement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (supplement['name'] as String?) ?? 'Suplemento';
    final dose = (supplement['dose'] as String?) ?? '';
    final unit = (supplement['unit'] as String?) ?? '';
    final timingList = (supplement['timing'] as List?) ?? [];
    final firstTiming = timingList.isNotEmpty
        ? _timingLabel(timingList.first.toString())
        : '';
    final summary = [
      if (dose.isNotEmpty || unit.isNotEmpty) '$dose$unit',
      if (firstTiming.isNotEmpty) firstTiming,
    ].join(' · ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius:
              BorderRadius.circular(RedesignRadius.buttonLg),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: RedesignColors.primario50,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      style: const TextStyle(
                        color: RedesignColors.primario400,
                        fontSize: 12,
                        fontFamily: 'Metropolis',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: RedesignColors.primario500,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  String _timingLabel(String key) {
    const map = {
      'al_despertar': 'Al despertar',
      'con_comidas': 'Con comidas',
      'post_entreno': 'Post entreno',
      'antes_dormir': 'Antes de dormir',
      'pre_entreno': 'Pre entreno',
    };
    return map[key] ?? key;
  }
}

// ---------------------------------------------------------------------------
// Supplement editor bottom sheet
// ---------------------------------------------------------------------------

class _SupplementEditorSheet extends ConsumerStatefulWidget {
  final String athleteId;
  final String category;
  final Map<String, dynamic>? existing;
  final String? prefillName;
  final VoidCallback onSaved;

  const _SupplementEditorSheet({
    required this.athleteId,
    required this.category,
    this.existing,
    this.prefillName,
    required this.onSaved,
  });

  @override
  ConsumerState<_SupplementEditorSheet> createState() =>
      _SupplementEditorSheetState();
}

class _SupplementEditorSheetState
    extends ConsumerState<_SupplementEditorSheet> {
  static const _units = ['g', 'mg', 'ml', 'caps'];
  static const _timingOptions = [
    ('al_despertar', 'Al despertar'),
    ('con_comidas', 'Con comidas'),
    ('post_entreno', 'Post entreno'),
    ('antes_dormir', 'Antes de dormir'),
    ('pre_entreno', 'Pre entreno'),
  ];
  static const _daysOptions = [
    ('todos', 'Todos los días'),
    ('entreno', 'Días de entreno'),
    ('medio', 'Día por medio'),
  ];

  late final TextEditingController _nameCtrl;
  late final TextEditingController _doseCtrl;
  late final TextEditingController _noteCtrl;
  late String? _unit;
  late Set<String> _timing;
  late String? _days;
  bool _loading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(
      text: e?['name'] as String? ?? widget.prefillName ?? '',
    );
    _doseCtrl =
        TextEditingController(text: e?['dose'] as String? ?? '');
    _noteCtrl =
        TextEditingController(text: e?['note'] as String? ?? '');
    _unit = e?['unit'] as String?;
    final rawTiming = e?['timing'] as List?;
    _timing = rawTiming != null
        ? Set<String>.from(rawTiming.map((t) => t.toString()))
        : {};
    _days = e?['days'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá un nombre'),
          backgroundColor: RedesignColors.danger,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'athlete_id': widget.athleteId,
        'category': widget.category,
        'name': name,
        'dose': _doseCtrl.text.trim().isEmpty
            ? null
            : _doseCtrl.text.trim(),
        'unit': _unit,
        'timing': _timing.toList(),
        'days': _days,
        'note': _noteCtrl.text.trim().isEmpty
            ? null
            : _noteCtrl.text.trim(),
      };
      final id = widget.existing?['id'] as String?;
      if (id != null) data['id'] = id;

      await ref.read(trainerServiceProvider).upsertAthleteSupplement(data);
      widget.onSaved();

      if (!mounted) return;
      final overlay = Overlay.maybeOf(context);
      Navigator.of(context).pop();
      if (overlay != null) {
        showRedesignToast(
          overlay.context,
          title: _isEditing
              ? '¡Guardado exitosamente!'
              : '¡Agregado exitosamente!',
          subtitle: _isEditing
              ? 'Se han guardado los cambios'
              : 'Se ha agregado',
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

  Future<void> _delete() async {
    final id = widget.existing?['id'] as String?;
    if (id == null) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(trainerServiceProvider)
          .deleteAthleteSupplement(id);
      widget.onSaved();
      if (!mounted) return;
      Navigator.of(context).pop();
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
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            RedesignColors.primario900,
            RedesignColors.secundario900,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50
                        .withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Close X
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: RedesignColors.primario300, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Title
              Text(
                _isEditing
                    ? (widget.existing?['name'] as String? ??
                        'Suplemento')
                    : 'Nuevo suplemento',
                style: const TextStyle(
                  color: RedesignColors.primario50,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Metropolis',
                ),
              ),
              const SizedBox(height: 20),

              // ── Nombre ──────────────────────────────────────────────
              _SheetLabel(label: 'Nombre'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(
                  color: RedesignColors.primario50,
                  fontFamily: 'Metropolis',
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ej: Creatina',
                  hintStyle: TextStyle(
                    color: RedesignColors.primario400,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ── Dosis + Unidad ────────────────────────────────────
              _SheetLabel(label: 'Dosis'),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _doseCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                        color: RedesignColors.primario50,
                        fontFamily: 'Metropolis',
                        fontSize: 15,
                      ),
                      decoration: const InputDecoration(
                        hintText: '5',
                        hintStyle: TextStyle(
                          color: RedesignColors.primario400,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _units.map((u) {
                        final selected = _unit == u;
                        return _SheetPill(
                          label: u,
                          selected: selected,
                          onTap: () => setState(
                              () => _unit = selected ? null : u),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Cuándo (timing multi-select) ─────────────────────
              _SheetLabel(label: 'Cuándo'),
              const SizedBox(height: 4),
              Text(
                'Podés marcar varios',
                style: TextStyle(
                  color: RedesignColors.primario400,
                  fontSize: 12,
                  fontFamily: 'Metropolis',
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timingOptions.map((opt) {
                  final selected = _timing.contains(opt.$1);
                  return _SheetPill(
                    label: opt.$2,
                    selected: selected,
                    onTap: () => setState(() {
                      if (selected) {
                        _timing.remove(opt.$1);
                      } else {
                        _timing.add(opt.$1);
                      }
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // ── Días (single-select) ─────────────────────────────
              _SheetLabel(label: 'Días'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _daysOptions.map((opt) {
                  final selected = _days == opt.$1;
                  return _SheetPill(
                    label: opt.$2,
                    selected: selected,
                    onTap: () => setState(
                        () => _days = selected ? null : opt.$1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),

              // ── Nota ────────────────────────────────────────────
              _SheetLabel(label: 'Nota (opcional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                maxLines: 3,
                style: const TextStyle(
                  color: RedesignColors.primario50,
                  fontFamily: 'Metropolis',
                  fontSize: 15,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ej: Tomar con agua...',
                  hintStyle: TextStyle(
                    color: RedesignColors.primario400,
                    fontFamily: 'Metropolis',
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Listo button ─────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RedesignColors.primario800,
                    foregroundColor: RedesignColors.primario50,
                    shape: RoundedRectangleBorder(
                      borderRadius: RedesignRadius.buttonLgBr,
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.primario50,
                          ),
                        )
                      : const Text(
                          'Listo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Metropolis',
                          ),
                        ),
                ),
              ),

              // ── Eliminar (edit mode only) ─────────────────────────
              if (_isEditing) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: RedesignColors.danger,
                    ),
                    child: const Text(
                      'Eliminar',
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet helpers (private)
// ---------------------------------------------------------------------------

class _SheetLabel extends StatelessWidget {
  final String label;
  const _SheetLabel({required this.label});

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

class _SheetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetPill({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.10),
          borderRadius:
              BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1.0 : 0.35),
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

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
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
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.12),
          borderRadius:
              BorderRadius.circular(RedesignRadius.buttonSm),
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
