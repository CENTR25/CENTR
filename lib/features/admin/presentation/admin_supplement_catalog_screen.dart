import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/supplement_catalog_service.dart';
import '../../shared/redesign_toast.dart';

const _units = ['g', 'mg', 'ml', 'caps'];

/// Supplement catalog management ("Suplementos"): list, add, edit,
/// activate/deactivate, delete and bulk paste import.
/// [asAdmin] true  => manages global entries (all visible).
/// [asAdmin] false => trainer: own entries editable, global ones read-only.
class AdminSupplementCatalogScreen extends ConsumerWidget {
  final bool asAdmin;
  const AdminSupplementCatalogScreen({super.key, this.asAdmin = true});

  bool _canEdit(SupplementCatalogItem i) => asAdmin ? i.isGlobal : !i.isGlobal;

  void _refresh(WidgetRef ref) {
    ref.invalidate(allSupplementCatalogProvider);
    ref.invalidate(activeSupplementCatalogProvider);
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref,
      [SupplementCatalogItem? item]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: RedesignTheme.theme,
        child: _CatalogEditSheet(item: item, asAdmin: asAdmin),
      ),
    );
    if (ok == true) _refresh(ref);
  }

  Future<void> _openImport(BuildContext context, WidgetRef ref) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: RedesignTheme.theme,
        child: _CatalogImportSheet(asAdmin: asAdmin),
      ),
    );
    if (ok == true) _refresh(ref);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, SupplementCatalogItem i) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          title: const Text('Eliminar suplemento',
              style: TextStyle(color: RedesignColors.primario50)),
          content: Text('¿Eliminar "${i.name}" de la lista?',
              style: const TextStyle(color: RedesignColors.primario300)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(
                  foregroundColor: RedesignColors.primario300),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: RedesignColors.danger),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(supplementCatalogServiceProvider).delete(i.id);
      _refresh(ref);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allSupplementCatalogProvider);
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: RedesignColors.primario50),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            asAdmin ? 'Suplementos' : 'Mi lista de suplementos',
            style: const TextStyle(
              color: RedesignColors.primario50,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Importar lista',
              icon: const Icon(Icons.playlist_add_rounded,
                  color: RedesignColors.actionPrimary),
              onPressed: () => _openImport(context, ref),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          onPressed: () => _openEdit(context, ref),
          child: const Icon(Icons.add_rounded),
        ),
        body: async.when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: RedesignColors.actionPrimary)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: RedesignColors.danger))),
          data: (items) {
            if (items.isEmpty) {
              return const Center(
                child: Text('No hay suplementos en la lista todavía.',
                    style: TextStyle(color: RedesignColors.primario400)),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                for (final i in items) ...[
                  _row(context, ref, i),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, SupplementCatalogItem i) {
    final editable = _canEdit(i);
    final dose = [i.defaultDose, i.defaultUnit]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');
    final meta = [
      i.category == 'quimica' ? 'Química' : 'Natural',
      if (dose.isNotEmpty) dose,
      if (!asAdmin && i.isGlobal) 'General',
      if (!i.isActive) 'Inactivo',
    ].join(' · ');
    return Opacity(
      opacity: i.isActive ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(RedesignRadius.buttonLg),
        onTap: editable ? () => _openEdit(context, ref, i) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: RedesignColors.primario700,
            borderRadius: BorderRadius.circular(RedesignRadius.buttonLg),
            border: Border.all(
                color: RedesignColors.secundario300.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name,
                        style: const TextStyle(
                          color: RedesignColors.primario50,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Metropolis',
                        )),
                    const SizedBox(height: 2),
                    Text(meta,
                        style: const TextStyle(
                          color: RedesignColors.primario400,
                          fontSize: 12,
                          fontFamily: 'Metropolis',
                        )),
                  ],
                ),
              ),
              if (editable) ...[
                IconButton(
                  tooltip: i.isActive ? 'Desactivar' : 'Activar',
                  icon: Icon(
                      i.isActive
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: RedesignColors.primario300,
                      size: 20),
                  onPressed: () async {
                    await ref
                        .read(supplementCatalogServiceProvider)
                        .setActive(i.id, !i.isActive);
                    _refresh(ref);
                  },
                ),
                IconButton(
                  tooltip: 'Eliminar',
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: RedesignColors.danger, size: 20),
                  onPressed: () => _delete(context, ref, i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sheet chrome
// ---------------------------------------------------------------------------

Widget _sheetShell(BuildContext context, {required List<Widget> children}) {
  return Container(
    constraints:
        BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [RedesignColors.primario900, RedesignColors.secundario900],
      ),
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ),
  );
}

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t,
          style: const TextStyle(
            color: RedesignColors.primario300,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Metropolis',
          )),
    );

const _fieldStyle = TextStyle(
    color: RedesignColors.primario50, fontFamily: 'Metropolis', fontSize: 15);

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
          color: RedesignColors.primario400, fontFamily: 'Metropolis'),
    );

Widget _pill(String label, bool selected, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected
            ? RedesignColors.secundario300
            : RedesignColors.secundario300.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
        border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1 : 0.35),
            width: 0.5),
      ),
      child: Text(label,
          style: TextStyle(
            color: selected
                ? RedesignColors.secundario900
                : RedesignColors.secundario300,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Metropolis',
          )),
    ),
  );
}

Widget _primaryButton(String text, bool loading, VoidCallback? onPressed) {
  return SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: RedesignColors.actionPrimary,
        foregroundColor: RedesignColors.onActionPrimary,
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: RedesignRadius.buttonLgBr),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: RedesignColors.onActionPrimary))
          : Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Metropolis')),
    ),
  );
}

// ---------------------------------------------------------------------------
// Add / edit
// ---------------------------------------------------------------------------

class _CatalogEditSheet extends ConsumerStatefulWidget {
  final SupplementCatalogItem? item;
  final bool asAdmin;
  const _CatalogEditSheet({this.item, required this.asAdmin});

  @override
  ConsumerState<_CatalogEditSheet> createState() => _CatalogEditSheetState();
}

class _CatalogEditSheetState extends ConsumerState<_CatalogEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _note;
  late String _category;
  String? _unit;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _name = TextEditingController(text: i?.name ?? '');
    _dose = TextEditingController(text: i?.defaultDose ?? '');
    _note = TextEditingController(text: i?.note ?? '');
    _category = i?.category ?? 'natural';
    _unit = i?.defaultUnit;
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingresá un nombre'),
          backgroundColor: RedesignColors.danger));
      return;
    }
    final nav = Navigator.of(context);
    final overlay = Overlay.maybeOf(context);
    setState(() => _loading = true);
    try {
      await ref.read(supplementCatalogServiceProvider).save(
            id: widget.item?.id,
            name: _name.text,
            category: _category,
            dose: _dose.text,
            unit: _unit,
            timing: widget.item?.defaultTiming ?? const [],
            note: _note.text,
            isActive: widget.item?.isActive ?? true,
            asAdmin: widget.asAdmin,
          );
      nav.pop(true);
      if (overlay != null) {
        // ignore: use_build_context_synchronously
        showRedesignToast(overlay.context,
            title: '¡Guardado exitosamente!', subtitle: 'Lista actualizada');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(context, children: [
      Text(widget.item == null ? 'Nuevo suplemento' : 'Editar suplemento',
          style: const TextStyle(
            color: RedesignColors.primario50,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Metropolis',
          )),
      const SizedBox(height: 20),
      _label('Nombre'),
      TextField(controller: _name, style: _fieldStyle, decoration: _dec('Ej: Creatina')),
      const SizedBox(height: 18),
      _label('Tipo'),
      Wrap(spacing: 8, children: [
        _pill('Natural', _category == 'natural',
            () => setState(() => _category = 'natural')),
        _pill('Química', _category == 'quimica',
            () => setState(() => _category = 'quimica')),
      ]),
      const SizedBox(height: 18),
      _label('Dosis sugerida (opcional)'),
      Row(children: [
        SizedBox(
          width: 90,
          child: TextField(
              controller: _dose,
              keyboardType: TextInputType.number,
              style: _fieldStyle,
              decoration: _dec('5')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final u in _units)
              _pill(u, _unit == u, () => setState(() => _unit = _unit == u ? null : u)),
          ]),
        ),
      ]),
      const SizedBox(height: 18),
      _label('Nota (opcional)'),
      TextField(
          controller: _note,
          maxLines: 2,
          style: _fieldStyle,
          decoration: _dec('Ej: Tomar con agua')),
      const SizedBox(height: 24),
      _primaryButton('Guardar', _loading, _save),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Bulk import
// ---------------------------------------------------------------------------

class _CatalogImportSheet extends ConsumerStatefulWidget {
  final bool asAdmin;
  const _CatalogImportSheet({required this.asAdmin});

  @override
  ConsumerState<_CatalogImportSheet> createState() =>
      _CatalogImportSheetState();
}

class _CatalogImportSheetState extends ConsumerState<_CatalogImportSheet> {
  final _ctrl = TextEditingController();
  String _category = 'natural';
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final lines = parseSupplementLines(_ctrl.text);
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pegá al menos un suplemento'),
          backgroundColor: RedesignColors.danger));
      return;
    }
    final nav = Navigator.of(context);
    final overlay = Overlay.maybeOf(context);
    setState(() => _loading = true);
    try {
      final n = await ref.read(supplementCatalogServiceProvider).bulkImport(
            lines,
            category: _category,
            asAdmin: widget.asAdmin,
          );
      nav.pop(true);
      if (overlay != null) {
        // ignore: use_build_context_synchronously
        showRedesignToast(overlay.context,
            title: '¡Importado!',
            subtitle: n == 0
                ? 'Todos ya estaban en la lista'
                : '$n suplementos agregados');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: RedesignColors.danger));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(context, children: [
      const Text('Importar lista',
          style: TextStyle(
            color: RedesignColors.primario50,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFamily: 'Metropolis',
          )),
      const SizedBox(height: 8),
      const Text(
        'Pegá un suplemento por línea. Formato opcional: nombre;dosis;unidad\n'
        'Ej: Creatina;5;g',
        style: TextStyle(
            color: RedesignColors.primario400,
            fontSize: 12,
            fontFamily: 'Metropolis'),
      ),
      const SizedBox(height: 16),
      _label('Tipo'),
      Wrap(spacing: 8, children: [
        _pill('Natural', _category == 'natural',
            () => setState(() => _category = 'natural')),
        _pill('Química', _category == 'quimica',
            () => setState(() => _category = 'quimica')),
      ]),
      const SizedBox(height: 18),
      TextField(
        controller: _ctrl,
        maxLines: 8,
        minLines: 6,
        style: _fieldStyle,
        decoration: _dec('Creatina;5;g\nOmega 3;1;g\nMagnesio'),
      ),
      const SizedBox(height: 24),
      _primaryButton('Importar', _loading, _import),
    ]);
  }
}

/// Tile for the admin home "Configuración" section.
class AdminSupplementsEntry extends StatelessWidget {
  const AdminSupplementsEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RedesignColors.primario700,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const AdminSupplementCatalogScreen(asAdmin: true)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: RedesignColors.actionPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication_outlined,
                  color: RedesignColors.actionPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Suplementos',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  SizedBox(height: 2),
                  Text('Lista de agregado rápido',
                      style: TextStyle(
                          color: RedesignColors.primario400, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario400),
          ]),
        ),
      ),
    );
  }
}
