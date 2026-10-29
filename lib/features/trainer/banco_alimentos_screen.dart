import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';

// ---------------------------------------------------------------------------
// BancoAlimentosScreen
//
// Full-screen list of default_meals. The trainer selects one and the screen
// pops with the chosen meal map so the caller (Nueva comida sheet) can prefill
// its form fields.
// ---------------------------------------------------------------------------

class BancoAlimentosScreen extends ConsumerStatefulWidget {
  const BancoAlimentosScreen({super.key});

  @override
  ConsumerState<BancoAlimentosScreen> createState() =>
      _BancoAlimentosScreenState();
}

class _BancoAlimentosScreenState extends ConsumerState<BancoAlimentosScreen> {
  String _search = '';

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> meals) {
    final q = _search.toLowerCase().trim();
    if (q.isEmpty) return meals;
    return meals.where((m) {
      final title = (m['meal_title'] as String? ?? '').toLowerCase();
      final desc = (m['meal_description'] as String? ?? '').toLowerCase();
      return title.contains(q) || desc.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final mealsAsync = ref.watch(defaultMealsProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'Banco de alimentos',
            style: TextStyle(
              color: RedesignColors.primario50,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
        body: Column(
          children: [
            // ── Search ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: InputDecoration(
                  hintText: 'Buscar alimento',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: RedesignColors.primario400),
                  filled: true,
                  fillColor: RedesignColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(RedesignRadius.input),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
            ),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: mealsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: RedesignColors.actionPrimary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(
                          color: RedesignColors.danger)),
                ),
                data: (meals) {
                  if (meals.isEmpty) {
                    return Center(
                      child: Text(
                        'El banco de alimentos está vacío.',
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario300),
                      ),
                    );
                  }

                  final filtered = _filter(meals);

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No hay resultados para "$_search".',
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario300),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final meal = filtered[index];
                      return _MealRow(
                        meal: meal,
                        onAdd: () => Navigator.pop(context, meal),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MealRow
// ---------------------------------------------------------------------------

class _MealRow extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onAdd;

  const _MealRow({required this.meal, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final title = (meal['meal_title'] as String?) ?? 'Comida';
    final kcal = meal['calories'] as int?;
    final imageUrl = meal['image_url'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _Thumb(),
                    errorWidget: (_, __, ___) => const _Thumb(),
                  )
                : const _Thumb(),
          ),
          const SizedBox(width: 12),
          // Title + kcal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (kcal != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '$kcal kcal',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Add button
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RedesignColors.secundario300.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: RedesignColors.secundario300
                        .withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.add_rounded,
                  color: RedesignColors.secundario300, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: RedesignColors.primario800,
      child: const Icon(Icons.restaurant_rounded,
          size: 22, color: RedesignColors.primario400),
    );
  }
}
