import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../models/news_model.dart';
import '../../../services/news_service.dart';
import '../../../services/storage_service.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_common.dart';

/// Create / edit a news article (Figma Third Batch "Nueva noticia").
/// Cover image, título, contenido, "Visible para" audience, draft/publish.
class AdminNewsEditorScreen extends ConsumerStatefulWidget {
  final NewsArticle? article;

  const AdminNewsEditorScreen({super.key, this.article});

  @override
  ConsumerState<AdminNewsEditorScreen> createState() =>
      _AdminNewsEditorScreenState();
}

class _AdminNewsEditorScreenState
    extends ConsumerState<AdminNewsEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;
  String _audience = 'all';
  String? _coverUrl;
  Uint8List? _coverPreview;
  bool _saving = false;
  bool _uploading = false;

  bool get _isEdit => widget.article != null;

  @override
  void initState() {
    super.initState();
    final a = widget.article;
    _titleCtrl = TextEditingController(text: a?.title ?? '');
    _contentCtrl = TextEditingController(text: a?.content ?? '');
    _audience = a?.audience ?? 'all';
    _coverUrl = a?.imageUrl;
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
      final url =
          await ref.read(storageServiceProvider).uploadNewsCoverBytes(bytes, ext);
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
          audience: _audience,
        );
      } else {
        await svc.createNews(
          title: _titleCtrl.text.trim(),
          content: _contentCtrl.text.trim(),
          imageUrl: _coverUrl,
          isPublished: publish,
          audience: _audience,
        );
      }
      ref.invalidate(allNewsProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: publish ? 'Noticia publicada' : 'Guardada como borrador',
        subtitle: 'Los cambios se guardaron.',
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
            _isEdit ? 'Editar noticia' : 'Nueva noticia',
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
              decoration: const InputDecoration(hintText: 'Título de la noticia'),
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
                hintText: 'Escribí la noticia',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            _label('Visible para'),
            const SizedBox(height: 8),
            Row(
              children: [
                _audienceChip('Todos', 'all'),
                const SizedBox(width: 8),
                _audienceChip('Entrenadores', 'trainers'),
                const SizedBox(width: 8),
                _audienceChip('Alumnos', 'students'),
              ],
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

  Widget _coverPicker() {
    final hasImage = _coverPreview != null ||
        (_coverUrl != null && _coverUrl!.isNotEmpty);
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
                              color: RedesignColors.onActionPrimary, size: 16),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.image_outlined,
                          color: RedesignColors.primario300, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Agregar imagen de portada',
                        style: RedesignType.label
                            .copyWith(color: RedesignColors.primario300),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _audienceChip(String label, String value) {
    return AdminFilterChip(
      label: label,
      active: _audience == value,
      onTap: () => setState(() => _audience = value),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: RedesignType.bodySm.copyWith(
          color: RedesignColors.primario50,
          fontWeight: FontWeight.w600,
        ),
      );
}
