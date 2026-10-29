import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../../services/storage_service.dart';

class CreateMealPlanSheet extends ConsumerStatefulWidget {
  const CreateMealPlanSheet({super.key});

  @override
  ConsumerState<CreateMealPlanSheet> createState() => _CreateMealPlanSheetState();
}

class _CreateMealPlanSheetState extends ConsumerState<CreateMealPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _caloriesController = TextEditingController();
  // Web-safe image state: bytes + extension instead of dart:io File
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final ext = x.name.split('.').last.toLowerCase();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _imageExt = ext.isEmpty ? 'jpg' : ext;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trainerService = ref.read(trainerServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      // Create the plan first (no image yet) to obtain the plan ID.
      final plan = await trainerService.createMealPlan(
        title: _nameController.text.trim(),
        description: _descController.text.trim(),
        targetCalories: int.tryParse(_caloriesController.text.trim()),
        storageService: storageService,
      );

      // If bytes were picked, upload via bytes path and patch image_url.
      if (_imageBytes != null) {
        final userId = trainerService.currentUserId ?? plan['trainer_id'] as String? ?? '';
        if (userId.isNotEmpty) {
          final url = await storageService.uploadMealPlanCoverBytes(
            _imageBytes!,
            _imageExt,
            userId,
          );
          await trainerService.updateMealPlanImageUrl(plan['id'] as String, url);
        }
      }

      ref.invalidate(myMealPlansProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan creado exitosamente'),
            backgroundColor: RedesignColors.success,
          ),
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RedesignColors.primario900, RedesignColors.secundario900],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
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
                        color: RedesignColors.primario50.withValues(alpha: 0.30),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Close button
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
                    'Nuevo Plan',
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega nombre, calorías y descripción',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario300,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Photo picker — dashed box
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: RedesignColors.primario800,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: RedesignColors.secundario300.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _imageBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(_imageBytes!, fit: BoxFit.cover),
                                Container(
                                  color: RedesignColors.primario900.withValues(alpha: 0.45),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.edit_rounded,
                                      color: RedesignColors.primario50, size: 28),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: RedesignColors.secundario300.withValues(alpha: 0.6),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Añadir portada',
                                  style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.secundario300.withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nombre del plan
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del plan',
                      hintText: 'Ej: Definición, Volumen...',
                      prefixIcon: Icon(Icons.restaurant_rounded),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 16),

                  // Calorías objetivo
                  TextFormField(
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calorías objetivo (opcional)',
                      hintText: 'Ej: 2000',
                      prefixIcon: Icon(Icons.local_fire_department_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Descripción / Notas
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Notas',
                      hintText: 'Instrucciones generales...',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: RedesignColors.primario950,
                            ),
                          )
                        : const Text('Crear plan'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
