import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rich_text/mini_markdown.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

/// "Lectura Obligatoria" the trainer's athletes see. Opens in a read view
/// (with an "Editar" action) when text already exists, straight into the
/// editor when empty. Content is a small Markdown subset (see
/// core/rich_text/mini_markdown.dart); plain text stays valid.
class RequiredReadingEditorScreen extends ConsumerStatefulWidget {
  const RequiredReadingEditorScreen({super.key});

  @override
  ConsumerState<RequiredReadingEditorScreen> createState() =>
      _RequiredReadingEditorScreenState();
}

class _RequiredReadingEditorScreenState
    extends ConsumerState<RequiredReadingEditorScreen> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _editing = false;
  bool _preview = false;
  String _saved = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final text = await ref.read(trainerServiceProvider).getRequiredReading();
    if (!mounted) return;
    setState(() {
      _saved = text ?? '';
      _controller.text = _saved;
      _editing = _saved.trim().isEmpty;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(trainerServiceProvider)
          .updateRequiredReading(_controller.text);
      ref.invalidate(myRequiredReadingProvider);
      if (!mounted) return;
      setState(() {
        _saved = _controller.text.trim();
        _isSaving = false;
        _editing = false;
        _preview = false;
      });
      showRedesignToast(context, title: 'Lectura obligatoria guardada');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showRedesignToast(
        context,
        title: 'No se pudo guardar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _controller.text = _saved;
      _editing = false;
      _preview = false;
    });
  }

  // ── Toolbar helpers ───────────────────────────────────────────────────

  void _wrapBold() {
    final v = _controller.value;
    final sel = v.selection;
    if (!sel.isValid) return;
    final text = v.text;
    final selected = sel.textInside(text);
    final replaced = selected.isEmpty ? '****' : '**$selected**';
    final newText = text.replaceRange(sel.start, sel.end, replaced);
    final caret = selected.isEmpty
        ? sel.start + 2
        : sel.start + replaced.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  void _prefixLine(String prefix) {
    final v = _controller.value;
    final text = v.text;
    final pos = v.selection.isValid ? v.selection.start : text.length;
    final lineStart = text.lastIndexOf('\n', pos > 0 ? pos - 1 : 0) + 1;
    final start = pos == 0 ? 0 : lineStart;
    // Replace any existing heading/bullet marker on this line.
    final rest = text.substring(start);
    final m = RegExp(r'^(#{1,2} |[-*] )').firstMatch(rest);
    final removed = m?.group(0)?.length ?? 0;
    final newText = text.replaceRange(start, start + removed, prefix);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (pos + prefix.length - removed).clamp(0, newText.length),
      ),
    );
  }

  Widget _toolButton(String label, VoidCallback onTap, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          foregroundColor: RedesignColors.primario50,
          side: BorderSide(
            color: RedesignColors.secundario300.withValues(alpha: 0.4),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _toolbar() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        _toolButton('B', _wrapBold, bold: true),
        _toolButton('Título', () => _prefixLine('# ')),
        _toolButton('Subtítulo', () => _prefixLine('## ')),
        _toolButton('• Viñeta', () => _prefixLine('- ')),
      ],
    ),
  );

  // ── Build ──────────────────────────────────────────────────────────────

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
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: RedesignColors.primario50,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Lectura Obligatoria',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
          actions: [
            if (!_isLoading && !_editing)
              TextButton.icon(
                onPressed: () => setState(() => _editing = true),
                style: TextButton.styleFrom(
                  foregroundColor: RedesignColors.actionPrimary,
                  minimumSize: const Size(0, 40),
                ),
                icon: const Icon(Icons.edit_rounded, size: 18),
                label: const Text('Editar'),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: RedesignColors.actionPrimary,
                ),
              )
            : _editing
            ? _editView()
            : _readView(),
      ),
    );
  }

  Widget _readView() {
    if (_saved.trim().isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: MiniMarkdownView(source: _saved),
    );
  }

  Widget _editView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Este texto le aparecerá a todos tus alumnos como lectura '
            'obligatoria. Escribí tu metodología, cómo se hacen los chequeos, '
            'obligaciones, etc. Dejalo vacío si no querés mostrar nada.',
            style: RedesignType.label.copyWith(
              color: RedesignColors.primario300,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _preview ? const SizedBox.shrink() : _toolbar()),
              TextButton.icon(
                onPressed: () => setState(() => _preview = !_preview),
                style: TextButton.styleFrom(
                  foregroundColor: RedesignColors.actionPrimary,
                  minimumSize: const Size(0, 38),
                ),
                icon: Icon(
                  _preview
                      ? Icons.edit_note_rounded
                      : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(_preview ? 'Editar' : 'Vista previa'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _preview
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: RedesignColors.primario800,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SingleChildScrollView(
                      child: MiniMarkdownView(source: _controller.text),
                    ),
                  )
                : TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      height: 1.4,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Escribí acá la información...',
                      alignLabelWithHint: true,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_saved.trim().isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _cancelEdit,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 54),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 54),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: RedesignColors.onActionPrimary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
