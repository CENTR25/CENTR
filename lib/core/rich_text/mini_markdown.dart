import 'package:flutter/material.dart';

import '../theme/theme_redesign.dart';

/// Tiny, dependency-free Markdown subset used for "Lectura Obligatoria":
///   `# Título`, `## Subtítulo`, `- viñeta` (or `* `), `**negrita**`,
///   blank lines = spacing. Anything else is plain text, so existing plain-text
///   content keeps rendering unchanged. Output is Flutter widgets only — no
///   HTML, no links, nothing executable.
enum MdBlockType { h1, h2, bullet, paragraph, blank }

class MdBlock {
  final MdBlockType type;
  final String text;
  const MdBlock(this.type, this.text);
}

/// A run of text, optionally bold.
class MdSpan {
  final String text;
  final bool bold;
  const MdSpan(this.text, {this.bold = false});

  @override
  bool operator ==(Object other) =>
      other is MdSpan && other.text == text && other.bold == bold;
  @override
  int get hashCode => Object.hash(text, bold);
  @override
  String toString() => 'MdSpan($text, bold: $bold)';
}

/// Splits [source] into line-level blocks. Consecutive blank lines collapse
/// into a single [MdBlockType.blank].
List<MdBlock> parseMdBlocks(String source) {
  final blocks = <MdBlock>[];
  for (final raw in source.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    final t = line.trimLeft();
    if (t.isEmpty) {
      if (blocks.isNotEmpty && blocks.last.type != MdBlockType.blank) {
        blocks.add(const MdBlock(MdBlockType.blank, ''));
      }
    } else if (t.startsWith('## ')) {
      blocks.add(MdBlock(MdBlockType.h2, t.substring(3).trim()));
    } else if (t.startsWith('# ')) {
      blocks.add(MdBlock(MdBlockType.h1, t.substring(2).trim()));
    } else if (t.startsWith('- ') || t.startsWith('* ')) {
      blocks.add(MdBlock(MdBlockType.bullet, t.substring(2).trim()));
    } else {
      blocks.add(MdBlock(MdBlockType.paragraph, line));
    }
  }
  while (blocks.isNotEmpty && blocks.last.type == MdBlockType.blank) {
    blocks.removeLast();
  }
  return blocks;
}

/// Parses `**bold**` inside a line. An unmatched `**` stays literal.
List<MdSpan> parseMdInline(String text) {
  final spans = <MdSpan>[];
  var i = 0;
  final buf = StringBuffer();
  void flush({bool bold = false}) {
    if (buf.isNotEmpty) {
      spans.add(MdSpan(buf.toString(), bold: bold));
      buf.clear();
    }
  }

  while (i < text.length) {
    if (text.startsWith('**', i)) {
      final end = text.indexOf('**', i + 2);
      if (end > i + 2) {
        flush();
        spans.add(MdSpan(text.substring(i + 2, end), bold: true));
        i = end + 2;
        continue;
      }
    }
    buf.write(text[i]);
    i++;
  }
  flush();
  return spans;
}

/// Renders the Markdown subset with the redesign navy/teal palette.
class MiniMarkdownView extends StatelessWidget {
  final String source;
  final double fontSize;
  final bool selectable;

  const MiniMarkdownView({
    super.key,
    required this.source,
    this.fontSize = 16,
    this.selectable = true,
  });

  TextSpan _inline(String text, TextStyle base) => TextSpan(
    style: base,
    children: [
      for (final s in parseMdInline(text))
        TextSpan(
          text: s.text,
          style: s.bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
        ),
    ],
  );

  Widget _text(TextSpan span) =>
      selectable ? SelectableText.rich(span) : Text.rich(span);

  @override
  Widget build(BuildContext context) {
    final base = RedesignType.bodySm.copyWith(
      color: RedesignColors.primario50,
      fontSize: fontSize,
      height: 1.5,
    );
    final children = <Widget>[];
    for (final b in parseMdBlocks(source)) {
      switch (b.type) {
        case MdBlockType.blank:
          children.add(SizedBox(height: fontSize * 0.7));
        case MdBlockType.h1:
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 4),
              child: _text(
                _inline(
                  b.text,
                  base.copyWith(
                    fontSize: fontSize * 1.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ),
          );
        case MdBlockType.h2:
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: _text(
                _inline(
                  b.text,
                  base.copyWith(
                    fontSize: fontSize * 1.2,
                    fontWeight: FontWeight.w600,
                    color: RedesignColors.secundario300,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          );
        case MdBlockType.bullet:
          children.add(
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '•',
                      style: base.copyWith(
                        color: RedesignColors.secundario300,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _text(_inline(b.text, base))),
                ],
              ),
            ),
          );
        case MdBlockType.paragraph:
          children.add(_text(_inline(b.text, base)));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
