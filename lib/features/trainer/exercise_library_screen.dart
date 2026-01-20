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

  IconData _getMuscleIcon(String muscleGroup) {
    // This mapping matches _MuscleGroupSelector
    switch (muscleGroup.toLowerCase()) {
      case 'pecho':
        return Icons.shield_rounded;
      case 'espalda':
        return Icons.layers;
      case 'piernas':
        return Icons.directions_run;
      case 'hombros':
        return Icons.accessibility;
      case 'brazos':
        return Icons.fitness_center;
      case 'core':
        return Icons.grid_view;
      default:
        return Icons.fitness_center; // Default Fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] ?? 'Ejercicio';
    final muscleGroup = exercise['muscle_group'] ?? '';
    final hasVideo = exercise['video_url'] != null;
    final hasImages = (exercise['image_urls'] as List?)?.isNotEmpty ?? false;
    final isCustom = exercise['created_by_trainer'] != null;

    final muscleIcon = _getMuscleIcon(muscleGroup);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showExerciseDetail(context, exercise),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Muscle Group Icon (Large, Circular)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  muscleIcon,
                  color: AppColors.primary,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      muscleGroup,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Metadata Badges Row
                    Row(
                      children: [
                        if (isCustom)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _MetadataBadge(
                              label: 'Custom',
                              color: AppColors.primary,
                              isOutlined: true,
                            ),
                          ),
                        if (hasVideo)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: _IconBadge(
                              icon: Icons.videocam,
                              color: Colors.blue,
                            ),
                          ),
                        if (hasImages)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: _IconBadge(
                              icon: Icons.image,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
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

class _MetadataBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isOutlined;

  const _MetadataBadge({
    required this.label,
    required this.color,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOutlined ? null : color.withOpacity(0.1),
        border: isOutlined ? Border.all(color: color) : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBadge({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 14,
        color: color,
      ),
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
  late PageController _pageController;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
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
    _pageController.dispose();
    super.dispose();
  }

  IconData _getMuscleIcon(String muscleGroup) {
    switch (muscleGroup.toLowerCase()) {
      case 'pecho':
        return Icons.shield_rounded;
      case 'espalda':
        return Icons.layers;
      case 'piernas':
        return Icons.directions_run;
      case 'hombros':
        return Icons.accessibility;
      case 'brazos':
        return Icons.fitness_center;
      case 'core':
        return Icons.grid_view;
      default:
        return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.exercise['name'] ?? 'Ejercicio';
    final muscleGroup = widget.exercise['muscle_group'] ?? '';
    final instructions = widget.exercise['instructions'] ?? 'Sin instrucciones';
    final imageUrls = (widget.exercise['image_urls'] as List?)?.cast<String>() ?? [];
    final muscleIcon = _getMuscleIcon(muscleGroup);

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(muscleIcon, color: AppColors.primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        muscleGroup,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                    Navigator.pop(context);
                    _showEditExercise(context, widget.exercise);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Video Player
                  if (_videoController != null && _videoController!.value.isInitialized) ...[
                     Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_videoController!),
                              Container(color: Colors.black26), // Overlay
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _videoController!.value.isPlaying
                                        ? _videoController!.pause()
                                        : _videoController!.play();
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    _videoController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Instructions Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description_outlined, size: 20, color: AppColors.textSecondary),
                            const SizedBox(width: 8),
                            Text(
                              'Instrucciones',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          instructions,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Images Gallery
                  if (imageUrls.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'Galería de imágenes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220, // Increased height for carousel
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (index) => setState(() => _currentImageIndex = index),
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showFullImage(context, imageUrls[index]),
                            child: Hero(
                              tag: 'exercise_img_$index',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade100,
                                      child: const Icon(Icons.broken_image, color: Colors.grey),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Dot Indicators
                    if (imageUrls.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imageUrls.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? AppColors.primary
                                  : Colors.grey.shade300,
                            ),
                          );
                        }),
                      ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    ));
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
                    const Text('Grupo muscular', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    _MuscleGroupSelector(
                      selectedGroup: _selectedMuscleGroup,
                      onSelect: (group) => setState(() => _selectedMuscleGroup = group),
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

// Muscle Group Selector Widget
class _MuscleGroupSelector extends StatelessWidget {
  final String selectedGroup;
  final Function(String) onSelect;

  const _MuscleGroupSelector({
    required this.selectedGroup,
    required this.onSelect,
  });

  static const _groups = [
    {'name': 'Pecho', 'icon': Icons.shield_rounded}, // Chest
    {'name': 'Espalda', 'icon': Icons.layers}, // Back
    {'name': 'Piernas', 'icon': Icons.directions_run}, // Running for legs
    {'name': 'Hombros', 'icon': Icons.accessibility}, // Accessibility usually shows upper body
    {'name': 'Brazos', 'icon': Icons.fitness_center}, // Dumbbell for arms
    {'name': 'Core', 'icon': Icons.grid_view}, // Grid for abs
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _groups.length,
      itemBuilder: (context, index) {
        final group = _groups[index];
        final name = group['name'] as String;
        final icon = group['icon'] as IconData;
        final isSelected = selectedGroup == name;

        return InkWell(
          onTap: () => onSelect(name),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
