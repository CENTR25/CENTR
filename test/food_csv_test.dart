import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/services/food_service.dart';

void main() {
  test('parses comma CSV with Alan header (serving_unit "100g")', () {
    const csv = 'id,name,category,state,calories,protein,carbs,fat,serving_unit\n'
        '1,Pechuga de pollo,Proteínas,Cruda,120,22.5,0,2.6,100g\n';
    final r = parseFoodsCsv(csv);
    expect(r.rows, hasLength(1));
    final d = r.rows.first.data;
    expect(r.rows.first.isValid, isTrue);
    expect(d['serving_size'], 100.0);
    expect(d['serving_unit'], 'g');
    expect(d['protein'], 22.5);
    expect(d['fiber'], 0);
  });

  test('semicolon delimiter + decimal comma + quotes', () {
    const csv = 'name;calories;protein;carbs;fat\n'
        '"Arroz; blanco";130;2,7;28;0,3\n';
    final r = parseFoodsCsv(csv);
    expect(r.rows.first.data['name'], 'Arroz; blanco');
    expect(r.rows.first.data['protein'], 2.7);
    expect(r.rows.first.data['fat'], 0.3);
  });

  test('validation errors', () {
    const csv = 'name,calories,protein\n'
        ',100,1\n'
        'Mal,abc,1\n'
        'Grande,5000,1\n'
        'Neg,100,-3\n';
    final r = parseFoodsCsv(csv);
    expect(r.rows.every((x) => !x.isValid), isTrue);
    expect(r.invalidCount, 4);
  });

  test('duplicates detected in file and vs existing, accent-insensitive', () {
    const csv = 'name,state,calories\n'
        'Atún,Crudo,100\n'
        'atun,crudo,100\n'
        'Salmón,Crudo,200\n';
    final r = parseFoodsCsv(csv, existingKeys: {foodKey('Salmon', 'crudo')});
    expect(r.rows[0].duplicate, isFalse);
    expect(r.rows[1].duplicate, isTrue);
    expect(r.rows[2].duplicate, isTrue);
    expect(r.importable, hasLength(1));
  });

  test('missing required columns and caps', () {
    expect(parseFoodsCsv('foo,bar\n1,2').fileErrors, isNotEmpty);
    expect(parseFoodsCsv('').fileErrors, isNotEmpty);
    final big = StringBuffer('name,calories\n');
    for (var i = 0; i < kMaxImportRows + 5; i++) {
      big.writeln('Food $i,10');
    }
    final r = parseFoodsCsv(big.toString());
    expect(r.rows.length, kMaxImportRows);
    expect(r.fileErrors, isNotEmpty);
  });

  test('unknown category falls back to Otros; category matched without accents',
      () {
    final r = parseFoodsCsv(
        'name,category,calories\nA,proteinas,10\nB,zzz,10\n');
    expect(r.rows[0].data['category'], 'Proteínas');
    expect(r.rows[1].data['category'], 'Otros');
  });
}
