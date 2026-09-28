import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Side-by-side comparison of two check-ins' photos so the trainer can gauge
/// progress over time. Optimised for wide screens (web/desktop): two columns
/// side by side, stacking on narrow phones.
class CheckInComparisonScreen extends StatefulWidget {
  /// Check-ins as returned by the trainer service (newest first). Each map has
  /// `created_at` and `photo_urls` (array) / `photo_url` (legacy single).
  final List<Map<String, dynamic>> checkIns;

  /// Optional pre-selected left/right indices. When provided (e.g. from the
  /// grid select-two flow), the comparison opens with those two check-ins
  /// pre-loaded instead of the default oldest/newest pair.
  final int? initialLeft;
  final int? initialRight;

  const CheckInComparisonScreen({
    super.key,
    required this.checkIns,
    this.initialLeft,
    this.initialRight,
  });

  @override
  State<CheckInComparisonScreen> createState() =>
      _CheckInComparisonScreenState();
}

class _CheckInComparisonScreenState extends State<CheckInComparisonScreen> {
  late int _leftIndex;
  late int _rightIndex;

  @override
  void initState() {
    super.initState();
    // Use caller-supplied indices if provided, otherwise default oldest/newest.
    _leftIndex = widget.initialLeft ?? widget.checkIns.length - 1;
    _rightIndex = widget.initialRight ?? 0;
  }

  static List<String> _photosOf(Map<String, dynamic> ci) {
    final list = (ci['photo_urls'] as List?)
            ?.whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    if (list.isNotEmpty) return list;
    final single = ci['photo_url'] as String?;
    return (single != null && single.isNotEmpty) ? [single] : [];
  }

  static String _dateLabel(Map<String, dynamic> ci) {
    // Prefer trainer-assigned date over the submission timestamp.
    final assigned = ci['assigned_date'] as String?;
    if (assigned != null) {
      final d = DateTime.tryParse(assigned);
      if (d != null) {
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    }
    final raw = ci['created_at'] as String?;
    if (raw == null) return 'Sin fecha';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return 'Sin fecha';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Comparar check-ins'),
        backgroundColor: AppColors.primary,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 700;
          final left = _ComparisonColumn(
            checkIns: widget.checkIns,
            selectedIndex: _leftIndex,
            photos: _photosOf(widget.checkIns[_leftIndex]),
            onChanged: (i) => setState(() => _leftIndex = i),
            dateLabel: _dateLabel,
          );
          final right = _ComparisonColumn(
            checkIns: widget.checkIns,
            selectedIndex: _rightIndex,
            photos: _photosOf(widget.checkIns[_rightIndex]),
            onChanged: (i) => setState(() => _rightIndex = i),
            dateLabel: _dateLabel,
          );

          if (wide) {
            // Bounded height + per-column scroll so tall photos don't overflow.
            return SizedBox(
              height: constraints.maxHeight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: SingleChildScrollView(child: left)),
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: right)),
                  ],
                ),
              ),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [left, const SizedBox(height: 24), right],
            ),
          );
        },
      ),
    );
  }
}

class _ComparisonColumn extends StatelessWidget {
  final List<Map<String, dynamic>> checkIns;
  final int selectedIndex;
  final List<String> photos;
  final ValueChanged<int> onChanged;
  final String Function(Map<String, dynamic>) dateLabel;

  const _ComparisonColumn({
    required this.checkIns,
    required this.selectedIndex,
    required this.photos,
    required this.onChanged,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedIndex,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
              items: [
                for (var i = 0; i < checkIns.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('Check-in ${dateLabel(checkIns[i])}'),
                  ),
              ],
              onChanged: (i) {
                if (i != null) onChanged(i);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (photos.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Sin fotos en este check-in',
              style: TextStyle(color: AppColors.textLight),
            ),
          )
        else
          for (final url in photos)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: () => _fullScreen(context, url),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Icon(Icons.broken_image_rounded,
                          color: Colors.grey, size: 48),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }

  void _fullScreen(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet showing all check-ins for one student as a thumbnail grid.
///
/// Usage:
///   showModalBottomSheet(
///     context: context,
///     isScrollControlled: true,
///     backgroundColor: Colors.transparent,
///     builder: (_) => CheckInGridSheet(checkIns: checkIns),
///   );
///
/// Each cell shows the first photo and the date. Tapping opens the full-screen
/// viewer. A "Comparar" button becomes active after the user taps two cells;
/// it opens [CheckInComparisonScreen] with those two pre-selected.
class CheckInGridSheet extends StatefulWidget {
  /// Check-ins ordered newest-first, same shape used throughout the app
  /// (`photo_urls` list / `photo_url` fallback, `assigned_date`, `created_at`).
  final List<Map<String, dynamic>> checkIns;

  const CheckInGridSheet({super.key, required this.checkIns});

  @override
  State<CheckInGridSheet> createState() => _CheckInGridSheetState();
}

class _CheckInGridSheetState extends State<CheckInGridSheet> {
  // Indices into widget.checkIns that the user has selected for comparison.
  final List<int> _selected = [];

  // ---- helpers -------------------------------------------------------

  static List<String> _photosOf(Map<String, dynamic> ci) {
    final list = (ci['photo_urls'] as List?)
            ?.whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ??
        [];
    if (list.isNotEmpty) return list;
    final single = ci['photo_url'] as String?;
    return (single != null && single.isNotEmpty) ? [single] : [];
  }

  static String _dateLabel(Map<String, dynamic> ci) {
    final assigned = ci['assigned_date'] as String?;
    if (assigned != null) {
      final d = DateTime.tryParse(assigned);
      if (d != null) {
        return '${d.day.toString().padLeft(2, '0')}/'
            '${d.month.toString().padLeft(2, '0')}/'
            '${d.year}';
      }
    }
    final raw = ci['created_at'] as String?;
    if (raw == null) return 'Sin fecha';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return 'Sin fecha';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  void _tapCell(int index) {
    setState(() {
      if (_selected.contains(index)) {
        _selected.remove(index);
      } else if (_selected.length < 2) {
        _selected.add(index);
      } else {
        // Replace the oldest selection.
        _selected.removeAt(0);
        _selected.add(index);
      }
    });
  }

  void _openViewer(BuildContext ctx, List<String> urls, int initial) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => _GridPhotoViewer(urls: urls, initialIndex: initial),
      ),
    );
  }

  void _openComparison(BuildContext ctx) {
    if (_selected.length != 2) return;
    // Sort so left is the older one (higher index = older in newest-first list).
    final sorted = List<int>.from(_selected)..sort();
    Navigator.pop(ctx); // close the grid sheet
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => CheckInComparisonScreen(
          checkIns: widget.checkIns,
          initialLeft: sorted[1], // older
          initialRight: sorted[0], // newer
        ),
      ),
    );
  }

  // ---- build ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final canCompare = _selected.length == 2;

    return Container(
      constraints: BoxConstraints(maxHeight: screenH * 0.92),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fotos Check-in',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _selected.isEmpty
                            ? 'Tocá dos fotos para comparar'
                            : _selected.length == 1
                                ? 'Seleccioná una más para comparar'
                                : 'Listo — tocá Comparar',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _selected.clear()),
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Grid
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.75,
              ),
              itemCount: widget.checkIns.length,
              itemBuilder: (ctx, i) {
                final ci = widget.checkIns[i];
                final photos = _photosOf(ci);
                final thumb = photos.isNotEmpty ? photos.first : null;
                final label = _dateLabel(ci);
                final isSelected = _selected.contains(i);
                final selOrder = isSelected ? _selected.indexOf(i) + 1 : 0;

                return GestureDetector(
                  onTap: () {
                    if (photos.isNotEmpty && _selected.isEmpty) {
                      // No selection in progress — open viewer on simple tap.
                      _openViewer(ctx, photos, 0);
                    } else {
                      _tapCell(i);
                    }
                  },
                  onLongPress: () => _tapCell(i),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: thumb != null
                            ? CachedNetworkImage(
                                imageUrl: thumb,
                                fit: BoxFit.cover,
                                // Thumbnail-size decode — prevents full-res
                                // decodes from evicting the cache and turning
                                // grid cells black after the viewer closes.
                                memCacheWidth: 300,
                                placeholder: (_, __) => Container(
                                  color: AppColors.surfaceVariant,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: AppColors.surfaceVariant,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.white24,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.photo_rounded,
                                  color: Colors.white24,
                                ),
                              ),
                      ),

                      // Dark gradient overlay at bottom
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(14)),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(6, 12, 6, 6),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.75),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Selection border + badge
                      if (isSelected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.primary,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      if (isSelected)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 1.5),
                            ),
                            child: Center(
                              child: Text(
                                '$selOrder',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Compare button anchored at bottom
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: canCompare
                ? SafeArea(
                    key: const ValueKey('compare-btn'),
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          icon: const Icon(Icons.compare_rounded, size: 20),
                          label: const Text(
                            'Comparar fotos',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () => _openComparison(context),
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('compare-none')),
          ),
        ],
      ),
    );
  }
}

/// Lightweight full-screen photo viewer used inside [CheckInGridSheet].
/// Replicates [CheckInPhotoViewerScreen] without requiring a cross-import.
class _GridPhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _GridPhotoViewer({required this.urls, required this.initialIndex});

  @override
  State<_GridPhotoViewer> createState() => _GridPhotoViewerState();
}

class _GridPhotoViewerState extends State<_GridPhotoViewer> {
  late final PageController _ctrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
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
        controller: _ctrl,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
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
        ),
      ),
    );
  }
}
