import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../core/utils/string_utils.dart';
import '../../../models/affiliated_brand_model.dart';
import '../../../models/news_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/affiliated_brand_service.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/news_service.dart';
import '../../../services/exercise_import.dart' show exerciseNameKey;
import '../../../services/supabase_service.dart';
import '../../shared/exercise_import_sheet.dart';
import '../../shared/redesign_toast.dart';
import '../../trainer/banco_alimentos_screen.dart';
import '../widgets/admin_add_exercise_sheet.dart';
import '../widgets/admin_common.dart';
import 'admin_brand_editor_screen.dart';
import 'admin_news_editor_screen.dart';
import '../../trainer/muscle_groups_editor_screen.dart';

/// Admin Contenido — Noticias / Marcas / Ejercicios under one tab with
/// segmented pills (Figma Third + Four Batch).
class AdminContentView extends ConsumerStatefulWidget {
  const AdminContentView({super.key});

  @override
  ConsumerState<AdminContentView> createState() => _AdminContentViewState();
}

class _AdminContentViewState extends ConsumerState<AdminContentView> {
  int _index = 0;

  void _add() {
    switch (_index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminNewsEditorScreen()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminBrandEditorScreen()),
        );
        break;
      case 2:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const AdminAddExerciseSheet(),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Recetas (index 3) has no "add" action yet — the recetario is not
    // implemented, so this tab only exposes the global on/off switch.
    const addLabels = ['Noticia', 'Marca', 'Ejercicio'];
    final showAdd = _index < addLabels.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminGradientHeader(
          title: 'Contenido',
          trailing: showAdd
              ? AdminAddPillButton(label: addLabels[_index], onTap: _add)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: AdminSegmentedPills(
            labels: const ['Noticias', 'Marcas', 'Ejercicios', 'Recetas'],
            activeIndex: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _index,
            children: const [
              _NewsList(),
              _BrandsList(),
              _ExercisesList(),
              _RecetasSection(),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Recetas ────────────────────────────────────────────────────────────────
/// Global recetario controls. The recipe book itself is not built yet, so for
/// now this is just the master on/off switch (+ a "coming soon" note). Recipe
/// management can slot in here once the feature exists.
class _RecetasSection extends ConsumerWidget {
  const _RecetasSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabledAsync = ref.watch(recipesEnabledProvider);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 130),
      children: [
        // Alimentos: admin entry to the food bank (global foods + meals, CSV import).
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BancoAlimentosScreen()),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_rounded,
                    color: RedesignColors.secundario300),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Alimentos (banco global, importar CSV)',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: RedesignColors.primario400),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AdminCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mostrar recetario',
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Activa la tarjeta “Recetario oficial” en el inicio de '
                      'los alumnos. Mantenela apagada mientras no esté lista.',
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              enabledAsync.when(
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Icon(Icons.error_outline_rounded,
                    color: RedesignColors.danger, size: 20),
                data: (enabled) => Switch(
                  value: enabled,
                  activeThumbColor: RedesignColors.onActionPrimary,
                  activeTrackColor: RedesignColors.actionPrimary,
                  onChanged: (v) async {
                    await ref
                        .read(appSettingsServiceProvider)
                        .setBool('recipes_enabled', v);
                    ref.invalidate(recipesEnabledProvider);
                    if (context.mounted) {
                      showRedesignToast(
                        context,
                        title: v
                            ? 'Recetario activado'
                            : 'Recetario desactivado',
                        subtitle: v
                            ? 'Los alumnos ya pueden verlo.'
                            : 'Oculto para los alumnos.',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Text(
            'La gestión de recetas estará disponible próximamente.',
            textAlign: TextAlign.center,
            style:
                RedesignType.label.copyWith(color: RedesignColors.primario300),
          ),
        ),
      ],
    );
  }
}

// ── Noticias ──────────────────────────────────────────────────────────────
class _NewsList extends ConsumerWidget {
  const _NewsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(allNewsProvider);
    return RefreshIndicator(
      color: RedesignColors.actionPrimary,
      backgroundColor: RedesignColors.primario800,
      onRefresh: () async {
        ref.invalidate(allNewsProvider);
        await ref.read(allNewsProvider.future);
      },
      child: newsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error('$e'),
        data: (items) {
          if (items.isEmpty) return _empty('No hay noticias todavía.');
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 130),
            children: [for (final n in items) _NewsCard(article: n)],
          );
        },
      ),
    );
  }
}

class _NewsCard extends ConsumerWidget {
  final NewsArticle article;
  const _NewsCard({required this.article});

  Future<void> _togglePublish(WidgetRef ref) async {
    await ref
        .read(newsServiceProvider)
        .updateNews(article.id, isPublished: !article.isPublished);
    ref.invalidate(allNewsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmDelete(context, 'esta noticia');
    if (ok != true) return;
    await ref.read(newsServiceProvider).deleteNews(article.id);
    ref.invalidate(allNewsProvider);
    if (context.mounted) {
      showRedesignToast(context,
          title: 'Noticia eliminada', subtitle: 'Se eliminó la noticia.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminNewsEditorScreen(article: article),
          ),
        ),
        child: Row(
          children: [
            _thumb(article.imageUrl, Icons.article_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeLabel(article),
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      AdminStatusPill(
                        label: article.isPublished ? 'Publicada' : 'Borrador',
                        color: article.isPublished
                            ? RedesignColors.success
                            : RedesignColors.primario400,
                      ),
                      AdminStatusPill(
                        label: article.sectionLabel,
                        color: RedesignColors.secundario400,
                      ),
                      if (article.hasLink)
                        const AdminStatusPill(
                          label: 'Con link',
                          color: RedesignColors.primario300,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _CardMenu(
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminNewsEditorScreen(article: article),
                ),
              ),
              toggleLabel: article.isPublished ? 'Despublicar' : 'Publicar',
              onToggle: () => _togglePublish(ref),
              onDelete: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(NewsArticle a) {
    if (a.updatedAt != null && a.updatedAt!.isAfter(a.createdAt)) {
      return 'Editada ${_relTime(a.updatedAt!)}';
    }
    return _relTime(a.createdAt);
  }
}

// ── Marcas ──────────────────────────────────────────────────────────────
class _BrandsList extends ConsumerWidget {
  const _BrandsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandsAsync = ref.watch(allBrandsProvider);
    return RefreshIndicator(
      color: RedesignColors.actionPrimary,
      backgroundColor: RedesignColors.primario800,
      onRefresh: () async {
        ref.invalidate(allBrandsProvider);
        await ref.read(allBrandsProvider.future);
      },
      child: brandsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error('$e'),
        data: (items) {
          if (items.isEmpty) return _empty('No hay marcas todavía.');
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 130),
            children: [for (final b in items) _BrandCard(brand: b)],
          );
        },
      ),
    );
  }
}

class _BrandCard extends ConsumerWidget {
  final AffiliatedBrand brand;
  const _BrandCard({required this.brand});

  Future<void> _toggleActive(WidgetRef ref) async {
    await ref.read(affiliatedBrandServiceProvider).updateBrand(
          brand.id,
          name: brand.name,
          discountCode: brand.discountCode,
          bannerText: brand.bannerText,
          websiteUrl: brand.websiteUrl,
          instagramUrl: brand.instagramUrl,
          logoUrl: brand.logoUrl,
          isActive: !brand.isActive,
          benefitDescription: brand.benefitDescription,
          category: brand.category,
          discountLabel: brand.discountLabel,
        );
    ref.invalidate(allBrandsProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmDelete(context, 'esta marca');
    if (ok != true) return;
    await ref.read(affiliatedBrandServiceProvider).deleteBrand(brand.id);
    ref.invalidate(allBrandsProvider);
    if (context.mounted) {
      showRedesignToast(context,
          title: 'Marca eliminada', subtitle: 'Se eliminó la marca.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminBrandEditorScreen(brand: brand),
          ),
        ),
        child: Row(
          children: [
            _thumb(brand.logoUrl, Icons.storefront_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    brand.name,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((brand.discountLabel?.trim().isNotEmpty ?? false)) ...[
                    const SizedBox(height: 4),
                    Text(
                      brand.discountLabel!,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.secundario300),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AdminStatusPill(
                    label: brand.isActive ? 'Activa' : 'Oculta',
                    color: brand.isActive
                        ? RedesignColors.success
                        : RedesignColors.primario400,
                  ),
                ],
              ),
            ),
            _CardMenu(
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminBrandEditorScreen(brand: brand),
                ),
              ),
              toggleLabel: brand.isActive ? 'Ocultar' : 'Mostrar',
              onToggle: () => _toggleActive(ref),
              onDelete: () => _delete(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ejercicios ─────────────────────────────────────────────────────────────
class _ExercisesList extends ConsumerStatefulWidget {
  const _ExercisesList();

  @override
  ConsumerState<_ExercisesList> createState() => _ExercisesListState();
}

class _ExercisesListState extends ConsumerState<_ExercisesList> {
  String _query = '';
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _deleting = false;

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    final q = foldSearch(_query);
    if (q.isEmpty) return items;
    return items
        .where((e) => foldSearch((e['name'] ?? '').toString()).contains(q))
        .toList();
  }

  List<Map<String, dynamic>> get _visible =>
      (ref.read(globalExercisesProvider).valueOrNull ?? const [])
          .where((e) => e['is_hidden'] != true)
          .toList();

  void _exitSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  Future<void> _refresh() async {
    ref.invalidate(globalExercisesProvider);
    await ref.read(globalExercisesProvider.future);
  }

  Future<void> _deleteSelected() async {
    setState(() => _deleting = true);
    final r = await confirmDeleteOrHideExercises(
      context,
      ids: _selected.toList(),
      run: ref.read(adminServiceProvider).deleteGlobalExercises,
    );
    if (!mounted) return;
    setState(() => _deleting = false);
    if (r != null) {
      _exitSelection();
      ref.invalidate(globalExercisesProvider);
    }
  }

  Future<void> _import() async {
    final ok = await ExerciseImportSheet.show(
      context,
      client: ref.read(supabaseClientProvider),
      ownerTrainerId: null,
      // Dedupe only against VISIBLE globals so hidden (soft-deleted) names
      // can be re-imported.
      existingNameKeys: {
        for (final e in _visible) exerciseNameKey(e['name']?.toString()),
      },
    );
    if (ok) ref.invalidate(globalExercisesProvider);
  }

  Future<void> _imageBank() async {
    final ok = await ExerciseImageBankSheet.show(
      context,
      client: ref.read(supabaseClientProvider),
      exercises: _visible,
      isAdmin: true,
    );
    if (ok) ref.invalidate(globalExercisesProvider);
  }

  Widget _toolButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          foregroundColor: RedesignColors.actionPrimary,
          side:
              const BorderSide(color: RedesignColors.actionPrimary, width: 1),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: const StadiumBorder()),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _selectionBar(List<Map<String, dynamic>> filtered) {
    final ids = filtered.map((e) => e['id'] as String).toList();
    final allOn = ids.isNotEmpty && ids.every(_selected.contains);
    final n = _selected.length;
    return Row(
      children: [
        IconButton(
          tooltip: 'Cancelar selección',
          icon: const Icon(Icons.close_rounded,
              color: RedesignColors.primario50),
          onPressed: _exitSelection,
        ),
        Expanded(
          child: Text(
            '$n seleccionado${n == 1 ? '' : 's'}',
            style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600),
          ),
        ),
        TextButton.icon(
          onPressed: () => setState(() =>
              allOn ? _selected.removeAll(ids) : _selected.addAll(ids)),
          style: TextButton.styleFrom(
              foregroundColor: RedesignColors.actionPrimary),
          icon: Icon(
              allOn ? Icons.deselect_rounded : Icons.select_all_rounded,
              size: 18),
          label: Text(allOn ? 'Quitar selección' : 'Seleccionar todos'),
        ),
        _deleting
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: RedesignColors.peligro400)),
              )
            : IconButton(
                tooltip: 'Eliminar seleccionados',
                icon: Icon(Icons.delete_rounded,
                    color: n == 0
                        ? RedesignColors.primario400
                        : RedesignColors.peligro400),
                onPressed: n == 0 ? null : _deleteSelected,
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final exAsync = ref.watch(globalExercisesProvider);
    final filtered = _filter(exAsync.valueOrNull ?? const []);
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
          child: TextField(
            onChanged: (val) => setState(() => _query = val),
            style:
                RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
            decoration: const InputDecoration(
              hintText: 'Buscar ejercicios',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: RedesignColors.primario300,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: _selecting
              ? _selectionBar(filtered)
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _toolButton(
                        'Grupos musculares',
                        Icons.category_rounded,
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MuscleGroupsEditorScreen(
                                  isAdmin: true)),
                        ),
                      ),
                      _toolButton('Importar CSV', Icons.upload_file_rounded,
                          _import),
                      _toolButton('Banco de imágenes',
                          Icons.photo_library_rounded, _imageBank),
                      _toolButton('Seleccionar', Icons.checklist_rounded,
                          () => setState(() => _selecting = true)),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: RefreshIndicator(
            color: RedesignColors.actionPrimary,
            backgroundColor: RedesignColors.primario800,
            onRefresh: _refresh,
            child: exAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _error('$e'),
              data: (items) {
                if (items.isEmpty) {
                  return _empty('No hay ejercicios todavía.');
                }
                if (filtered.isEmpty) {
                  return _empty('No se encontraron ejercicios.');
                }
                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 130),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final e = filtered[i];
                    final id = e['id'] as String;
                    return _ExerciseCard(
                      exercise: e,
                      selecting: _selecting,
                      selected: _selected.contains(id),
                      onToggle: () => setState(() => _selected.contains(id)
                          ? _selected.remove(id)
                          : _selected.add(id)),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  final Map<String, dynamic> exercise;
  final bool selecting;
  final bool selected;
  final VoidCallback onToggle;
  const _ExerciseCard({
    required this.exercise,
    required this.selecting,
    required this.selected,
    required this.onToggle,
  });

  Future<void> _toggleHidden(WidgetRef ref) async {
    final hidden = exercise['is_hidden'] as bool? ?? false;
    await ref
        .read(adminServiceProvider)
        .setGlobalExerciseHidden(exercise['id'] as String, !hidden);
    ref.invalidate(globalExercisesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    // Capture before the await: this card's ref is dead if the user leaves
    // the tab while the RPC runs.
    final container = ProviderScope.containerOf(context, listen: false);
    final r = await confirmDeleteOrHideExercises(
      context,
      ids: [exercise['id'] as String],
      run: ref.read(adminServiceProvider).deleteGlobalExercises,
    );
    if (r != null) container.invalidate(globalExercisesProvider);
  }

  /// First photo, else the GIF — for the list thumbnail.
  String? get _thumbUrl {
    final imgs = exercise['image_urls'];
    if (imgs is List) {
      for (final u in imgs) {
        final s = u?.toString() ?? '';
        if (s.isNotEmpty) return s;
      }
    }
    final gif = exercise['gif_url']?.toString() ?? '';
    return gif.isEmpty ? null : gif;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = exercise['is_hidden'] as bool? ?? false;
    final name = (exercise['name'] ?? 'Ejercicio').toString();
    final muscle = (exercise['muscle_group'] ?? '').toString();

    void openEditor() => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AdminAddExerciseSheet(exercise: exercise),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.all(14),
        onTap: selecting ? onToggle : openEditor,
        child: Row(
          children: [
            if (selecting) ...[
              Icon(
                selected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                color: selected
                    ? RedesignColors.actionPrimary
                    : RedesignColors.primario400,
              ),
              const SizedBox(width: 10),
            ],
            _thumb(_thumbUrl, Icons.fitness_center_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (muscle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      muscle,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AdminStatusPill(
                    label: hidden ? 'Oculto' : 'Visible',
                    color: hidden
                        ? RedesignColors.primario400
                        : RedesignColors.success,
                  ),
                ],
              ),
            ),
            if (!selecting)
              _CardMenu(
                onEdit: openEditor,
                toggleLabel: hidden ? 'Mostrar' : 'Ocultar',
                onToggle: () => _toggleHidden(ref),
                onDelete: () => _delete(context, ref),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Shared pieces ──────────────────────────────────────────────────────────
Widget _thumb(String? url, IconData fallback) {
  return Container(
    width: 56,
    height: 56,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: RedesignColors.primario700,
      borderRadius: BorderRadius.circular(14),
    ),
    child: (url != null && url.isNotEmpty)
        ? Image.network(url, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Icon(fallback, color: RedesignColors.primario300, size: 22))
        : Icon(fallback, color: RedesignColors.primario300, size: 22),
  );
}

Widget _empty(String text) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Text(
            text,
            style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
          ),
        ),
      ),
    ],
  );
}

Widget _error(String msg) {
  return ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Center(
          child: Text('Error: $msg',
              style: const TextStyle(color: RedesignColors.danger)),
        ),
      ),
    ],
  );
}

Future<bool?> _confirmDelete(BuildContext context, String what) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => Theme(
      data: RedesignTheme.theme,
      child: AlertDialog(
        backgroundColor: RedesignColors.primario800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Eliminar',
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            )),
        content: Text('¿Seguro que querés eliminar $what?',
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.primario50)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.danger)),
          ),
        ],
      ),
    ),
  );
}

String _relTime(DateTime dtUtc) {
  final dt = dtUtc.toLocal();
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays >= 7) {
    final w = (diff.inDays / 7).floor();
    return 'Hace $w semana${w == 1 ? '' : 's'}';
  }
  if (diff.inDays >= 1) {
    return diff.inDays == 1 ? 'Ayer' : 'Hace ${diff.inDays} días';
  }
  if (diff.inHours >= 1) return 'Hace ${diff.inHours} h';
  return 'Hace un momento';
}

class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final String toggleLabel;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _CardMenu({
    required this.onEdit,
    required this.toggleLabel,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded,
          color: RedesignColors.primario300, size: 20),
      color: RedesignColors.primario800,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        switch (v) {
          case 'edit':
            onEdit();
            break;
          case 'toggle':
            onToggle();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (_) => [
        _item('edit', 'Editar', RedesignColors.primario50),
        _item('toggle', toggleLabel, RedesignColors.primario50),
        _item('delete', 'Eliminar', RedesignColors.danger),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Text(label,
          style: RedesignType.bodySm.copyWith(color: color)),
    );
  }
}
