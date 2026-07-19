import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/storage_service.dart';
import '../../services/supabase_service.dart';

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
  Map<String, dynamic>? _formData;
  final Map<String, dynamic> _formResponses = {};

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Máximo $_maxPhotos fotos')));
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
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Check-in enviado a tu entrenador!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check-in')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Sube hasta $_maxPhotos fotos para que tu entrenador evalúe tu progreso.',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            _buildPhotoGrid(),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Comentarios o sensaciones',
                hintText: '¿Cómo te has sentido esta semana?',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.comment_outlined),
              ),
            ),
            const SizedBox(height: 24),
            if (_formData != null) ...[
              _buildCoachForm(),
              const SizedBox(height: 24),
            ],
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitCheckIn,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: const Text('Enviar Reporte'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    final remaining = _maxPhotos - _selectedImages.length;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ..._selectedImages.asMap().entries.map((e) {
          final i = e.key;
          final img = e.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  img.bytes,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        if (remaining > 0)
          GestureDetector(
            onTap: () => _showImageSourceModal(context),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Añadir',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCoachForm() {
    final questions =
        (_formData?['questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (questions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                color: AppColors.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _formData?['title'] ?? 'Formulario de check-in',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
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
                style: const TextStyle(color: Colors.white54, fontSize: 13),
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
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: sel
                            ? AppColors.accent
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$n',
                        style: TextStyle(
                          color: sel ? Colors.black : Colors.white54,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            ...options.map(
              (o) => RadioListTile<String>(
                title: Text(
                  o,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                value: o,
                groupValue: sel.isEmpty ? null : sel,
                onChanged: (v) => onChanged(v),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.accent,
              ),
            ),
          ],
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}
