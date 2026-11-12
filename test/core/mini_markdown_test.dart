import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/core/rich_text/mini_markdown.dart';

void main() {
  test('blocks: headings, bullets, paragraphs, collapsed blanks', () {
    final b = parseMdBlocks('# T\n\n\n## S\n- a\n* b\ntexto\n\n');
    expect(b.map((e) => e.type).toList(), [
      MdBlockType.h1,
      MdBlockType.blank,
      MdBlockType.h2,
      MdBlockType.bullet,
      MdBlockType.bullet,
      MdBlockType.paragraph,
    ]);
    expect(b.first.text, 'T');
  });

  test('plain text without markdown stays paragraphs', () {
    final b = parseMdBlocks('hola\nmundo #1 - ok');
    expect(b.every((e) => e.type == MdBlockType.paragraph), true);
  });

  test('inline bold', () {
    expect(parseMdInline('a **b** c'), [
      const MdSpan('a '),
      const MdSpan('b', bold: true),
      const MdSpan(' c'),
    ]);
    expect(parseMdInline('sin **cerrar'), [const MdSpan('sin **cerrar')]);
    expect(parseMdInline('****'), [const MdSpan('****')]);
  });
}
