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
  const NuevoPlanScreen({super.key});

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

  // ── Meal-time slots: internal key → Spanish label ─────────────────────────
  // These MUST match the keys in kMealTimeLabels / kMealTimeOrder so that
  // _DayContent grouping and _NuevaComidaSheet time pills line up perfectly.
  static const _momentosKeys = [
    'breakfast',
    'lunch',
    'afternoon_snack',
    'dinner',
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _calController  = TextEditingController();
  final _daysController = TextEditingController(text: '7');

  String? _selectedObjective;

  // All 4 slots selected by default.
  final Set<String> _selectedMoments = {'breakfast', 'lunch', 'afternoon_snack', 'dinner'};

  // Cover photo
  Uint8List? _photoBytes;
  String _photoExt = 'jpg';

  bool _isSaving = false;

  @override
  void dispose() {
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
      final days = int.tryParse(_daysController.text.trim()) ?? 7;

      final newPlan = await trainerService.createMealPlan(
        title: name,
        objective: _selectedObjective,
        targetCalories: kcal,
        days: days,
        mealTimes: _selectedMoments.isEmpty ? null : _selectedMoments.toList(),
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
            content: Text('Error al crear el plan: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }

  // ── Pill builders ─────────────────────────────────────────────────────────

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

  Widget _buildMomentoPill(String key) {
    final selected = _selectedMoments.contains(key);
    final label    = kMealTimeLabels[key] ?? key;
    return GestureDetector(
      onTap: () => setState(() {
        if (selected) {
          _selectedMoments.remove(key);
        } else {
          _selectedMoments.add(key);
        }
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
                    'Nuevo plan',
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
                        painter: _photoBytes == null
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
                                : null,
                          ),
                          child: _photoBytes == null
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

              // ── Momentos del día ───────────────────────────────────────────
              Text(
                'Momentos del día',
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
                    for (var i = 0; i < _momentosKeys.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      _buildMomentoPill(_momentosKeys[i]),
                    ],
                  ],
                ),
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
                      : const Text('Continuar a comidas'),
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
