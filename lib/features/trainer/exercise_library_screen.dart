import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/trainer_service.dart';
import '../../../services/storage_service.dart';

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedMuscleGroup;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(exercisesProvider);
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca de Ejercicios'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Mis Ejercicios'),
          ],
        ),
        actions: [
          // Muscle group filter
          muscleGroupsAsync.when(
            data: (groups) => PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              initialValue: _selectedMuscleGroup,
              onSelected: (value) {
                setState(() => _selectedMuscleGroup = value == 'Todos' ? null : value);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'Todos', child: Text('Todos')),
                const PopupMenuDivider(),
                ...groups.map((g) => PopupMenuItem(value: g, child: Text(g))),
              ],
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // All exercises
          _ExerciseList(muscleGroup: _selectedMuscleGroup),
          // My custom exercises
          _ExerciseList(muscleGroup: _selectedMuscleGroup, customOnly: true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateExercise(context),
        icon: const Icon(Icons.add),
        label: const Text('Crear Ejercicio'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showCreateExercise(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateExerciseSheet(),
    );
  }
}

// Exercise List Widget
class _ExerciseList extends ConsumerWidget {
  final String? muscleGroup;
  final bool customOnly;

  const _ExerciseList({
    this.muscleGroup,
    this.customOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return exercisesAsync.when(
      data: (exercises) {
        var filtered = exercises;

        // Filter by muscle group
        if (muscleGroup != null) {
          filtered = filtered.where((e) => e['muscle_group'] == muscleGroup).toList();
        }

        // Filter custom only
        if (customOnly) {
          filtered = filtered.where((e) => e['created_by_trainer'] != null).toList();
        }

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(
                  customOnly ? 'No has creado ejercicios' : 'Sin ejercicios',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final exercise = filtered[index];
            return _ExerciseCard(exercise: exercise);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

// Exercise Card
class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] ?? 'Ejercicio';
    final muscleGroup = exercise['muscle_group'] ?? '';
    final hasVideo = exercise['video_url'] != null;
    final hasImages = (exercise['image_urls'] as List?)?.isNotEmpty ?? false;
    final isCustom = exercise['created_by_trainer'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: Icon(
                hasVideo ? Icons.play_circle_fill : Icons.fitness_center,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            if (hasImages)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.image, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(muscleGroup, style: TextStyle(color: AppColors.textSecondary)),
            if (isCustom)
              const Text(
                'Custom',
                style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showExerciseDetail(context, exercise),
      ),
    );
  }

  void _showExerciseDetail(BuildContext context, Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ExerciseDetailSheet(exercise: exercise),
    );
  }
}

// Exercise Detail Sheet
class _ExerciseDetailSheet extends StatefulWidget {
  final Map<String, dynamic> exercise;

  const _ExerciseDetailSheet({required this.exercise});

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    final videoUrl = widget.exercise['video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.exercise['name'] ?? 'Ejercicio';
    final muscleGroup = widget.exercise['muscle_group'] ?? '';
    final instructions = widget.exercise['instructions'] ?? 'Sin instrucciones';
    final imageUrls = (widget.exercise['image_urls'] as List?)?.cast<String>() ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(muscleGroup, style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditExercise(context, widget.exercise);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player
                  if (_videoController != null && _videoController!.value.isInitialized)
                    AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          VideoPlayer(_videoController!),
                          IconButton(
                            icon: Icon(
                              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 64,
                            ),
                            onPressed: () {
                              setState(() {
                                _videoController!.value.isPlaying
                                    ? _videoController!.pause()
                                    : _videoController!.play();
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                  if (_videoController != null) const SizedBox(height: 16),

                  // Images Gallery
                  if (imageUrls.isNotEmpty) ...[
                    const Text('Imágenes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: imageUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                imageUrls[index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Instructions
                  const Text('Instrucciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(instructions),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditExercise(BuildContext context, Map<String, dynamic> exercise) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateExerciseSheet(exerciseToEdit: exercise),
    );
  }
}

// Create/Edit Exercise Sheet
class _CreateExerciseSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? exerciseToEdit;
  
  const _CreateExerciseSheet({this.exerciseToEdit});

  @override
  ConsumerState<_CreateExerciseSheet> createState() => _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends ConsumerState<_CreateExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _selectedMuscleGroup = 'Pecho';
  File? _selectedVideo;
  List<File> _selectedImages = [];
  bool _isLoading = false;

  final _picker = ImagePicker();
  
  bool get _isEditMode => widget.exerciseToEdit != null;
  String get _title => _isEditMode ? 'Editar Ejercicio' : 'Crear Ejercicio';

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _nameController.text = widget.exerciseToEdit!['name'] ?? '';
      _instructionsController.text = widget.exerciseToEdit!['instructions'] ?? '';
      _selectedMuscleGroup = widget.exerciseToEdit!['muscle_group'] ?? 'Pecho';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    _title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _saveExercise,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del ejercicio',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // Muscle Group
                    DropdownButtonFormField<String>(
                      value: _selectedMuscleGroup,
                      decoration: const InputDecoration(
                        labelText: 'Grupo muscular',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Pecho', child: Text('Pecho')),
                        DropdownMenuItem(value: 'Espalda', child: Text('Espalda')),
                        DropdownMenuItem(value: 'Piernas', child: Text('Piernas')),
                        DropdownMenuItem(value: 'Hombros', child: Text('Hombros')),
                        DropdownMenuItem(value: 'Brazos', child: Text('Brazos')),
                        DropdownMenuItem(value: 'Core', child: Text('Core')),
                      ],
                      onChanged: (v) => setState(() => _selectedMuscleGroup = v!),
                    ),
                    const SizedBox(height: 16),

                    // Instructions
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instrucciones',
                        border: OutlineInputBorder(),
                        hintText: 'Describe cómo realizar el ejercicio',
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Video
                    const Text('Video (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _VideoSelector(
                      selectedVideo: _selectedVideo,
                      onSelect: (file) => setState(() => _selectedVideo = file),
                      onRemove: () => setState(() => _selectedVideo = null),
                    ),
                    const SizedBox(height: 24),

                    // Images
                    const Text('Imágenes (opcional)', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _ImageSelector(
                      selectedImages: _selectedImages,
                      onAdd: (file) => setState(() => _selectedImages.add(file)),
                      onRemove: (index) => setState(() => _selectedImages.removeAt(index)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(trainerServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      
      String exerciseId;

      if (_isEditMode) {
        // Edit mode: update existing exercise
        exerciseId = widget.exerciseToEdit!['id'] as String;
        
        await service.updateExercise(
          exerciseId,
          name: _nameController.text,
          muscleGroup: _selectedMuscleGroup,
          instructions: _instructionsController.text,
        );
      } else {
        // Create mode: create new exercise
        final exerciseData = await service.createExercise(
          name: _nameController.text,
          muscleGroup: _selectedMuscleGroup,
          instructions: _instructionsController.text,
        );
        exerciseId = exerciseData['id'] as String;
      }

      // Upload video if selected
      String? videoUrl;
      if (_selectedVideo != null) {
        videoUrl = await storageService.uploadExerciseVideo(_selectedVideo!, exerciseId);
      }

      // Upload images if selected
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        imageUrls = await storageService.uploadExerciseImages(_selectedImages, exerciseId);
      }

      // Update exercise with URLs
      if (videoUrl != null || imageUrls.isNotEmpty) {
        await service.updateExerciseMedia(exerciseId, videoUrl: videoUrl, imageUrls: imageUrls);
      }

      // Refresh list
      ref.invalidate(exercisesProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode ? 'Ejercicio actualizado' : 'Ejercicio creado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// Video Selector Widget
class _VideoSelector extends StatelessWidget {
  final File? selectedVideo;
  final Function(File) onSelect;
  final VoidCallback onRemove;

  const _VideoSelector({
    required this.selectedVideo,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedVideo != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.video_library, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(selectedVideo!.path.split('/').last)),
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.error),
              onPressed: onRemove,
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () async {
        final picker = ImagePicker();
        final video = await picker.pickVideo(source: ImageSource.gallery);
        if (video != null) {
          onSelect(File(video.path));
        }
      },
      icon: const Icon(Icons.video_library),
      label: const Text('Seleccionar video'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

// Image Selector Widget
class _ImageSelector extends StatelessWidget {
  final List<File> selectedImages;
  final Function(File) onAdd;
  final Function(int) onRemove;

  const _ImageSelector({
    required this.selectedImages,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (selectedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(selectedImages[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => onRemove(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              onAdd(File(image.path));
            }
          },
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Agregar imagen'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

// Provider for muscle groups
final muscleGroupsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMuscleGroups();
});
