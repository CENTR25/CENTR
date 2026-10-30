import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../models/affiliated_brand_model.dart';
import '../../../services/affiliated_brand_service.dart';
import '../../../services/storage_service.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_common.dart';

/// Create / edit an affiliated brand (Figma Third Batch "Nueva marca").
class AdminBrandEditorScreen extends ConsumerStatefulWidget {
  final AffiliatedBrand? brand;

  const AdminBrandEditorScreen({super.key, this.brand});

  @override
  ConsumerState<AdminBrandEditorScreen> createState() =>
      _AdminBrandEditorScreenState();
}

class _AdminBrandEditorScreenState
    extends ConsumerState<AdminBrandEditorScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _discountLabelCtrl;
  late final TextEditingController _bannerCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _instagramCtrl;

  String? _category;
  String? _logoUrl;
  Uint8List? _logoPreview;
  bool _saving = false;
  bool _uploading = false;

  bool get _isEdit => widget.brand != null;

  @override
  void initState() {
    super.initState();
    final b = widget.brand;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _codeCtrl = TextEditingController(text: b?.discountCode ?? '');
    _discountLabelCtrl = TextEditingController(text: b?.discountLabel ?? '');
    _bannerCtrl = TextEditingController(text: b?.bannerText ?? '');
    _urlCtrl = TextEditingController(text: b?.websiteUrl ?? '');
    _instagramCtrl = TextEditingController(text: b?.instagramUrl ?? '');
    _category = b?.category;
    _logoUrl = b?.logoUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _discountLabelCtrl.dispose();
    _bannerCtrl.dispose();
    _urlCtrl.dispose();
    _instagramCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext =
          picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final url = await ref
          .read(storageServiceProvider)
          .uploadBrandLogoBytes(bytes, ext);
      if (!mounted) return;
      setState(() {
        _logoUrl = url;
        _logoPreview = bytes;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showRedesignToast(context,
          title: 'No se pudo subir el logo',
          subtitle: '$e',
          icon: Icons.error_outline_rounded);
    }
  }

  String? _trimOrNull(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showRedesignToast(context,
          title: 'Falta el nombre',
          subtitle: 'Ingresá el nombre de la marca.',
          icon: Icons.error_outline_rounded);
      return;
    }
    setState(() => _saving = true);
    try {
      final svc = ref.read(affiliatedBrandServiceProvider);
      if (_isEdit) {
        await svc.updateBrand(
          widget.brand!.id,
          name: _nameCtrl.text.trim(),
          discountCode: _trimOrNull(_codeCtrl),
          bannerText: _trimOrNull(_bannerCtrl),
          websiteUrl: _trimOrNull(_urlCtrl),
          instagramUrl: _trimOrNull(_instagramCtrl),
          logoUrl: _logoUrl,
          category: _category,
          discountLabel: _trimOrNull(_discountLabelCtrl),
        );
      } else {
        await svc.createBrand(
          name: _nameCtrl.text.trim(),
          discountCode: _trimOrNull(_codeCtrl),
          bannerText: _trimOrNull(_bannerCtrl),
          websiteUrl: _trimOrNull(_urlCtrl),
          instagramUrl: _trimOrNull(_instagramCtrl),
          logoUrl: _logoUrl,
          category: _category,
          discountLabel: _trimOrNull(_discountLabelCtrl),
        );
      }
      ref.invalidate(allBrandsProvider);
      ref.invalidate(activeBrandsProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: _isEdit ? 'Marca actualizada' : 'Marca creada',
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
            _isEdit ? 'Editar marca' : 'Nueva marca',
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
            _label('Marca'),
            const SizedBox(height: 8),
            _field(_nameCtrl, 'Nombre de la marca'),
            const SizedBox(height: 16),
            _logoPicker(),
            const SizedBox(height: 18),
            _label('Código de descuento'),
            const SizedBox(height: 8),
            _field(_codeCtrl, 'Ej: PRGS'),
            const SizedBox(height: 18),
            _label('Descuento (opcional)'),
            const SizedBox(height: 8),
            _field(_discountLabelCtrl, 'Ej: 15% OFF'),
            const SizedBox(height: 18),
            _label('Texto del descuento (opcional)'),
            const SizedBox(height: 8),
            _field(_bannerCtrl, 'Ej: No olvides usar el código al abonar',
                maxLines: 2),
            const SizedBox(height: 18),
            _label('Categoría (opcional)'),
            const SizedBox(height: 8),
            Row(
              children: [
                _categoryChip('Ropa', 'ropa'),
                const SizedBox(width: 8),
                _categoryChip('Nutrición', 'nutricion'),
                const SizedBox(width: 8),
                _categoryChip('Salud', 'salud'),
              ],
            ),
            const SizedBox(height: 18),
            _label('URL (opcional)'),
            const SizedBox(height: 8),
            _field(_urlCtrl, 'URL del sitio',
                keyboardType: TextInputType.url),
            const SizedBox(height: 18),
            _label('Instagram (opcional)'),
            const SizedBox(height: 8),
            _field(_instagramCtrl, 'Usuario o URL'),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: RedesignColors.onActionPrimary,
                        ),
                      )
                    : Text(_isEdit ? 'Guardar cambios' : 'Crear marca'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPicker() {
    final hasLogo =
        _logoPreview != null || (_logoUrl != null && _logoUrl!.isNotEmpty);
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: RedesignColors.primario800,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.25),
            ),
          ),
          child: _uploading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : hasLogo
                  ? (_logoPreview != null
                      ? Image.memory(_logoPreview!, fit: BoxFit.cover)
                      : Image.network(_logoUrl!, fit: BoxFit.cover))
                  : const Icon(Icons.storefront_outlined,
                      color: RedesignColors.primario300, size: 24),
        ),
        const SizedBox(width: 14),
        OutlinedButton.icon(
          onPressed: _uploading ? null : _pickLogo,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsets.symmetric(horizontal: 18),
          ),
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: const Text('Logo'),
        ),
      ],
    );
  }

  Widget _categoryChip(String label, String value) {
    return AdminFilterChip(
      label: label,
      active: _category == value,
      onTap: () => setState(
          () => _category = _category == value ? null : value),
    );
  }

  Widget _field(
    TextEditingController c,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
      decoration: InputDecoration(hintText: hint),
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
