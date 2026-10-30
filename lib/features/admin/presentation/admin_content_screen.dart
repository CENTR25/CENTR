import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../models/affiliated_brand_model.dart';
import '../../../models/news_model.dart';
import '../../../services/admin_service.dart';
import '../../../services/affiliated_brand_service.dart';
import '../../../services/news_service.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_add_exercise_sheet.dart';
import '../widgets/admin_common.dart';
import 'admin_brand_editor_screen.dart';
import 'admin_news_editor_screen.dart';

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
    const addLabels = ['Noticia', 'Marca', 'Ejercicio'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminGradientHeader(
          title: 'Contenido',
          trailing: AdminAddPillButton(label: addLabels[_index], onTap: _add),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          child: AdminSegmentedPills(
            labels: const ['Noticias', 'Marcas', 'Ejercicios'],
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
            ],
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
                  AdminStatusPill(
                    label: article.isPublished ? 'Publicada' : 'Borrador',
                    color: article.isPublished
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
class _ExercisesList extends ConsumerWidget {
  const _ExercisesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exAsync = ref.watch(globalExercisesProvider);
    return RefreshIndicator(
      color: RedesignColors.actionPrimary,
      backgroundColor: RedesignColors.primario800,
      onRefresh: () async {
        ref.invalidate(globalExercisesProvider);
        await ref.read(globalExercisesProvider.future);
      },
      child: exAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _error('$e'),
        data: (items) {
          if (items.isEmpty) return _empty('No hay ejercicios todavía.');
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 130),
            children: [for (final e in items) _ExerciseCard(exercise: e)],
          );
        },
      ),
    );
  }
}

class _ExerciseCard extends ConsumerWidget {
  final Map<String, dynamic> exercise;
  const _ExerciseCard({required this.exercise});

  Future<void> _toggleHidden(WidgetRef ref) async {
    final hidden = exercise['is_hidden'] as bool? ?? false;
    await ref
        .read(adminServiceProvider)
        .setGlobalExerciseHidden(exercise['id'] as String, !hidden);
    ref.invalidate(globalExercisesProvider);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirmDelete(context, 'este ejercicio');
    if (ok != true) return;
    await ref
        .read(adminServiceProvider)
        .deleteGlobalExercise(exercise['id'] as String);
    ref.invalidate(globalExercisesProvider);
    if (context.mounted) {
      showRedesignToast(context,
          title: 'Ejercicio eliminado', subtitle: 'Se eliminó el ejercicio.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = exercise['is_hidden'] as bool? ?? false;
    final name = (exercise['name'] ?? 'Ejercicio').toString();
    final muscle = (exercise['muscle_group'] ?? '').toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.all(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AdminAddExerciseSheet(exercise: exercise),
        ),
        child: Row(
          children: [
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
            _CardMenu(
              onEdit: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AdminAddExerciseSheet(exercise: exercise),
              ),
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
