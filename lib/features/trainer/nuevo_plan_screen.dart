import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/meal_times.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/storage_service.dart';
import '../../services/trainer_service.dart';
import 'meal_plan_detail_screen.dart';

// ---------------------------------------------------------------------------
// NuevoPlanScreen — full-screen meal-plan creation
// ---------------------------------------------------------------------------

class NuevoPlanScreen extends ConsumerStatefulWidget {
  /// When set, the screen edits this plan (from getMealPlan, incl. items)
  /// instead of creating one. Pops `true` after saving.
  final Map<String, dynamic>? editPlan;

  const NuevoPlanScreen({super.key, this.editPlan});

  @override
  ConsumerState<NuevoPlanScreen> createState() => _NuevoPlanScreenState();
}

class _NuevoPlanScreenState extends ConsumerState<NuevoPlanScreen> {
  // ── Objectives (Spanish labels stored verbatim) ────────────────────────────
  static const _objectives = [
    'Déficit',
    'Ganar masa muscular',
    'Rendimiento',
    'Salud',
    'Mantener',
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _calController  = TextEditingController();
  final _daysController = TextEditingController(text: '7');

  String? _selectedObjective;

  final _noteController = TextEditingController();

  // Ordered meal moments (stable key + editable label) and their controllers.
  late List<MealSlot> _slots;
  final Map<String, TextEditingController> _slotCtrls = {};

  // One label controller per day (index i = day i+1). Empty = "Día N".
  final List<TextEditingController> _dayCtrls = [];

  Map<String, dynamic>? get _edit => widget.editPlan;
  String? _existingImageUrl;

  // Cover photo
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final p = _edit;
    _slots = mealSlotsOf(p);
    if (p != null) {
      _nameController.text = (p['title'] as String?) ?? '';
      final kcal = (p['target_calories'] as num?)?.toInt();
      if (kcal != null) _calController.text = '$kcal';
      _daysController.text = '${planDayCount(p)}';
      _selectedObjective = p['objective'] as String?;
      _noteController.text = (p['note'] as String?) ?? '';
      _existingImageUrl = p['image_url'] as String?;
    }
    for (final s in _slots) {
      _slotCtrls[s.key] = TextEditingController(text: s.label);
    }
    _syncDayCtrls();
  }

  int get _daysCount =>
      (int.tryParse(_daysController.text.trim()) ?? 7).clamp(1, 7);

  /// Resize day-label controllers to the days field (keeps typed text).
  void _syncDayCtrls() {
    final n = _daysCount;
    while (_dayCtrls.length < n) {
      final i = _dayCtrls.length + 1;
      final existing = _edit == null ? '' : _rawDayLabel(i);
      _dayCtrls.add(TextEditingController(text: existing));
    }
    while (_dayCtrls.length > n) {
      _dayCtrls.removeLast().dispose();
    }
  }

  String _rawDayLabel(int day) {
    final l = dayLabelOf(_edit, day);
    return l == 'Día $day' ? '' : l;
  }

  void _applyDayPreset(String preset) {
    setState(() {
      if (preset == 'weekdays') {
        _daysController.text = '7';
        _syncDayCtrls();
        for (var i = 0; i < 7; i++) {
          _dayCtrls[i].text = kWeekdayNames[i];
        }
      } else if (preset == 'split') {
        _daysController.text = '2';
        _syncDayCtrls();
        _dayCtrls[0].text = 'Semana';
        _dayCtrls[1].text = 'Fin de semana';
      } else {
        for (final c in _dayCtrls) {
          c.text = '';
        }
      }
    });
  }

  // ── Meal moments editing ──────────────────────────────────────────────────

  void _addSlot() {
    setState(() {
      final s = MealSlot(newMealSlotKey(), '');
      _slots = [..._slots, s];
      _slotCtrls[s.key] = TextEditingController();
    });
  }

  void _moveSlot(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _slots.length) return;
    setState(() {
      final l = [..._slots];
      final t = l.removeAt(i);
      l.insert(j, t);
      _slots = l;
    });
  }

  bool _slotHasItems(String key) {
    for (final it in (_edit?['meal_plan_items'] as List?) ?? const []) {
      if (it is Map && it['time_of_day'] == key) return true;
    }
    return false;
  }

  void _removeSlot(int i) {
    final s = _slots[i];
    if (_slots.length <= 1) return;
    if (_slotHasItems(s.key)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ese momento tiene comidas. Eliminá las comidas primero.'),
        backgroundColor: RedesignColors.danger,
      ));
      return;
    }
    setState(() {
      _slots = [..._slots]..removeAt(i);
      _slotCtrls.remove(s.key)?.dispose();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final c in _slotCtrls.values) {
      c.dispose();
    }
    for (final c in _dayCtrls) {
      c.dispose();
    }
    _nameController.dispose();
    _calController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  // ── Image pick (web-safe) ─────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      setState(() {
        _photoBytes = bytes;
        _photoExt   = ext.toLowerCase();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo seleccionar la imagen')),
        );
      }
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El nombre del plan es requerido.'),
          backgroundColor: RedesignColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final trainerService = ref.read(trainerServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      // Upload cover if picked
      String? imageUrl;
      if (_photoBytes != null) {
        final userId = trainerService.currentUserId ?? '';
        imageUrl = await storageService.uploadMealPlanCoverBytes(
          _photoBytes!,
          _photoExt,
          userId,
        );
      }

      final kcal = int.tryParse(_calController.text.trim());
      final days = _daysCount;
      final slots = [
        for (var i = 0; i < _slots.length; i++)
          _slots[i]
              .withLabel(_slotCtrls[_slots[i].key]!.text.trim().isEmpty
                  ? 'Comida ${i + 1}'
                  : _slotCtrls[_slots[i].key]!.text.trim())
              .toJson(),
      ];
      final labels = [for (final c in _dayCtrls) c.text.trim()];
      final dayLabels = labels.every((l) => l.isEmpty) ? null : labels;
      final note = _noteController.text.trim();

      if (_edit != null) {
        // Cannot drop days that still hold meals.
        var maxItemDay = 0;
        for (final it in (_edit!['meal_plan_items'] as List?) ?? const []) {
          final d = it is Map ? (it['day_number'] as num?)?.toInt() : null;
          if (d != null && d > maxItemDay) maxItemDay = d;
        }
        if (days < maxItemDay) {
          throw 'El día $maxItemDay tiene comidas. Eliminalas antes de reducir los días.';
        }
        await trainerService.updateMealPlanDetails(
          planId: _edit!['id'] as String,
          title: name,
          objective: _selectedObjective,
          targetCalories: kcal,
          days: days,
          mealSlots: [for (final m in slots) Map<String, String>.from(m)],
          dayLabels: dayLabels,
          note: note,
          imageUrl: imageUrl,
        );
        ref.invalidate(myMealPlansProvider);
        ref.invalidate(mealPlanDetailProvider(_edit!['id'] as String));
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      final newPlan = await trainerService.createMealPlan(
        title: name,
        objective: _selectedObjective,
        targetCalories: kcal,
        days: days,
        mealTimes: [for (final m in slots) m['key']!],
        mealSlots: [for (final m in slots) Map<String, String>.from(m)],
        dayLabels: dayLabels,
        note: note,
        imageUrl: imageUrl,
      );

      ref.invalidate(myMealPlansProvider);

      if (!mounted) return;

      final newId = newPlan['id'] as String;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MealPlanDetailScreen(
            planId: newId,
            planName: name,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_edit != null ? 'Error al guardar: $e' : 'Error al crear el plan: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

  // ── Pill builders ─────────────────────────────────────────────────────────

  Widget _presetPill(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: RedesignColors.secundario300.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
            border: Border.all(
                color: RedesignColors.secundario300.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: RedesignType.buttonSm.copyWith(
                color: RedesignColors.secundario300,
                fontWeight: FontWeight.w600),
          ),
        ),
      );

  Widget _buildObjectivePill(String label) {
    final selected = _selectedObjective == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedObjective = selected ? null : label;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: RedesignColors.primario700.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: selected
                ? RedesignColors.secundario300
                : RedesignColors.primario500.withValues(alpha: 0.5),
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.secundario300
                : RedesignColors.primario100,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top.clamp(24.0, 80.0) + 18,
            20,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded,
                          color: RedesignColors.primario50, size: 26),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    _edit != null ? 'Editar plan' : 'Nuevo plan',
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── Photo box + name ───────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square dashed photo box (transparent, no label)
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: CustomPaint(
                        painter: (_photoBytes == null &&
                                (_existingImageUrl == null ||
                                    _existingImageUrl!.isEmpty))
                            ? _DashedRRectPainter(
                                color: RedesignColors.primario300
                                    .withValues(alpha: 0.7),
                                radius: 22,
                              )
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            image: _photoBytes != null
                                ? DecorationImage(
                                    image: MemoryImage(_photoBytes!),
                                    fit: BoxFit.cover,
                                  )
                                : (_existingImageUrl != null &&
                                        _existingImageUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(_existingImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (_photoBytes == null &&
                                  (_existingImageUrl == null ||
                                      _existingImageUrl!.isEmpty))
                              ? const Center(
                                  child: Icon(
                                    Icons.add_a_photo_outlined,
                                    color: RedesignColors.primario300,
                                    size: 30,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Name column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Nombre',
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario300,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Recomposición',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // ── Objetivo ───────────────────────────────────────────────────
              Text(
                'Objetivo',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    for (var i = 0; i < _objectives.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildObjectivePill(_objectives[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Calories + Days row ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calorías x día',
                          style: RedesignType.label.copyWith(
                            color: RedesignColors.primario300,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _calController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                          ),
                          decoration: InputDecoration(
                            hintText: '2000',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Align(
                                widthFactor: 1.0,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  'kcal',
                                  style: RedesignType.label.copyWith(
                                    color: RedesignColors.primario400,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Días',
                          style: RedesignType.label.copyWith(
                            color: RedesignColors.primario300,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _daysController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                          ),
                          onChanged: (_) => setState(_syncDayCtrls),
                          decoration: const InputDecoration(
                            hintText: '7',
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Nombres de los días ────────────────────────────────────────
              Text(
                'Nombre de los días',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dejá vacío para usar "Día 1, Día 2...".',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario400),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _presetPill('Lunes a Domingo', () => _applyDayPreset('weekdays')),
                  _presetPill('Semana / Fin de semana', () => _applyDayPreset('split')),
                  _presetPill('Día 1, Día 2...', () => _applyDayPreset('generic')),
                ],
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _dayCtrls.length; i++) ...[
                TextField(
                  controller: _dayCtrls[i],
                  style: RedesignType.bodySm
                      .copyWith(color: RedesignColors.primario50),
                  decoration: InputDecoration(hintText: 'Día ${i + 1}'),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 16),

              // ── Momentos del día ───────────────────────────────────────────
              Text(
                'Momentos del día',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < _slots.length; i++) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: ValueKey(_slots[i].key),
                        controller: _slotCtrls[_slots[i].key],
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario50),
                        decoration: InputDecoration(hintText: 'Comida ${i + 1}'),
                      ),
                    ),
                    IconButton(
                      onPressed: i == 0 ? null : () => _moveSlot(i, -1),
                      icon: const Icon(Icons.keyboard_arrow_up_rounded),
                      color: RedesignColors.secundario300,
                      tooltip: 'Subir',
                    ),
                    IconButton(
                      onPressed:
                          i == _slots.length - 1 ? null : () => _moveSlot(i, 1),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      color: RedesignColors.secundario300,
                      tooltip: 'Bajar',
                    ),
                    IconButton(
                      onPressed: _slots.length <= 1 ? null : () => _removeSlot(i),
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: RedesignColors.danger,
                      tooltip: 'Quitar',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addSlot,
                  style: TextButton.styleFrom(
                    foregroundColor: RedesignColors.secundario300,
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar momento'),
                ),
              ),
              const SizedBox(height: 24),

              // ── Nota del plan ──────────────────────────────────────────────
              Text(
                'Nota del plan',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Se muestra arriba del plan al alumno. Ej: "Recordá que los pesos son en crudo".',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario400),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 3,
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: const InputDecoration(hintText: 'Nota (opcional)'),
              ),
              const SizedBox(height: 36),

              // ── Continue button ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.onActionPrimary,
                          ),
                        )
                      : Text(_edit != null ? 'Guardar cambios' : 'Continuar a comidas'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed rounded-rect border — the "add photo" box (Figma).
class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedRRectPainter({required this.color, this.radius = 16});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final next = (dist + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(dist, next), paint);
        dist = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}
