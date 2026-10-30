import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../core/utils/string_utils.dart';
import '../../../services/trainer_service.dart';
import '../../../services/storage_service.dart';
import 'package:north_star/utils/exercise_category.dart';

// ---------------------------------------------------------------------------
// ExerciseLibraryScreen — PRGS redesign (navy/teal palette)
// Figma screens: "Ejercicios (todos)", "Ejercicios (mis ejercicios)",
//                "Nuevo ejercicio", "Detalle del ejercicio"
// ---------------------------------------------------------------------------

// Muscle-group filter chips shown in the list header.
const List<String> _kMuscleChips = [
  'Todos',
  'Piernas',
  'Pecho',
  'Espalda',
  'Hombros',
  'Brazos',
  'Core',
];

class ExerciseLibraryScreen extends ConsumerStatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  ConsumerState<ExerciseLibraryScreen> createState() =>
      _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends ConsumerState<ExerciseLibraryScreen> {
  // 0 = Todos, 1 = Mis ejercicios
  int _tabIndex = 0;
  String? _selectedMuscleGroup; // null means "Todos"
  String _searchQuery = '';
  bool _filterNoVideo = false; // toggled by "Ver" pill in banner

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              _buildSegmentedTabs(),
              const SizedBox(height: 16),
              _buildSearchField(),
              const SizedBox(height: 12),
              // Muscle-group chips only on "Todos" tab
              if (_tabIndex == 0) ...[
                _buildMuscleChips(),
                const SizedBox(height: 16),
              ],
              _buildCreateButton(context),
              const SizedBox(height: 4),
              Expanded(
                child: _ExerciseList(
                  muscleGroup: _selectedMuscleGroup,
                  searchQuery: _searchQuery,
                  customOnly: _tabIndex == 1,
                  filterNoVideo: _filterNoVideo,
                  onFilterNoVideo: (val) =>
                      setState(() => _filterNoVideo = val),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header: back arrow + "Ejercicios" title ──────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: RedesignColors.primario50,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Ejercicios',
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Segmented pill: Todos / Mis ejercicios ───────────────────────────────

  Widget _buildSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: RedesignColors.primario800,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _SegmentPill(
              label: 'Todos',
              active: _tabIndex == 0,
              onTap: () => setState(() {
                _tabIndex = 0;
                _filterNoVideo = false;
              }),
            ),
            _SegmentPill(
              label: 'Mis ejercicios',
              active: _tabIndex == 1,
              onTap: () => setState(() {
                _tabIndex = 1;
                _filterNoVideo = false;
              }),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search field ─────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    final placeholder = _tabIndex == 1
        ? 'Buscar en mis ejercicios'
        : 'Buscar ejercicios';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        onChanged: (val) => setState(() {
          _searchQuery = val;
          _filterNoVideo = false;
        }),
        style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
        decoration: InputDecoration(
          hintText: placeholder,
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: RedesignColors.primario300,
          ),
        ),
      ),
    );
  }

  // ── Horizontal muscle-group filter chips ─────────────────────────────────

  Widget _buildMuscleChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _kMuscleChips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = _kMuscleChips[i];
          final active = (i == 0 && _selectedMuscleGroup == null) ||
              label == _selectedMuscleGroup;
          return _FilterChip(
            label: label,
            active: active,
            onTap: () => setState(() {
              _selectedMuscleGroup = i == 0 ? null : label;
              _filterNoVideo = false;
            }),
          );
        },
      ),
    );
  }

  // ── "+ Crear ejercicio" outlined button ──────────────────────────────────

  Widget _buildCreateButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: OutlinedButton(
        onPressed: () => _showCreateExercise(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: RedesignColors.actionPrimaryDark,
          side: const BorderSide(
            color: RedesignColors.actionPrimaryDark,
            width: 1.5,
          ),
          minimumSize: const Size(double.infinity, 48),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          '+ Crear ejercicio',
          style: RedesignType.buttonLg.copyWith(
            color: RedesignColors.actionPrimaryDark,
          ),
        ),
      ),
    );
  }

  void _showCreateExercise(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: RedesignTheme.theme,
        child: const _CreateExerciseSheet(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Segmented pill tab
// ---------------------------------------------------------------------------

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SegmentPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? RedesignColors.actionPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: RedesignType.buttonSm.copyWith(
              color: active
                  ? RedesignColors.onActionPrimary
                  : RedesignColors.primario50,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal filter chip (muscle groups)
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.transparent : RedesignColors.primario700,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? RedesignColors.actionPrimaryDark
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: active
                ? RedesignColors.actionPrimaryDark
                : RedesignColors.primario50,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise List
// ---------------------------------------------------------------------------

class _ExerciseList extends ConsumerWidget {
  final String? muscleGroup;
  final bool customOnly;
  final String searchQuery;
  final bool filterNoVideo;
  final ValueChanged<bool> onFilterNoVideo;

  const _ExerciseList({
    this.muscleGroup,
    this.customOnly = false,
    this.searchQuery = '',
    required this.filterNoVideo,
    required this.onFilterNoVideo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(exercisesProvider);

    return exercisesAsync.when(
      data: (exercises) {
        var filtered = exercises;

        if (muscleGroup != null) {
          filtered = filtered
              .where((e) => ExerciseCategory.matches(e, muscleGroup))
              .toList();
        }
        if (customOnly) {
          filtered = filtered
              .where((e) => e['created_by_trainer'] != null)
              .toList();
        }
        if (searchQuery.isNotEmpty) {
          final q = foldSearch(searchQuery);
          filtered = filtered
              .where(
                  (e) => foldSearch(e['name'] as String? ?? '').contains(q))
              .toList();
        }

        // Count custom exercises with no media
        final noVideoList = filtered
            .where(
              (e) =>
                  (e['created_by_trainer'] != null) &&
                  (e['video_url'] == null) &&
                  ((e['image_urls'] as List?)?.isEmpty ?? true),
            )
            .toList();

        final noVideoCount = noVideoList.length;

        // When "Ver" filter is active, show only exercises missing media
        final displayList = filterNoVideo ? noVideoList : filtered;

        if (displayList.isEmpty && !filterNoVideo) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 64,
                  color: RedesignColors.primario600,
                ),
                const SizedBox(height: 16),
                Text(
                  customOnly
                      ? 'No has creado ejercicios'
                      : 'Sin ejercicios',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario300,
                  ),
                ),
              ],
            ),
          );
        }

        // Banner only in "Mis ejercicios" tab when there are exercises w/o media
        final showBanner = customOnly && noVideoCount > 0;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          itemCount: displayList.length + (showBanner ? 1 : 0),
          itemBuilder: (context, index) {
            if (showBanner && index == 0) {
              return _NoVideoBanner(
                count: noVideoCount,
                filterActive: filterNoVideo,
                onTapVer: () => onFilterNoVideo(!filterNoVideo),
              );
            }
            final exercise = displayList[index - (showBanner ? 1 : 0)];
            return _ExerciseCard(exercise: exercise);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: RedesignColors.actionPrimary),
      ),
      error: (e, _) => Center(
        child: Text(
          'Error: $e',
          style: RedesignType.label.copyWith(color: RedesignColors.peligro400),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "N ejercicios sin vídeo" banner
// ---------------------------------------------------------------------------

class _NoVideoBanner extends StatelessWidget {
  final int count;
  final bool filterActive;
  final VoidCallback onTapVer;

  const _NoVideoBanner({
    required this.count,
    required this.filterActive,
    required this.onTapVer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.banner),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: RedesignColors.primario300,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario200,
                ),
                children: [
                  TextSpan(
                    text: '$count ${count == 1 ? 'ejercicio' : 'ejercicios'} sin vídeo',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(
                    text:
                        '. Con video tus alumnos entienden mejor la técnica.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onTapVer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: filterActive
                      ? RedesignColors.actionPrimary
                      : RedesignColors.actionPrimaryDark,
                  width: 1.5,
                ),
              ),
              child: Text(
                filterActive ? 'Todos' : 'Ver',
                style: RedesignType.buttonSm.copyWith(
                  color: filterActive
                      ? RedesignColors.actionPrimary
                      : RedesignColors.actionPrimaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise Card
// ---------------------------------------------------------------------------

class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const _ExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final name = exercise['name'] as String? ?? 'Ejercicio';
    final muscleGroup = exercise['muscle_group'] as String? ?? '';
    final hasVideo = exercise['video_url'] != null;
    final hasImages = (exercise['image_urls'] as List?)?.isNotEmpty ?? false;
    final hasMedia = hasVideo || hasImages;
    final gifUrl = exercise['gif_url'] as String?;

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: RedesignColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: RedesignColors.primario700,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: gifUrl != null && gifUrl.isNotEmpty
                  ? Image.network(
                      gifUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _PlayIconPlaceholder(),
                    )
                  : _PlayIconPlaceholder(),
            ),
            const SizedBox(width: 14),

            // ── Name + muscle + badges ───────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        muscleGroup,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.primario300,
                        ),
                      ),
                      if (!hasMedia) ...[
                        const SizedBox(width: 8),
                        _SinVideoBadge(),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.chevron_right_rounded,
              color: RedesignColors.primario400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Theme(
        data: RedesignTheme.theme,
        child: _ExerciseDetailSheet(exercise: exercise),
      ),
    );
  }
}

// ── Play-icon thumbnail placeholder ─────────────────────────────────────────

class _PlayIconPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: RedesignColors.primario300,
        size: 28,
      ),
    );
  }
}

// ── "Sin vídeo" amber badge ──────────────────────────────────────────────────

class _SinVideoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: RedesignColors.advertencia800,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Sin vídeo',
        style: RedesignType.label.copyWith(
          color: RedesignColors.advertencia300,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise Detail Sheet
// ---------------------------------------------------------------------------

class _ExerciseDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> exercise;

  const _ExerciseDetailSheet({required this.exercise});

  @override
  ConsumerState<_ExerciseDetailSheet> createState() =>
      _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends ConsumerState<_ExerciseDetailSheet> {
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubeController;
  late PageController _pageController;
  int _currentImageIndex = 0;
  bool _isYoutubeVideo = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _initVideo();
  }

  void _initVideo() {
    final videoUrl = widget.exercise['video_url'] as String?;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      if (videoUrl.contains('youtube.com') || videoUrl.contains('youtu.be')) {
        _isYoutubeVideo = true;
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
        _isYoutubeVideo = false;
        _videoController =
            VideoPlayerController.networkUrl(Uri.parse(videoUrl))
              ..initialize().then((_) {
                if (mounted) setState(() {});
              });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _youtubeController?.close();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.exercise['name'] as String? ?? 'Ejercicio';
    final muscleGroup = widget.exercise['muscle_group'] as String? ?? '';
    final instructions =
        widget.exercise['instructions'] as String? ?? 'Sin instrucciones.';
    final imageUrls =
        (widget.exercise['image_urls'] as List?)?.cast<String>() ?? [];
    final gifUrl = widget.exercise['gif_url'] as String?;

    final myTrainerAsync = ref.watch(myTrainerIdProvider);
    final myTrainerId = myTrainerAsync.valueOrNull;
    final owner = widget.exercise['created_by_trainer'];
    final isOwn = owner != null && owner == myTrainerId;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: RedesignColors.primario900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Hero media area ───────────────────────────────────────────
          Stack(
            children: [
              // Hero image / gif placeholder
              Container(
                width: double.infinity,
                height: 220,
                decoration: const BoxDecoration(
                  color: RedesignColors.primario800,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildHeroMedia(gifUrl),
              ),

              // Back button overlay (top-left)
              Positioned(
                top: 14,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: RedesignColors.primario50,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Edit / duplicate + delete actions (top-right)
              Positioned(
                top: 14,
                right: 16,
                child: Row(
                  children: [
                    _HeroButton(
                      icon: isOwn
                          ? Icons.edit_outlined
                          : Icons.perm_media_outlined,
                      tooltip: isOwn ? 'Editar' : 'Añadir mi video/fotos',
                      onTap: myTrainerAsync.isLoading
                          ? null
                          : () {
                              Navigator.pop(context);
                              _showEdit(
                                context,
                                duplicate: false,
                                mediaOverlay: !isOwn,
                              );
                            },
                    ),
                    if (isOwn) ...[
                      const SizedBox(width: 8),
                      _HeroButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: 'Eliminar',
                        onTap: _confirmDelete,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Body ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Muscle chip
                  if (muscleGroup.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: RedesignColors.primario700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        muscleGroup,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.primario200,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),

                  // Exercise name
                  Text(
                    name,
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Instructions
                  Text(
                    instructions,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario300,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Inline video players (YouTube / native) if present
                  if (_isYoutubeVideo && _youtubeController != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: YoutubePlayer(controller: _youtubeController!),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (!_isYoutubeVideo &&
                      _videoController != null &&
                      _videoController!.value.isInitialized) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_videoController!),
                            GestureDetector(
                              onTap: () => setState(() {
                                _videoController!.value.isPlaying
                                    ? _videoController!.pause()
                                    : _videoController!.play();
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: RedesignColors.primario50,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: RedesignColors.primario50,
                                  size: 36,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Photos section
                  if (imageUrls.isNotEmpty) ...[
                    Text(
                      'Fotos',
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 110,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: imageUrls.length,
                        onPageChanged: (i) =>
                            setState(() => _currentImageIndex = i),
                        itemBuilder: (context, index) => GestureDetector(
                          onTap: () =>
                              _showFullImage(context, imageUrls[index]),
                          child: Hero(
                            tag: 'exercise_img_$index',
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: RedesignColors.primario700,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                imageUrls[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.broken_image_rounded,
                                  color: RedesignColors.primario400,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (imageUrls.length > 1) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imageUrls.length,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == i
                                  ? RedesignColors.actionPrimary
                                  : RedesignColors.primario600,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],

                  // ── Primary CTA: Agregar a una rutina ─────────────────
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Agregar a una rutina'),
                  ),
                  const SizedBox(height: 12),

                  // ── Secondary: Editar / Añadir mi video/fotos ─────────
                  OutlinedButton(
                    onPressed: myTrainerAsync.isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                            _showEdit(
                              context,
                              duplicate: false,
                              mediaOverlay: !isOwn,
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: RedesignColors.primario700,
                      foregroundColor: RedesignColors.primario50,
                      side: BorderSide.none,
                      minimumSize:
                          const Size(double.infinity, RedesignSpacing.inputHeight),
                      shape: RoundedRectangleBorder(
                        borderRadius: RedesignRadius.buttonLgBr,
                      ),
                    ),
                    child: Text(
                      isOwn ? 'Editar' : 'Añadir mi video/fotos',
                      style: RedesignType.buttonLg.copyWith(
                        color: RedesignColors.primario50,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMedia(String? gifUrl) {
    if (_isYoutubeVideo && _youtubeController != null) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: YoutubePlayer(controller: _youtubeController!),
      );
    }
    if (!_isYoutubeVideo &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      return VideoPlayer(_videoController!);
    }
    if (gifUrl != null && gifUrl.isNotEmpty) {
      return Image.network(
        gifUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(
            Icons.play_circle_outline_rounded,
            color: RedesignColors.primario400,
            size: 48,
          ),
        ),
      );
    }
    return const Center(
      child: Icon(
        Icons.play_circle_outline_rounded,
        color: RedesignColors.primario400,
        size: 48,
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(child: InteractiveViewer(child: Image.network(url))),
      ),
    ));
  }

  void _showEdit(
    BuildContext context, {
    required bool duplicate,
    bool mediaOverlay = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: RedesignTheme.theme,
        child: _CreateExerciseSheet(
          exerciseToEdit: widget.exercise,
          duplicate: duplicate,
          mediaOverlay: mediaOverlay,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Eliminar ejercicio',
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          '¿Eliminar "${widget.exercise['name']}" de tu lista? '
          'Esta acción no se puede deshacer.',
          style: RedesignType.label.copyWith(color: RedesignColors.primario200),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.danger,
              foregroundColor: RedesignColors.peligro200,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref
          .read(trainerServiceProvider)
          .deleteExercise(widget.exercise['id'] as String);
      ref.invalidate(exercisesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ejercicio eliminado'),
            backgroundColor: RedesignColors.success,
          ),
        );
      }
    } catch (e) {
      final inUse = e.toString().contains('foreign key') ||
          e.toString().contains('23503');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              inUse
                  ? 'No se puede eliminar: el ejercicio está en uso en una rutina.'
                  : 'Error al eliminar: $e',
            ),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    }
  }
}

// ── Overlay action button in hero area ──────────────────────────────────────

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  const _HeroButton({required this.icon, this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.40),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: RedesignColors.primario50, size: 18),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Provider for muscle groups (unchanged — kept in this file)
// ---------------------------------------------------------------------------

final muscleGroupsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMuscleGroups();
});

// ---------------------------------------------------------------------------
// Create / Edit Exercise Sheet
// ---------------------------------------------------------------------------

class _CreateExerciseSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? exerciseToEdit;
  final bool duplicate;
  /// When true: the exercise is a global seed and we only write media to
  /// trainer_exercise_media (no duplication, no name/instructions editing).
  final bool mediaOverlay;

  const _CreateExerciseSheet({
    this.exerciseToEdit,
    this.duplicate = false,
    this.mediaOverlay = false,
  });

  @override
  ConsumerState<_CreateExerciseSheet> createState() =>
      _CreateExerciseSheetState();
}

class _CreateExerciseSheetState extends ConsumerState<_CreateExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  String _selectedMuscleGroup = 'Pecho';
  Uint8List? _videoBytes;
  String? _videoExt;
  String? _videoName;
  final List<_PickedImage> _newImages = [];
  String? _existingVideoUrl;
  final List<String> _existingImageUrls = [];
  bool _isLoading = false;

  bool get _isEditMode =>
      widget.exerciseToEdit != null && !widget.duplicate && !widget.mediaOverlay;
  String get _title => widget.mediaOverlay
      ? 'Añadir mi video/fotos'
      : (widget.duplicate
          ? 'Duplicar y editar'
          : (_isEditMode ? 'Editar ejercicio' : 'Nuevo ejercicio'));

  @override
  void initState() {
    super.initState();
    if (widget.exerciseToEdit != null) {
      if (!widget.mediaOverlay) {
        // Normal edit / duplicate / create: pre-populate all fields.
        _nameController.text = widget.exerciseToEdit!['name'] as String? ?? '';
        _instructionsController.text =
            widget.exerciseToEdit!['instructions'] as String? ?? '';
        _selectedMuscleGroup =
            widget.exerciseToEdit!['muscle_group'] as String? ?? 'Pecho';
        final existingVideo = widget.exerciseToEdit!['video_url'] as String?;
        if (existingVideo != null && existingVideo.isNotEmpty) {
          if (_isYoutubeUrl(existingVideo)) {
            _youtubeUrlController.text = existingVideo;
          } else {
            _existingVideoUrl = existingVideo;
          }
        }
        _existingImageUrls.addAll(
          (widget.exerciseToEdit!['image_urls'] as List?)?.cast<String>() ?? [],
        );
      } else {
        // Media-overlay mode: load the trainer's existing overlay row (if any)
        // so the form shows what they already have.
        _loadExistingOverlay();
      }
    }
  }

  /// Fetch any previously saved trainer_exercise_media row and pre-populate
  /// the media fields in the form.
  Future<void> _loadExistingOverlay() async {
    final exerciseId = widget.exerciseToEdit!['id'] as String?;
    if (exerciseId == null) return;
    try {
      final trainerId = await ref.read(trainerServiceProvider).getTrainerId();
      if (trainerId == null || !mounted) return;
      final row = await ref
          .read(trainerServiceProvider)
          .getOverlayRow(trainerId, exerciseId);
      if (row == null || !mounted) return;
      setState(() {
        final v = row['video_url'] as String?;
        if (v != null && v.isNotEmpty) {
          if (_isYoutubeUrl(v)) {
            _youtubeUrlController.text = v;
          } else {
            _existingVideoUrl = v;
          }
        }
        _existingImageUrls
          ..clear()
          ..addAll((row['image_urls'] as List?)?.cast<String>() ?? []);
      });
    } catch (_) {
      // Overlay row may not exist yet — that's fine.
    }
  }

  bool _isYoutubeUrl(String url) =>
      url.contains('youtube.com') || url.contains('youtu.be');

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: RedesignColors.primario900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: RedesignColors.primario50,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    _title,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Placeholder to balance the close button
                const SizedBox(width: 48),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Form ─────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // In media-overlay mode we only show the media picker —
                    // no name / muscle-group / instructions editing.
                    if (!widget.mediaOverlay) ...[
                      // Nombre
                      _FieldLabel(label: 'Nombre'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameController,
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario50),
                        decoration: const InputDecoration(
                          hintText: 'Ej: Press inclinado en Smith',
                        ),
                        validator: (v) =>
                            v?.isEmpty == true ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 20),

                      // Grupo muscular
                      _FieldLabel(label: 'Grupo muscular'),
                      const SizedBox(height: 10),
                      _MuscleGroupChips(
                        selected: _selectedMuscleGroup,
                        onSelect: (g) =>
                            setState(() => _selectedMuscleGroup = g),
                      ),
                      const SizedBox(height: 20),

                      // Instrucciones
                      _FieldLabelOptional(label: 'Instrucciones'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _instructionsController,
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario50),
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Ej: banco a 30°, bajar la barra al pecho alto…',
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Videos y fotos
                    if (widget.mediaOverlay)
                      _FieldLabel(label: 'Videos y fotos')
                    else
                      _FieldLabelOptional(label: 'Videos y fotos'),
                    const SizedBox(height: 12),
                    _MediaTiles(
                      videoName: _videoName,
                      existingVideoUrl: _existingVideoUrl,
                      youtubeUrl: _youtubeUrlController.text,
                      existingImageUrls: _existingImageUrls,
                      newImages: _newImages,
                      onPickVideo: _pickVideo,
                      onRemoveVideo: () => setState(() {
                        _videoBytes = null;
                        _videoExt = null;
                        _videoName = null;
                        _existingVideoUrl = null;
                      }),
                      onYoutubeChanged: (v) => setState(() {}),
                      youtubeController: _youtubeUrlController,
                      isYoutubeUrl: _isYoutubeUrl,
                      onPickImage: _pickImage,
                      onRemoveExisting: (i) =>
                          setState(() => _existingImageUrls.removeAt(i)),
                      onRemoveNew: (i) =>
                          setState(() => _newImages.removeAt(i)),
                    ),
                    const SizedBox(height: 32),

                    // CTA
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveExercise,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: RedesignColors.onActionPrimary,
                              ),
                            )
                          : Text(
                              _isEditMode
                                  ? 'Guardar cambios'
                                  : 'Crear ejercicio',
                            ),
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

  Future<void> _pickVideo() async {
    final video = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    final bytes = await video.readAsBytes();
    if (!mounted) return;
    setState(() {
      _videoBytes = bytes;
      _videoExt = _ext(video.name, fallback: 'mp4');
      _videoName = video.name;
      _existingVideoUrl = null;
    });
  }

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _newImages.add(_PickedImage(bytes: bytes, ext: _ext(image.name, fallback: 'jpg')));
    });
  }

  String _ext(String name, {required String fallback}) {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : fallback;
  }

  Future<void> _saveExercise() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final service = ref.read(trainerServiceProvider);
      final storageService = ref.read(storageServiceProvider);
      String exerciseId;

      if (widget.mediaOverlay) {
        // Media-overlay mode: write to trainer_exercise_media, not exercises.
        // The exercise row is the global/seed one — we never touch it.
        exerciseId = widget.exerciseToEdit!['id'] as String;
        // (No name/instructions update — the trainer's name field is hidden.)
      } else if (_isEditMode) {
        exerciseId = widget.exerciseToEdit!['id'] as String;
        await service.updateExercise(
          exerciseId,
          name: _nameController.text,
          muscleGroup: _selectedMuscleGroup,
          instructions: _instructionsController.text,
        );
      } else {
        final src = widget.duplicate ? widget.exerciseToEdit : null;
        final data = await service.createExercise(
          name: _nameController.text,
          muscleGroup: _selectedMuscleGroup,
          instructions: _instructionsController.text,
          category: src?['category'] as String?,
          equipment: (src?['equipment'] as List?)?.cast<String>(),
          gifUrl: src?['gif_url'] as String?,
          mediaId: src?['media_id'] as String?,
        );
        exerciseId = data['id'] as String;
      }

      String? videoUrl;
      final youtubeUrl = _youtubeUrlController.text.trim();
      if (youtubeUrl.isNotEmpty) {
        videoUrl = youtubeUrl;
      } else if (_videoBytes != null) {
        videoUrl = await storageService.uploadExerciseVideoBytes(
          _videoBytes!,
          _videoExt ?? 'mp4',
          exerciseId,
        );
      } else {
        videoUrl = _existingVideoUrl;
      }

      final imageUrls = List<String>.from(_existingImageUrls);
      for (var i = 0; i < _newImages.length; i++) {
        imageUrls.add(await storageService.uploadExerciseImageBytes(
          _newImages[i].bytes,
          _newImages[i].ext,
          exerciseId,
          i,
        ));
      }

      if (widget.mediaOverlay) {
        // Upsert into the overlay table — no changes to the exercises row.
        await service.upsertTrainerExerciseMedia(
          exerciseId,
          videoUrl: videoUrl,
          imageUrls: imageUrls,
        );
      } else if (_isEditMode || videoUrl != null || imageUrls.isNotEmpty) {
        await service.updateExerciseMedia(
          exerciseId,
          videoUrl: videoUrl,
          imageUrls: imageUrls,
        );
      }

      ref.invalidate(exercisesProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.mediaOverlay
                ? 'Media guardada'
                : (_isEditMode ? 'Ejercicio actualizado' : 'Ejercicio creado')),
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
}

// ---------------------------------------------------------------------------
// Form field label helpers
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: RedesignType.bodySm.copyWith(
          color: RedesignColors.primario50,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _FieldLabelOptional extends StatelessWidget {
  final String label;
  const _FieldLabelOptional({required this.label});

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: ' (opcional)',
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario400,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Muscle group chip selector (wrap layout)
// ---------------------------------------------------------------------------

class _MuscleGroupChips extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  static const _groups = [
    'Pecho', 'Espalda', 'Piernas', 'Hombros', 'Brazos', 'Core',
  ];

  const _MuscleGroupChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _groups.map((g) {
        final active = selected == g;
        return GestureDetector(
          onTap: () => onSelect(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  active ? Colors.transparent : RedesignColors.primario700,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active
                    ? RedesignColors.actionPrimaryDark
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              g,
              style: RedesignType.buttonSm.copyWith(
                color: active
                    ? RedesignColors.actionPrimaryDark
                    : RedesignColors.primario50,
                fontWeight:
                    active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Media tiles (video + YouTube + photos) for the create form
// ---------------------------------------------------------------------------

class _MediaTiles extends StatelessWidget {
  final String? videoName;
  final String? existingVideoUrl;
  final String youtubeUrl;
  final List<String> existingImageUrls;
  final List<_PickedImage> newImages;
  final VoidCallback onPickVideo;
  final VoidCallback onRemoveVideo;
  final ValueChanged<String> onYoutubeChanged;
  final TextEditingController youtubeController;
  final bool Function(String) isYoutubeUrl;
  final VoidCallback onPickImage;
  final void Function(int) onRemoveExisting;
  final void Function(int) onRemoveNew;

  const _MediaTiles({
    required this.videoName,
    required this.existingVideoUrl,
    required this.youtubeUrl,
    required this.existingImageUrls,
    required this.newImages,
    required this.onPickVideo,
    required this.onRemoveVideo,
    required this.onYoutubeChanged,
    required this.youtubeController,
    required this.isYoutubeUrl,
    required this.onPickImage,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = videoName != null || existingVideoUrl != null;
    final hasYoutube = youtubeUrl.isNotEmpty;
    final totalImages = existingImageUrls.length + newImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Three upload tiles ────────────────────────────────────────
        Row(
          children: [
            _UploadTile(
              icon: Icons.videocam_rounded,
              label: hasVideo ? (videoName ?? 'Video actual') : 'Grabar o subir',
              active: hasVideo,
              onTap: hasVideo ? onRemoveVideo : onPickVideo,
            ),
            const SizedBox(width: 10),
            _UploadTile(
              icon: Icons.link_rounded,
              label: hasYoutube ? 'YouTube' : 'Link YouTube',
              active: hasYoutube,
              onTap: () => _showYoutubeDialog(context),
            ),
            const SizedBox(width: 10),
            _UploadTile(
              icon: Icons.image_rounded,
              label: totalImages > 0 ? '$totalImages foto${totalImages > 1 ? 's' : ''}' : 'Fotos',
              active: totalImages > 0,
              onTap: onPickImage,
            ),
          ],
        ),

        // ── Existing image strip ──────────────────────────────────────
        if (totalImages > 0) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: totalImages,
              itemBuilder: (context, index) {
                final isExisting = index < existingImageUrls.length;
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 80,
                      height: 80,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: RedesignColors.primario700,
                      ),
                      child: isExisting
                          ? Image.network(
                              existingImageUrls[index],
                              fit: BoxFit.cover,
                            )
                          : Image.memory(
                              newImages[index - existingImageUrls.length].bytes,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () => isExisting
                            ? onRemoveExisting(index)
                            : onRemoveNew(index - existingImageUrls.length),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: RedesignColors.danger,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  void _showYoutubeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Link de YouTube',
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: youtubeController,
          onChanged: onYoutubeChanged,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'https://youtube.com/watch?v=...',
            prefixIcon: Icon(Icons.play_circle_outline_rounded, color: Colors.red),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final url = youtubeController.text.trim();
              if (url.isEmpty || isYoutubeUrl(url)) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Single dashed upload tile ────────────────────────────────────────────────

class _UploadTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UploadTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? RedesignColors.actionPrimaryDark
                  : RedesignColors.primario500,
              width: 1.5,
              // Dashed border emulated via solid — Flutter doesn't support
              // native dashed borders without a custom painter; solid is
              // visually close enough here.
            ),
            color: active
                ? RedesignColors.actionPrimaryDark.withValues(alpha: 0.07)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active
                    ? RedesignColors.actionPrimaryDark
                    : RedesignColors.primario300,
                size: 22,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: RedesignType.label.copyWith(
                  color: active
                      ? RedesignColors.actionPrimaryDark
                      : RedesignColors.primario300,
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Raw-bytes image holder (web-safe — no dart:io File)
// ---------------------------------------------------------------------------

class _PickedImage {
  final Uint8List bytes;
  final String ext;
  const _PickedImage({required this.bytes, required this.ext});
}
