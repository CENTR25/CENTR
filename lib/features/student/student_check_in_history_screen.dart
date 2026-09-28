import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import '../trainer/check_in_comparison_screen.dart' show CheckInGridSheet;

class StudentCheckInHistoryScreen extends ConsumerWidget {
  const StudentCheckInHistoryScreen({super.key});

  void _openGrid(
    BuildContext context,
    List<Map<String, dynamic>> checkIns,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckInGridSheet(checkIns: checkIns),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(myCheckInsProvider);

    // Resolve loaded check-ins for the AppBar action (null while loading).
    final loadedCheckIns = historyAsync.valueOrNull;
    final hasPhotos =
        loadedCheckIns != null && loadedCheckIns.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Check-ins'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (hasPhotos)
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: 'Expandir',
              onPressed: () => _openGrid(context, loadedCheckIns),
            ),
        ],
      ),
      body: historyAsync.when(
        data: (checkIns) {
          if (checkIns.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Icon(
                      Icons.photo_camera_rounded,
                      size: 64,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Aún no tienes check-ins',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tus fotos de progreso aparecerán aquí',
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: checkIns.length,
            itemBuilder: (context, index) {
              return _CheckInCard(checkIn: checkIns[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error al cargar: $e',
            style: const TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }
}

class _CheckInCard extends StatelessWidget {
  final Map<String, dynamic> checkIn;

  const _CheckInCard({required this.checkIn});

  @override
  Widget build(BuildContext context) {
    // Prefer trainer-assigned date if set, otherwise show submission date.
    final assignedRaw = checkIn['assigned_date'] as String?;
    final createdAt = DateTime.parse(checkIn['created_at'] as String).toLocal();
    final displayDate = assignedRaw != null
        ? (DateTime.tryParse(assignedRaw) ?? createdAt)
        : createdAt;
    final comment = checkIn['comment'] as String?;

    // photo_urls is a jsonb array; fall back to single photo_url for older rows
    final rawUrls = checkIn['photo_urls'];
    final List<String> photoUrls;
    if (rawUrls is List && rawUrls.isNotEmpty) {
      photoUrls = rawUrls.map((u) => u.toString()).toList();
    } else {
      final single = checkIn['photo_url'] as String?;
      photoUrls = single != null ? [single] : [];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date + photo count header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${displayDate.day.toString().padLeft(2, '0')}/'
                  '${displayDate.month.toString().padLeft(2, '0')}/'
                  '${displayDate.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (photoUrls.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.photo_rounded,
                          size: 12,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${photoUrls.length} foto${photoUrls.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            if (comment != null && comment.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                comment,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (photoUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: photoUrls.length,
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => _openPhotoViewer(context, photoUrls, i),
                      child: Container(
                        width: 90,
                        margin: EdgeInsets.only(
                          right: i < photoUrls.length - 1 ? 10 : 0,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surfaceVariant,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CachedNetworkImage(
                          imageUrl: photoUrls[i],
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openPhotoViewer(
    BuildContext context,
    List<String> urls,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckInPhotoViewerScreen(
          urls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

/// Full-screen swipeable photo viewer. Shared by student history and trainer
/// gallery (exported so trainer screens can reuse it).
class CheckInPhotoViewerScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const CheckInPhotoViewerScreen({
    super.key,
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<CheckInPhotoViewerScreen> createState() =>
      _CheckInPhotoViewerScreenState();
}

class _CheckInPhotoViewerScreenState
    extends State<CheckInPhotoViewerScreen> {
  late final PageController _controller;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_current + 1} / ${widget.urls.length}',
          style: const TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (context, i) {
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: widget.urls[i],
                fit: BoxFit.contain,
                placeholder: (_, __) => const CircularProgressIndicator(
                  color: AppColors.primary,
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white24,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
