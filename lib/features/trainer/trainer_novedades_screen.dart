import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/theme_redesign.dart';
import '../../models/news_model.dart';
import '../../services/news_service.dart';
import '../../services/storage_service.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

/// The signed-in trainer's own Novedades — news articles scoped to their
/// athletes (trainer_id = their trainers.id, audience 'students').
final trainerNewsProvider = FutureProvider<List<NewsArticle>>((ref) async {
  final trainerId = await ref.watch(myTrainerIdProvider.future);
  if (trainerId == null) return [];
  return ref.read(newsServiceProvider).getTrainerNews(trainerId);
});

/// Lets a trainer publish Novedades to their own athletes. Lists existing
/// articles (published + drafts) and opens an editor to create/edit/delete.
class TrainerNovedadesScreen extends ConsumerWidget {
  const TrainerNovedadesScreen({super.key});

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    NewsArticle? article,
  }) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TrainerNewsEditorScreen(article: article),
      ),
    );
    ref.invalidate(trainerNewsProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    NewsArticle article,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          title: Text(
            'Eliminar novedad',
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '¿Seguro que querés eliminar "${article.title}"? Esta acción no se puede deshacer.',
            style: RedesignType.label.copyWith(color: RedesignColors.primario200),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar',
                  style: TextStyle(color: RedesignColors.danger)),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final ok = await ref.read(newsServiceProvider).deleteNews(article.id);
    ref.invalidate(trainerNewsProvider);
    if (!context.mounted) return;
    showRedesignToast(
      context,
      title: ok ? 'Novedad eliminada' : 'No se pudo eliminar',
      icon: ok ? Icons.check_circle_outline : Icons.error_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(trainerNewsProvider);

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
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Novedades',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context, ref),
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nueva novedad'),
        ),
        body: newsAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
                color: RedesignColors.actionPrimary),
          ),
          error: (e, _) => Center(
            child: Text('Error: $e',
                style: RedesignType.label
                    .copyWith(color: RedesignColors.primario300)),
          ),
          data: (articles) {
            if (articles.isEmpty) {
              return _EmptyState(onCreate: () => _openEditor(context, ref));
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: articles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _NewsRow(
                article: articles[i],
                onTap: () => _openEditor(context, ref, article: articles[i]),
                onDelete: () => _confirmDelete(context, ref, articles[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_outlined,
                color: RedesignColors.primario400, size: 48),
            const SizedBox(height: 16),
            Text(
              'Todavía no publicaste novedades',
              textAlign: TextAlign.center,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compartí avisos, cambios o anuncios con tus alumnos. '
              'Aparecerán en su pantalla de inicio.',
              textAlign: TextAlign.center,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsRow extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NewsRow({
    required this.article,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RedesignRadius.card),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  article.imageUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(
                      width: 48, height: 48),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusChip(published: article.isPublished),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          article.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RedesignType.label
                              .copyWith(color: RedesignColors.primario300),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: RedesignColors.primario400, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool published;
  const _StatusChip({required this.published});

  @override
  Widget build(BuildContext context) {
    final color =
        published ? RedesignColors.secundario300 : RedesignColors.primario400;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        published ? 'Publicada' : 'Borrador',
        style: RedesignType.label.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Editor
// ---------------------------------------------------------------------------

class _TrainerNewsEditorScreen extends ConsumerStatefulWidget {
  final NewsArticle? article;
  const _TrainerNewsEditorScreen({this.article});

  @override
  ConsumerState<_TrainerNewsEditorScreen> createState() =>
      _TrainerNewsEditorScreenState();
}

class _TrainerNewsEditorScreenState
    extends ConsumerState<_TrainerNewsEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String? _coverUrl;
  Uint8List? _coverPreview;
  bool _saving = false;
  bool _uploading = false;

  bool get _isEdit => widget.article != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.article?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.article?.content ?? '');
    _coverUrl = widget.article?.imageUrl;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext =
          picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final url = await ref
          .read(storageServiceProvider)
          .uploadNewsCoverBytes(bytes, ext);
      if (!mounted) return;
      setState(() {
        _coverUrl = url;
        _coverPreview = bytes;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showRedesignToast(context,
          title: 'No se pudo subir la imagen',
          subtitle: '$e',
          icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _save({required bool publish}) async {
    if (_titleCtrl.text.trim().isEmpty || _contentCtrl.text.trim().isEmpty) {
      showRedesignToast(context,
          title: 'Faltan datos',
          subtitle: 'Completá título y contenido.',
          icon: Icons.error_outline_rounded);
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = ref.read(newsServiceProvider);
      if (_isEdit) {
        await svc.updateNews(
          widget.article!.id,
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          imageUrl: _coverUrl,
          isPublished: publish,
        );
      } else {
        final trainerId = await ref.read(myTrainerIdProvider.future);
        if (trainerId == null) {
          throw Exception('No se encontró tu perfil de entrenador.');
        }
        await svc.createNews(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          imageUrl: _coverUrl,
          isPublished: publish,
          trainerId: trainerId,
          audience: 'students',
        );
      }
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: publish ? 'Novedad publicada' : 'Guardada como borrador',
        subtitle: 'Tus alumnos la verán en su inicio.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showRedesignToast(context,
          title: 'No se pudo guardar',
          subtitle: '$e',
          icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded,
                color: RedesignColors.primario50),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            _isEdit ? 'Editar novedad' : 'Nueva novedad',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _coverPicker(),
            const SizedBox(height: 20),
            _label('Título'),
            const SizedBox(height: 8),
            TextField(
              controller: _titleCtrl,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario50),
              decoration: const InputDecoration(hintText: 'Título de la novedad'),
            ),
            const SizedBox(height: 18),
            _label('Contenido'),
            const SizedBox(height: 8),
            TextField(
              controller: _contentCtrl,
              maxLines: 6,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario50),
              decoration: const InputDecoration(
                hintText: 'Escribí la novedad para tus alumnos',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => _save(publish: false),
                    child: const Text('Borrador'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : () => _save(publish: true),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RedesignColors.onActionPrimary,
                            ),
                          )
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: RedesignType.label.copyWith(color: RedesignColors.primario300),
      );

  Widget _coverPicker() {
    final hasImage =
        _coverPreview != null || (_coverUrl != null && _coverUrl!.isNotEmpty);
    return GestureDetector(
      onTap: _uploading ? null : _pickCover,
      child: Container(
        height: 160,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: RedesignColors.primario800,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: _uploading
            ? const Center(child: CircularProgressIndicator())
            : hasImage
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_coverPreview != null)
                        Image.memory(_coverPreview!, fit: BoxFit.cover)
                      else
                        Image.network(_coverUrl!, fit: BoxFit.cover),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: RedesignColors.actionPrimary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit_rounded,
                              color: RedesignColors.onActionPrimary, size: 18),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: RedesignColors.primario300, size: 32),
                      const SizedBox(height: 8),
                      Text('Agregar imagen (opcional)',
                          style: RedesignType.label
                              .copyWith(color: RedesignColors.primario300)),
                    ],
                  ),
      ),
    );
  }
}
