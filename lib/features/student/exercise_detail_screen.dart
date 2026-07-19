import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/theme/app_theme.dart';
import '../../models/exercise_model.dart';
import '../../services/exercise_media_service.dart';
import '../../services/trainer_service.dart';
import '../../widgets/exercise_gif_view.dart';

/// Pantalla de detalle de ejercicio para el alumno.
///
/// Muestra: GIF animado (si es seed) o video YouTube/mp4 (si el trainer lo cargó),
/// nombre, target/equipment/sinergistas, instrucciones en español y aclaraciones
/// del coach (comment del routine_exercise).
class ExerciseDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>
  exerciseData; // routine_exercises row con exercises(*)
  final String? coachComment;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseData,
    this.coachComment,
  });

  @override
  ConsumerState<ExerciseDetailScreen> createState() =>
      _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends ConsumerState<ExerciseDetailScreen> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  bool _isYoutube = false;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.close();
    super.dispose();
  }

  void _initVideo() {
    final exercise =
        widget.exerciseData['exercises'] as Map<String, dynamic>? ??
        widget.exerciseData;
    final videoUrl = exercise['video_url'] as String?;
    if (videoUrl == null || videoUrl.isEmpty) return;

    if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
      _isYoutube = true;
      final videoId = YoutubePlayerController.convertUrlToId(videoUrl);
      if (videoId != null) {
        _youtubeController = YoutubePlayerController.fromVideoId(
          videoId: videoId,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            mute: false,
          ),
        );
      }
    } else {
      _isYoutube = false;
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          if (mounted) {
            _videoController!.setLooping(true);
            _videoController!.play();
            setState(() => _isVideoInitialized = true);
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawExercise =
        widget.exerciseData['exercises'] as Map<String, dynamic>? ??
        widget.exerciseData;
    final exercise = ExerciseModel.fromMap({...rawExercise});

    // Stats from routine_exercises
    final sets = widget.exerciseData['sets'] ?? 3;
    final repsTarget = widget.exerciseData['reps_target']?.toString() ?? '10';
    final restSeconds = widget.exerciseData['rest_seconds'] ?? 60;
    final coachComment =
        widget.coachComment ?? widget.exerciseData['comment'] as String?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title block
            Text(
              exercise.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 12),
            _buildAttributeChips(exercise),
            const SizedBox(height: 20),

            // Media: video > gif
            _buildMediaBlock(exercise),
            const SizedBox(height: 24),

            // Stats (sets/reps/rest)
            _buildStatsRow(sets, repsTarget, restSeconds),
            const SizedBox(height: 24),

            // Coach comment
            if (coachComment != null && coachComment.isNotEmpty) ...[
              _buildCoachCard(coachComment),
              const SizedBox(height: 20),
            ],

            // Instructions
            _buildInstructionsCard(exercise),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAttributeChips(ExerciseModel ex) {
    final chips = <_ChipData>[
      if (ex.bodyPart != null && ex.bodyPart!.isNotEmpty)
        _ChipData(
          label: _translateBodyPart(ex.bodyPart!),
          color: AppColors.primary,
        ),
      if (ex.equipment != null && ex.equipment!.isNotEmpty)
        _ChipData(
          label: _translateEquipment(ex.equipment!),
          color: AppColors.accent,
        ),
      if (ex.target != null && ex.target!.isNotEmpty)
        _ChipData(label: ex.target!, color: AppColors.success),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: c.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.color.withValues(alpha: 0.3)),
              ),
              child: Text(
                c.label,
                style: TextStyle(
                  color: c.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMediaBlock(ExerciseModel ex) {
    // Video first
    if (_isYoutube && _youtubeController != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: YoutubePlayer(controller: _youtubeController!),
        ),
      );
    }
    if (!_isYoutube && _videoController != null && _isVideoInitialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
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
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  _videoController!.value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // GIF
    final gifUrl = ref
        .read(exerciseMediaServiceProvider)
        .resolveGifUrl(ex.gifUrl, mediaId: ex.mediaId);
    if (gifUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ExerciseGifView(
          url: gifUrl,
          height: 280,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            height: 280,
            color: AppColors.surface,
            child: const Center(child: CircularProgressIndicator()),
          ),
          errorWidget: (_, __, ___) => Container(
            height: 280,
            color: AppColors.surface,
            child: const Icon(
              Icons.broken_image,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      );
    }
    // Placeholder
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center, color: Colors.white38, size: 56),
          SizedBox(height: 12),
          Text(
            'Sin multimedia',
            style: TextStyle(color: Colors.white54, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(int sets, String repsTarget, int restSeconds) {
    Widget stat(String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white54,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );

    return Row(
      children: [
        stat('$sets', 'Series', AppColors.primaryLight),
        const SizedBox(width: 12),
        stat(repsTarget, 'Reps', AppColors.accent),
        const SizedBox(width: 12),
        stat('${restSeconds}s', 'Descanso', AppColors.warning),
      ],
    );
  }

  Widget _buildCoachCard(String comment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.record_voice_over_rounded,
                color: AppColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'ACLARACIONES DEL COACH',
                style: TextStyle(
                  color: AppColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            comment,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard(ExerciseModel ex) {
    final steps = ex.stepsEs;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'INSTRUCCIONES',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (steps.length == 1)
            Text(
              steps.first,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.6,
              ),
            )
          else
            ...steps.asMap().entries.map((entry) {
              final i = entry.key + 1;
              final text = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$i',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          // Secondary muscles
          if (ex.secondaryMuscles.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const Text(
              'MÚSCULOS SECUNDARIOS',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: ex.secondaryMuscles
                  .map(
                    (m) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        m,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // Translate helpers
  String _translateBodyPart(String part) {
    const map = {
      'chest': 'Pecho',
      'back': 'Espalda',
      'upper legs': 'Piernas',
      'lower legs': 'Pantorrillas',
      'shoulders': 'Hombros',
      'upper arms': 'Brazos',
      'lower arms': 'Antebrazos',
      'waist': 'Core',
      'cardio': 'Cardio',
      'neck': 'Cuello',
    };
    return map[part.toLowerCase()] ?? part;
  }

  String _translateEquipment(String eq) {
    const map = {
      'barbell': 'Barra',
      'dumbbell': 'Mancuerna',
      'body weight': 'Peso corporal',
      'cable': 'Cable',
      'machine': 'Máquina',
      'kettlebell': 'Pesa rusa',
      'band': 'Banda',
      'resistance band': 'Banda elástica',
      'leverage machine': 'Máquina palanca',
      'smith machine': 'Smith',
      'stability ball': 'Pelota',
      'medicine ball': 'Pelota medicinal',
      'ez barbell': 'Barra Z',
      'rope': 'Cuerda',
      'weighted': 'Lastre',
      'assisted': 'Asistido',
    };
    return map[eq.toLowerCase()] ?? eq;
  }
}

class _ChipData {
  final String label;
  final Color color;
  const _ChipData({required this.label, required this.color});
}

/// Provider para fetch by id (opcional - por si se quiere navegar solo con id)
final exerciseByIdProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, id) async {
      final service = ref.watch(trainerServiceProvider);
      return service.getExercise(id);
    });
