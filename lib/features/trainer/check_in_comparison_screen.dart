import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Side-by-side comparison of two check-ins' photos so the trainer can gauge
/// progress over time. Optimised for wide screens (web/desktop): two columns
/// side by side, stacking on narrow phones.
class CheckInComparisonScreen extends StatefulWidget {
  /// Check-ins as returned by the trainer service (newest first). Each map has
  /// `created_at` and `photo_urls` (array) / `photo_url` (legacy single).
  final List<Map<String, dynamic>> checkIns;

  const CheckInComparisonScreen({super.key, required this.checkIns});

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
    // Left = oldest, right = newest (list is newest-first).
    _leftIndex = widget.checkIns.length - 1;
    _rightIndex = 0;
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
