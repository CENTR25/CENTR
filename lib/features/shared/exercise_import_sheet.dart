import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/exercise_import.dart';
import '../../services/storage_service.dart';
import '../trainer/food_edit_sheet.dart'
    show confirmDestructive, foodFieldDecoration;

/// Max image files per batch / bytes per image for the image bank.
const kMaxBankImages = 300;
const kMaxBankImageBytes = 10 * 1024 * 1024;

// ---------------------------------------------------------------------------
// Delete-or-hide (bulk + single) — shared by admin catalog + trainer library
// ---------------------------------------------------------------------------

/// Confirms, runs the delete-or-hide RPC and shows the result dialog.
/// Returns the result, or null when cancelled / failed.
Future<DeleteOrHideResult?> confirmDeleteOrHideExercises(
  BuildContext context, {
  required List<String> ids,
  required Future<DeleteOrHideResult> Function(List<String> ids) run,
}) async {
  final n = ids.length;
  if (n == 0) return null;
  final ok = await confirmDestructive(
    context,
    n == 1 ? 'Eliminar ejercicio' : 'Eliminar $n ejercicios',
    message: 'Los ejercicios que estén en uso en alguna rutina no se borran: '
        'se ocultan para que las rutinas sigan funcionando. '
        'El resto se elimina y no se puede deshacer.',
  );
  if (!ok || !context.mounted) return null;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    final r = await run(ids);
    if (context.mounted) await showDeleteOrHideResult(context, r);
    return r;
  } catch (_) {
    messenger?.showSnackBar(const SnackBar(
      content: Text('No se pudieron eliminar los ejercicios.'),
      backgroundColor: RedesignColors.danger,
    ));
    return null;
  }
}

Future<void> showDeleteOrHideResult(
    BuildContext context, DeleteOrHideResult r) {
  final parts = <String>[
    '${r.deleted} eliminado${r.deleted == 1 ? '' : 's'}',
    '${r.hidden} ocultado${r.hidden == 1 ? '' : 's'} (en uso en rutinas)',
    if (r.skipped > 0) '${r.skipped} sin permiso',
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: RedesignColors.primario900,
      title: const Text('Listo',
          style: TextStyle(color: RedesignColors.primario50)),
      content: Text(parts.join(' · '),
          style: const TextStyle(color: RedesignColors.primario200)),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: RedesignColors.actionPrimary),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Picked image upload (shared by CSV import + image bank)
// ---------------------------------------------------------------------------

class _PickedImage {
  final String name;
  final Uint8List bytes;
  const _PickedImage(this.name, this.bytes);
}

/// Opens the file picker for many images (web-safe: bytes, not paths).
/// Returns (accepted images, rejected file names).
Future<({List<_PickedImage> images, List<String> rejected})?>
    _pickImageFiles() async {
  final res = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: kImageExtensions.toList(),
    allowMultiple: true,
    withData: true,
  );
  if (res == null) return null;
  final images = <_PickedImage>[];
  final rejected = <String>[];
  for (final f in res.files) {
    final bytes = f.bytes;
    if (bytes == null ||
        bytes.length > kMaxBankImageBytes ||
        !kImageExtensions.contains(fileExtension(f.name)) ||
        images.length >= kMaxBankImages) {
      rejected.add(f.name);
      continue;
    }
    images.add(_PickedImage(f.name, bytes));
  }
  return (images: images, rejected: rejected);
}

/// Uploads each matched image to the exercise-media bucket and replaces that
/// exercise's image_urls with it. Returns (ok, failed).
Future<({int ok, int failed})> _uploadMatched(
  SupabaseClient client,
  List<_PickedImage> images,
  Map<String, String?> matches,
  void Function(int done, int total) onProgress,
) async {
  final storage = StorageService(client);
  final todo = images.where((i) => matches[i.name] != null).toList();
  var ok = 0, failed = 0;
  for (var i = 0; i < todo.length; i++) {
    final img = todo[i];
    final id = matches[img.name]!;
    try {
      final url = await storage.uploadExerciseImageBytes(
          img.bytes, fileExtension(img.name), id, 0);
      if (await setExerciseImageUrls(client, id, [url])) {
        ok++;
      } else {
        failed++;
      }
    } catch (_) {
      failed++;
    }
    onProgress(i + 1, todo.length);
  }
  return (ok: ok, failed: failed);
}

// ---------------------------------------------------------------------------
// Shared sheet chrome
// ---------------------------------------------------------------------------

Widget _sheet(BuildContext context, List<Widget> children) {
  return Theme(
    data: RedesignTheme.theme,
    child: Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

ButtonStyle _secondaryStyle() => ElevatedButton.styleFrom(
      backgroundColor: RedesignColors.primario700,
      foregroundColor: RedesignColors.primario50,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 18),
    );

ButtonStyle _primaryStyle() => ElevatedButton.styleFrom(
      backgroundColor: RedesignColors.actionPrimary,
      foregroundColor: RedesignColors.onActionPrimary,
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 24),
    );

Widget _footer(BuildContext context,
    {required bool busy,
    required String label,
    required VoidCallback? onPressed}) {
  return Row(
    children: [
      const Spacer(),
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context, false),
        style: TextButton.styleFrom(
            foregroundColor: RedesignColors.primario300,
            minimumSize: const Size(0, 44)),
        child: const Text('Cancelar'),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: _primaryStyle(),
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Text(label),
      ),
    ],
  );
}

Widget _statusLine(IconData icon, Color color, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 12))),
        ],
      ),
    );

// ---------------------------------------------------------------------------
// CSV import
// ---------------------------------------------------------------------------

/// "Importar CSV" for exercises — paste or pick a .csv, preview validation +
/// duplicates, optionally attach photos (matched by `imagen_archivo` or name),
/// then insert. [ownerTrainerId] null = admin global catalog.
class ExerciseImportSheet extends StatefulWidget {
  final SupabaseClient client;
  final String? ownerTrainerId;

  /// [exerciseNameKey]s of VISIBLE exercises in the target scope.
  final Set<String> existingNameKeys;

  const ExerciseImportSheet({
    super.key,
    required this.client,
    required this.ownerTrainerId,
    required this.existingNameKeys,
  });

  /// Returns true if rows were imported.
  static Future<bool> show(
    BuildContext context, {
    required SupabaseClient client,
    required String? ownerTrainerId,
    required Set<String> existingNameKeys,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseImportSheet(
        client: client,
        ownerTrainerId: ownerTrainerId,
        existingNameKeys: existingNameKeys,
      ),
    );
    return r == true;
  }

  @override
  State<ExerciseImportSheet> createState() => _ExerciseImportSheetState();
}

class _ExerciseImportSheetState extends State<ExerciseImportSheet> {
  final _ctrl = TextEditingController();
  ExerciseCsvResult? _result;
  List<_PickedImage> _images = const [];
  bool _busy = false;
  String? _message;
  String? _progress;
  bool _showFormat = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _preview() {
    setState(() {
      _message = null;
      _result = parseExercisesCsv(_ctrl.text,
          existingNameKeys: widget.existingNameKeys);
    });
  }

  Future<void> _pickCsv() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'tsv'],
      withData: true,
    );
    final bytes = res?.files.single.bytes;
    if (bytes == null) return;
    if (bytes.length > kMaxExerciseImportChars * 2) {
      setState(() => _message = 'El archivo es demasiado grande.');
      return;
    }
    _ctrl.text = utf8.decode(bytes, allowMalformed: true);
    _preview();
  }

  Future<void> _pickImages() async {
    final r = await _pickImageFiles();
    if (r == null || !mounted) return;
    setState(() {
      _images = r.images;
      _message = r.rejected.isEmpty
          ? null
          : '${r.rejected.length} archivo(s) ignorados (formato o tamaño > 10 MB).';
    });
  }

  /// CSV `imagen_archivo` key -> exercise name key, for importable rows.
  Map<String, String> get _fileKeyToName => {
        for (final r in _result?.importable ?? const <ExerciseCsvRow>[])
          if (r.imageFileKey != null)
            r.imageFileKey!: exerciseNameKey(r.data['name'] as String?),
      };

  int get _imagesMatched {
    final rows = _result?.importable ?? const <ExerciseCsvRow>[];
    final fake = [
      for (final r in rows) {'id': r.data['name'], 'name': r.data['name']},
    ];
    return matchImagesToExercises(_images.map((i) => i.name), fake,
            fileKeyToName: _fileKeyToName)
        .values
        .where((v) => v != null)
        .length;
  }

  Future<void> _import() async {
    final rows = _result!.importable
        .map((r) =>
            exerciseInsertPayload(r.data, ownerTrainerId: widget.ownerTrainerId))
        .toList();
    if (rows.isEmpty) return;
    setState(() {
      _busy = true;
      _progress = 'Importando ${rows.length} ejercicios…';
    });
    try {
      final ins = await insertExercisesChunked(widget.client, rows);
      var photoNote = '';
      if (_images.isNotEmpty && ins.inserted.isNotEmpty) {
        final matches = matchImagesToExercises(
            _images.map((i) => i.name), ins.inserted,
            fileKeyToName: _fileKeyToName);
        final up = await _uploadMatched(widget.client, _images, matches,
            (d, t) {
          if (mounted) setState(() => _progress = 'Subiendo fotos $d/$t…');
        });
        photoNote = ' · ${up.ok} fotos subidas'
            '${up.failed > 0 ? ' (${up.failed} fallidas)' : ''}';
      }
      if (!mounted) return;
      if (ins.inserted.isEmpty) {
        setState(() {
          _busy = false;
          _progress = null;
          _message =
              'No se pudo importar ninguna fila (${ins.failed} fallidas).';
        });
        return;
      }
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text('${ins.inserted.length} ejercicios importados'
            '${ins.failed > 0 ? ' · ${ins.failed} fallidos' : ''}$photoNote'),
        backgroundColor: RedesignColors.success,
      ));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
          _message = 'Error al importar. Intentá de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    final ok = res?.importable.length ?? 0;
    return _sheet(context, [
      Text('Importar ejercicios (CSV)',
          style:
              RedesignType.headingMd.copyWith(color: RedesignColors.primario50)),
      const SizedBox(height: 6),
      Text(
        widget.ownerTrainerId == null
            ? 'Se importan como ejercicios globales (visibles para todos).'
            : 'Se importan como tus propios ejercicios.',
        style: RedesignType.label.copyWith(color: RedesignColors.secundario300),
      ),
      const SizedBox(height: 4),
      Text(
        'Separador ; , o tabulación. Listas (secundarios, equipamiento, '
        'imágenes) separadas con |. Máx. $kMaxExerciseImportRows filas.',
        style: RedesignType.label.copyWith(color: RedesignColors.primario400),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _showFormat = !_showFormat),
            style: TextButton.styleFrom(
                foregroundColor: RedesignColors.actionPrimary),
            icon: Icon(
                _showFormat
                    ? Icons.expand_less_rounded
                    : Icons.info_outline_rounded,
                size: 18),
            label: const Text('Ver formato'),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                  const ClipboardData(text: kExerciseCsvTemplate));
              if (mounted) {
                setState(() {
                  _message = null;
                  _progress = 'Plantilla copiada: pegala en una planilla, '
                      'completala y exportala como CSV.';
                });
              }
            },
            style: TextButton.styleFrom(
                foregroundColor: RedesignColors.actionPrimary),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar plantilla'),
          ),
        ],
      ),
      if (_showFormat)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RedesignColors.primario800,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SelectableText(
            '$kExerciseCsvHeader\n\n'
            '• nombre y grupo_muscular son obligatorios.\n'
            '• imagen: link(s) http(s) a la foto.\n'
            '• imagen_archivo: nombre del archivo de foto que adjuntes abajo '
            '(si no, se busca una foto con el mismo nombre del ejercicio).',
            style: const TextStyle(
                color: RedesignColors.primario200, fontSize: 12),
          ),
        ),
      const SizedBox(height: 4),
      TextField(
        controller: _ctrl,
        minLines: 5,
        maxLines: 8,
        maxLength: kMaxExerciseImportChars,
        style: const TextStyle(color: RedesignColors.primario50, fontSize: 12),
        decoration:
            foodFieldDecoration('Pegá el CSV acá').copyWith(counterText: ''),
        onChanged: (_) {
          if (_result != null) setState(() => _result = null);
        },
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: _busy ? null : _pickCsv,
            style: _secondaryStyle(),
            icon: const Icon(Icons.upload_file_rounded, size: 18),
            label: const Text('Elegir archivo .csv'),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _preview,
            style: _secondaryStyle(),
            child: const Text('Previsualizar'),
          ),
        ],
      ),
      if (res != null) ...[
        const SizedBox(height: 12),
        for (final e in res.fileErrors)
          Text(e, style: const TextStyle(color: RedesignColors.peligro400)),
        if (res.rows.isNotEmpty)
          Text(
            '$ok para importar · ${res.duplicateCount} duplicados '
            '(se omiten) · ${res.invalidCount} con errores',
            style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView(
            shrinkWrap: true,
            children: [for (final r in res.rows.take(300)) _rowLine(r)],
          ),
        ),
        if (ok > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _images.isEmpty
                      ? 'Fotos (opcional): adjuntá los archivos y se asignan '
                          'por imagen_archivo o por nombre.'
                      : '${_images.length} fotos · $_imagesMatched con '
                          'coincidencia',
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario300),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _pickImages,
                style: _secondaryStyle(),
                icon: const Icon(Icons.photo_library_rounded, size: 18),
                label: const Text('Adjuntar fotos'),
              ),
            ],
          ),
        ],
      ],
      if (_progress != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_progress!,
              style: const TextStyle(color: RedesignColors.primario200)),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_message!,
              style: const TextStyle(color: RedesignColors.peligro400)),
        ),
      const SizedBox(height: 12),
      _footer(context,
          busy: _busy,
          label: 'Importar ($ok)',
          onPressed: ok == 0 ? null : _import),
    ]);
  }

  Widget _rowLine(ExerciseCsvRow r) {
    final bad = !r.isValid;
    final color = bad
        ? RedesignColors.peligro400
        : r.duplicate
            ? RedesignColors.warning
            : RedesignColors.exito500;
    final detail = bad
        ? r.errors.join(', ')
        : r.duplicate
            ? 'Ya existe, se omite'
            : '${r.data['muscle_group']}'
                '${(r.data['image_urls'] as List).isNotEmpty ? ' · con foto' : ''}';
    return _statusLine(
      bad
          ? Icons.error_outline_rounded
          : r.duplicate
              ? Icons.copy_rounded
              : Icons.check_circle_outline_rounded,
      color,
      'L${r.line} · ${r.data['name']} — $detail',
    );
  }
}

// ---------------------------------------------------------------------------
// Image bank
// ---------------------------------------------------------------------------

/// "Banco de imágenes" — pick many photos at once; each file is matched to an
/// exercise whose normalized name equals the file name (sin extensión,
/// `_`/`-` = espacio, sin tildes). Preview, then upload + replace image_urls.
class ExerciseImageBankSheet extends StatefulWidget {
  final SupabaseClient client;

  /// Exercises the caller may edit (`id`, `name`): admin = visible globals,
  /// trainer = own visible exercises.
  final List<Map<String, dynamic>> exercises;
  final bool isAdmin;

  const ExerciseImageBankSheet({
    super.key,
    required this.client,
    required this.exercises,
    required this.isAdmin,
  });

  /// Returns true if any image was uploaded.
  static Future<bool> show(
    BuildContext context, {
    required SupabaseClient client,
    required List<Map<String, dynamic>> exercises,
    required bool isAdmin,
  }) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExerciseImageBankSheet(
          client: client, exercises: exercises, isAdmin: isAdmin),
    );
    return r == true;
  }

  @override
  State<ExerciseImageBankSheet> createState() => _ExerciseImageBankSheetState();
}

class _ExerciseImageBankSheetState extends State<ExerciseImageBankSheet> {
  List<_PickedImage> _images = const [];
  List<String> _rejected = const [];
  Map<String, String?> _matches = const {};
  bool _busy = false;
  String? _progress;
  String? _message;

  late final Map<String, String> _nameById = {
    for (final e in widget.exercises)
      if (e['id'] != null) e['id'].toString(): (e['name'] ?? '').toString(),
  };

  Future<void> _pick() async {
    final r = await _pickImageFiles();
    if (r == null || !mounted) return;
    setState(() {
      _images = r.images;
      _rejected = r.rejected;
      _matches = matchImagesToExercises(
          r.images.map((i) => i.name), widget.exercises);
      _message = null;
    });
  }

  int get _matchedCount => _matches.values.where((v) => v != null).length;

  Future<void> _upload() async {
    setState(() {
      _busy = true;
      _progress = 'Subiendo…';
    });
    final up = await _uploadMatched(widget.client, _images, _matches, (d, t) {
      if (mounted) setState(() => _progress = 'Subiendo $d/$t…');
    });
    if (!mounted) return;
    if (up.ok == 0) {
      setState(() {
        _busy = false;
        _progress = null;
        _message = 'No se pudo subir ninguna imagen (${up.failed} fallidas).';
      });
      return;
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text('${up.ok} imágenes asignadas'
          '${up.failed > 0 ? ' · ${up.failed} fallidas' : ''}'),
      backgroundColor: RedesignColors.success,
    ));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [..._images]..sort((a, b) {
        final ma = _matches[a.name] == null ? 1 : 0;
        final mb = _matches[b.name] == null ? 1 : 0;
        return ma != mb ? ma - mb : a.name.compareTo(b.name);
      });
    return _sheet(context, [
      Text('Banco de imágenes',
          style:
              RedesignType.headingMd.copyWith(color: RedesignColors.primario50)),
      const SizedBox(height: 6),
      Text(
        'Subí muchas fotos a la vez. Cada archivo se asigna al ejercicio con '
        'el mismo nombre (ej. "press_banca_plano.jpg" → "Press banca plano"). '
        'La foto reemplaza las fotos actuales del ejercicio.',
        style: RedesignType.label.copyWith(color: RedesignColors.primario300),
      ),
      const SizedBox(height: 4),
      Text(
        widget.isAdmin
            ? 'Se aplica a los ejercicios globales.'
            : 'Se aplica solo a tus ejercicios.',
        style: RedesignType.label.copyWith(color: RedesignColors.secundario300),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: _busy ? null : _pick,
          style: _secondaryStyle(),
          icon: const Icon(Icons.photo_library_rounded, size: 18),
          label: Text(_images.isEmpty ? 'Elegir imágenes' : 'Elegir otras'),
        ),
      ),
      if (_images.isNotEmpty || _rejected.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(
          '$_matchedCount con coincidencia · '
          '${_images.length - _matchedCount} sin coincidencia'
          '${_rejected.isNotEmpty ? ' · ${_rejected.length} ignoradas' : ''}',
          style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final img in sorted)
                _matches[img.name] != null
                    ? _statusLine(
                        Icons.check_circle_outline_rounded,
                        RedesignColors.exito500,
                        '${img.name} → ${_nameById[_matches[img.name]] ?? ''}')
                    : _statusLine(Icons.help_outline_rounded,
                        RedesignColors.warning, '${img.name} — sin coincidencia'),
              for (final n in _rejected)
                _statusLine(Icons.error_outline_rounded,
                    RedesignColors.peligro400,
                    '$n — formato no válido o > 10 MB'),
            ],
          ),
        ),
      ],
      if (_progress != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_progress!,
              style: const TextStyle(color: RedesignColors.primario200)),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_message!,
              style: const TextStyle(color: RedesignColors.peligro400)),
        ),
      const SizedBox(height: 12),
      _footer(context,
          busy: _busy,
          label: 'Subir ($_matchedCount)',
          onPressed: _matchedCount == 0 ? null : _upload),
    ]);
  }
}
