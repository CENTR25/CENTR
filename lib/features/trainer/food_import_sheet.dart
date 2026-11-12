import 'package:flutter/material.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/food_service.dart';
import 'food_edit_sheet.dart' show foodFieldDecoration;

/// "Importar CSV" — paste CSV, preview validation + duplicates, then import.
class FoodImportSheet extends StatefulWidget {
  final FoodAccess access;
  final FoodService service;
  final Set<String> existingKeys;

  const FoodImportSheet({
    super.key,
    required this.access,
    required this.service,
    required this.existingKeys,
  });

  /// Returns true if rows were imported.
  static Future<bool> show(
    BuildContext context, {
    required FoodAccess access,
    required FoodService service,
    required Set<String> existingKeys,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodImportSheet(
          access: access, service: service, existingKeys: existingKeys),
    );
    return r == true;
  }

  @override
  State<FoodImportSheet> createState() => _FoodImportSheetState();
}

class _FoodImportSheetState extends State<FoodImportSheet> {
  final _ctrl = TextEditingController();
  FoodCsvResult? _result;
  bool _importing = false;
  String? _message;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _preview() {
    setState(() {
      _message = null;
      _result = parseFoodsCsv(_ctrl.text, existingKeys: widget.existingKeys);
    });
  }

  Future<void> _import() async {
    final rows = _result!.importable.map((r) => r.data).toList();
    if (rows.isEmpty) return;
    setState(() => _importing = true);
    try {
      final r = await widget.service.importFoods(rows, widget.access);
      if (!mounted) return;
      if (r.inserted > 0) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _importing = false;
          _message = 'No se pudo importar ninguna fila (${r.failed} fallidas).';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _importing = false;
          _message = 'Error al importar. Intentá de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    final ok = res?.importable.length ?? 0;
    return Theme(
      data: RedesignTheme.theme,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: const BoxDecoration(
            color: RedesignColors.primario900,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Importar alimentos (CSV)',
                      style: RedesignType.headingMd
                          .copyWith(color: RedesignColors.primario50)),
                  const SizedBox(height: 6),
                  Text(
                    widget.access.isAdmin
                        ? 'Se importan como alimentos globales.'
                        : 'Se importan como tus propios alimentos.',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.secundario300),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Columnas: name, category, state, calories, protein, carbs, '
                    'fat, fiber, serving_size, serving_unit, source, verified. '
                    'Separador coma o punto y coma; decimales con coma o punto. '
                    'Máx. $kMaxImportRows filas.',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario400),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _ctrl,
                    minLines: 5,
                    maxLines: 8,
                    maxLength: kMaxImportChars,
                    style: const TextStyle(
                        color: RedesignColors.primario50, fontSize: 12),
                    decoration: foodFieldDecoration('Pegá el CSV acá')
                        .copyWith(counterText: ''),
                    onChanged: (_) {
                      if (_result != null) setState(() => _result = null);
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _importing ? null : _preview,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RedesignColors.primario700,
                        foregroundColor: RedesignColors.primario50,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: const Text('Previsualizar'),
                    ),
                  ),
                  if (res != null) ...[
                    const SizedBox(height: 12),
                    for (final e in res.fileErrors)
                      Text(e,
                          style: const TextStyle(
                              color: RedesignColors.peligro400)),
                    if (res.rows.isNotEmpty)
                      Text(
                        '$ok para importar · ${res.duplicateCount} duplicadas '
                        '(se omiten) · ${res.invalidCount} con errores',
                        style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w600),
                      ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final r in res.rows.take(300)) _PreviewRow(r),
                        ],
                      ),
                    ),
                  ],
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_message!,
                          style: const TextStyle(
                              color: RedesignColors.peligro400)),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed:
                            _importing ? null : () => Navigator.pop(context, false),
                        style: TextButton.styleFrom(
                            foregroundColor: RedesignColors.primario300,
                            minimumSize: const Size(0, 44)),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: (_importing || ok == 0) ? null : _import,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RedesignColors.actionPrimary,
                          foregroundColor: RedesignColors.onActionPrimary,
                          minimumSize: const Size(0, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                        ),
                        child: _importing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Text('Importar ($ok)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final FoodCsvRow row;
  const _PreviewRow(this.row);

  @override
  Widget build(BuildContext context) {
    final bad = !row.isValid;
    final color = bad
        ? RedesignColors.peligro400
        : row.duplicate
            ? RedesignColors.warning
            : RedesignColors.exito500;
    final state = row.data['state'];
    final label =
        '${row.data['name']}${state != null ? ' ($state)' : ''}';
    final detail = bad
        ? row.errors.join(', ')
        : row.duplicate
            ? 'Duplicada, se omite'
            : '${row.data['calories']} kcal · P ${row.data['protein']} · '
                'C ${row.data['carbs']} · G ${row.data['fat']}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              bad
                  ? Icons.error_outline_rounded
                  : row.duplicate
                      ? Icons.copy_rounded
                      : Icons.check_circle_outline_rounded,
              size: 16,
              color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text('L${row.line} · $label — $detail',
                style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
