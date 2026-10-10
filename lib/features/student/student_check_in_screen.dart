import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';
import 'student_check_in_history_screen.dart';
import 'student_routine_screen.dart';
import 'student_meal_plan_screen.dart';
import 'widgets/student_bottom_nav.dart';

class StudentCheckInScreen extends ConsumerStatefulWidget {
  const StudentCheckInScreen({super.key});

  @override
  ConsumerState<StudentCheckInScreen> createState() =>
      _StudentCheckInScreenState();
}

class _ImageData {
  final Uint8List bytes;
  final String extension;
  _ImageData(this.bytes, this.extension);
}

class _StudentCheckInScreenState extends ConsumerState<StudentCheckInScreen> {
  final TextEditingController _commentController = TextEditingController();
  final List<_ImageData> _selectedImages = [];
  bool _isLoading = false;
  bool _submitted = false;
  Map<String, dynamic>? _formData;
  final Map<String, dynamic> _formResponses = {};
  DateTime _selectedDate = DateTime.now();

  static const int _maxPhotos = 10;

  @override
  void initState() {
    super.initState();
    _loadCoachForm();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadCoachForm() async {
    try {
      final form = await ref
          .read(studentServiceProvider)
          .getActiveCoachCheckInForm();
      if (form != null && mounted) setState(() => _formData = form);
    } catch (e) {
      debugPrint('Error loading check-in form: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= _maxPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo $_maxPhotos fotos')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final ext =
          picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      setState(() => _selectedImages.add(_ImageData(bytes, ext)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo acceder a la imagen')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<void> _submitCheckIn() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor añade al menos una foto')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      final userId =
          ref.read(supabaseClientProvider).auth.currentUser?.id ?? 'unknown';

      final photoUrls = <String>[];
      for (final img in _selectedImages) {
        final url = await storage.uploadCheckInPhotoBytes(
          img.bytes,
          img.extension,
          userId,
        );
        photoUrls.add(url);
      }

      final service = ref.read(studentServiceProvider);
      await service.performCheckInFromUrls(
        photoUrls: photoUrls,
        comment: _commentController.text.trim(),
        formId: _formData?['id'] as String?,
        formResponses: _formResponses.isNotEmpty ? _formResponses : null,
      );

      if (mounted) {
        ref.invalidate(checkInStatusProvider);
        ref.invalidate(myCheckInsProvider);
        setState(() => _submitted = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    setState(() {
      _selectedImages.clear();
      _commentController.clear();
      _formResponses.clear();
      _selectedDate = DateTime.now();
      _submitted = false;
    });
  }

  // ─── Date helpers ──────────────────────────────────────────────────────────

  String _formatDateLabel(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final prefix = isToday ? 'Hoy' : '${d.day}';
    return '$prefix - ${d.day} ${months[d.month]}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      helpText: 'Seleccioná la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
      builder: (ctx, child) => Theme(
        data: RedesignTheme.theme,
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        extendBody: true,
        appBar: _buildAppBar(context),
        bottomNavigationBar: StudentBottomNav(
          active: StudentNavTab.inicio,
          onInicioTap: () =>
              Navigator.popUntil(context, (r) => r.isFirst),
          onEntrenarTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentRoutineScreen(),
            ),
          ),
          onNutricionTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentMealPlanScreen(),
            ),
          ),
        ),
        body: _submitted ? _buildSuccessView() : _buildFormView(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.arrow_back, color: Colors.white),
      ),
      centerTitle: true,
      title: const Text(
        'Check-in',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Metropolis',
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentCheckInHistoryScreen(),
              ),
            ),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: RedesignColors.primario700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Form view (States A + B) ──────────────────────────────────────────────

  Widget _buildFormView() {
    final hasPhotos = _selectedImages.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Amber info banner ──────────────────────────────────────────────
          _buildInfoBanner(),
          const SizedBox(height: 20),

          // ── Date field ────────────────────────────────────────────────────
          const Text(
            'Fecha',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(height: 8),
          _buildDateField(),
          const SizedBox(height: 20),

          // ── Photo area ────────────────────────────────────────────────────
          _buildPhotoArea(),
          const SizedBox(height: 20),

          // ── Comments ──────────────────────────────────────────────────────
          _buildCommentsField(),
          const SizedBox(height: 24),

          // ── Coach form (if any) ───────────────────────────────────────────
          if (_formData != null) ...[
            _buildCoachForm(),
            const SizedBox(height: 24),
          ],

          // ── Submit button ─────────────────────────────────────────────────
          _buildSubmitButton(hasPhotos),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RedesignColors.advertencia800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: RedesignColors.advertencia400,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Subí hasta 10 fotos para que tu entrenador vea el progreso.',
              style: TextStyle(
                color: RedesignColors.advertencia100,
                fontSize: 13,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _formatDateLabel(_selectedDate),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontFamily: 'Metropolis',
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: RedesignColors.primario300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoArea() {
    final hasPhotos = _selectedImages.isNotEmpty;
    final canAddMore = _selectedImages.length < _maxPhotos;

    return GestureDetector(
      onTap: hasPhotos ? null : () => _showImageSourceModal(context),
      child: _DashedBorderBox(
        borderRadius: 16,
        borderColor: RedesignColors.primario500,
        child: hasPhotos
            ? _buildPhotoGrid(canAddMore)
            : _buildEmptyPhotoState(),
      ),
    );
  }

  Widget _buildEmptyPhotoState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.add_a_photo_outlined,
            color: RedesignColors.primario400,
            size: 36,
          ),
          SizedBox(height: 10),
          Text(
            'Añadir fotos',
            style: TextStyle(
              color: RedesignColors.primario400,
              fontSize: 14,
              fontFamily: 'Metropolis',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(bool canAddMore) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ..._selectedImages.asMap().entries.map((e) {
            final i = e.key;
            final img = e.value;
            return _PhotoThumbnail(
              imageData: img,
              onRemove: () => _removeImage(i),
            );
          }),
          if (canAddMore)
            GestureDetector(
              onTap: () => _showImageSourceModal(context),
              child: Container(
                width: _thumbnailSize(context),
                height: _thumbnailSize(context),
                decoration: BoxDecoration(
                  color: RedesignColors.primario700,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: RedesignColors.primario500,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: RedesignColors.primario400,
                  size: 28,
                ),
              ),
            ),
        ],
      ),
    );
  }

  double _thumbnailSize(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final available = screenW - 44 - 24; // h-padding 22*2 minus gaps (2*12)
    return (available / 3).floorToDouble();
  }

  Widget _buildCommentsField() {
    return TextField(
      controller: _commentController,
      maxLines: 4,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontFamily: 'Metropolis',
      ),
      decoration: InputDecoration(
        hintText: 'Comentarios o sensaciones',
        hintStyle: const TextStyle(
          color: RedesignColors.primario400,
          fontSize: 14,
          fontFamily: 'Metropolis',
        ),
        filled: true,
        fillColor: RedesignColors.primario700,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: RedesignColors.inputBorderFocused,
            width: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton(bool hasPhotos) {
    if (_isLoading) {
      return SizedBox(
        height: 54,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: RedesignColors.onActionPrimary,
              strokeWidth: 2.5,
            ),
          ),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: hasPhotos ? _submitCheckIn : null,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            hasPhotos ? RedesignColors.actionPrimary : RedesignColors.disabledFill,
        foregroundColor: hasPhotos
            ? RedesignColors.onActionPrimary
            : RedesignColors.disabledText,
        minimumSize: const Size(double.infinity, 54),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        disabledBackgroundColor: RedesignColors.disabledFill,
        disabledForegroundColor: RedesignColors.disabledText,
      ),
      icon: const Icon(Icons.upload_rounded, size: 20),
      label: const Text(
        'Subir reporte',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Metropolis',
        ),
      ),
    );
  }

  // ─── Success view (State C) ────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.cloud_done_rounded,
            color: RedesignColors.success,
            size: 72,
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Listo!',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Tus fotos fueron enviadas a tu entrenador. Te avisaremos cuando las revise.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RedesignColors.primario300,
              fontSize: 15,
              fontFamily: 'Metropolis',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _resetForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.actionPrimary,
              foregroundColor: RedesignColors.onActionPrimary,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Volver al check-in',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () =>
                Navigator.popUntil(context, (r) => r.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.primario700,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Ir al inicio',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                fontFamily: 'Metropolis',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Coach form (preserved from original) ─────────────────────────────────

  Widget _buildCoachForm() {
    final questions =
        (_formData?['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (questions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.assignment_rounded,
                color: RedesignColors.actionPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formData?['title'] ?? 'Formulario de check-in',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFamily: 'Metropolis',
                ),
              ),
            ],
          ),
          if (_formData?['description'] is String &&
              (_formData!['description'] as String).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _formData!['description'],
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontFamily: 'Metropolis',
                ),
              ),
            ),
          const SizedBox(height: 16),
          ...questions.asMap().entries.map((e) {
            final i = e.key;
            final q = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildFormField(
                key: 'q_$i',
                type: q['type'] as String? ?? 'text_short',
                label: q['label'] as String? ?? 'Pregunta ${i + 1}',
                options: (q['options'] as List?)?.cast<String>() ?? [],
                value: _formResponses['q_$i'],
                onChanged: (v) => setState(() => _formResponses['q_$i'] = v),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String key,
    required String type,
    required String label,
    required List<String> options,
    required dynamic value,
    required ValueChanged<dynamic> onChanged,
  }) {
    switch (type) {
      case 'text_long':
        return TextField(
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
          ),
          onChanged: (v) => onChanged(v),
        );
      case 'scale_1_10':
        final cur = (value is int) ? value : 5;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Metropolis',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(10, (i) {
                final n = i + 1;
                final sel = cur == n;
                return GestureDetector(
                  onTap: () => onChanged(n),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: sel
                          ? RedesignColors.actionPrimary
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sel
                            ? RedesignColors.actionPrimary
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: sel
                              ? RedesignColors.onActionPrimary
                              : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      case 'multiple_choice':
        final sel = (value is String) ? value : '';
        return RadioGroup<String>(
          groupValue: sel.isEmpty ? null : sel,
          onChanged: (v) => onChanged(v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Metropolis',
                ),
              ),
              const SizedBox(height: 8),
              ...options.map(
                (o) => RadioListTile<String>(
                  title: Text(
                    o,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                  value: o,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: RedesignColors.actionPrimary,
                ),
              ),
            ],
          ),
        );
      default:
        return TextField(
          decoration: InputDecoration(labelText: label),
          controller: TextEditingController(text: value?.toString() ?? ''),
          onChanged: (v) => onChanged(v),
        );
    }
  }

  void _showImageSourceModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: RedesignColors.primario800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: RedesignColors.primario500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Tomar Foto',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Metropolis',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Galería',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Metropolis',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Photo thumbnail widget ───────────────────────────────────────────────────

class _PhotoThumbnail extends StatelessWidget {
  final _ImageData imageData;
  final VoidCallback onRemove;

  const _PhotoThumbnail({
    required this.imageData,
    required this.onRemove,
  });

  static const double _size = 96;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              imageData.bytes,
              width: _size,
              height: _size,
              fit: BoxFit.cover,
              cacheWidth: (_size * 2).round(),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: RedesignColors.actionPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 13,
                  color: RedesignColors.onActionPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed border box ────────────────────────────────────────────────────────

class _DashedBorderBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final Color borderColor;

  const _DashedBorderBox({
    required this.child,
    required this.borderRadius,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(
        radius: borderRadius,
        color: borderColor,
        dashWidth: 6,
        dashGap: 5,
        strokeWidth: 1.5,
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: RedesignColors.primario900.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final double radius;
  final Color color;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;

  const _DashedBorderPainter({
    required this.radius,
    required this.color,
    required this.dashWidth,
    required this.dashGap,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    final dashTotal = dashWidth + dashGap;
    var distance = 0.0;

    while (distance < totalLength) {
      final end = math.min(distance + dashWidth, totalLength);
      final extractedPath = metrics.extractPath(distance, end);
      canvas.drawPath(extractedPath, paint);
      distance += dashTotal;
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dashWidth != dashWidth ||
      old.dashGap != dashGap ||
      old.strokeWidth != strokeWidth;
}
