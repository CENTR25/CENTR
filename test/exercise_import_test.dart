import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/services/exercise_import.dart';

void main() {
  group('parseExercisesCsv', () {
    test('parses semicolon CSV with Spanish accented headers', () {
      const csv = 'Nombre;Grupo Muscular;Músculos secundarios;Categoría;'
          'Equipamiento;Instrucciones;video_url;gif_url;Imagen;imagen_archivo\n'
          'Sentadilla búlgara;Piernas;Glúteos|Isquios;Fuerza;Mancuernas| Banco ;'
          'Bajar controlado;https://youtu.be/abc;;https://x.com/a.jpg|https://x.com/b.png;'
          'Sentadilla_Bulgara.JPG\n';
      final r = parseExercisesCsv(csv);
      expect(r.fileErrors, isEmpty);
      expect(r.rows, hasLength(1));
      final row = r.rows.single;
      expect(row.isValid, isTrue, reason: row.errors.join(', '));
      expect(row.line, 2);
      expect(row.data['name'], 'Sentadilla búlgara');
      expect(row.data['muscle_group'], 'Piernas');
      expect(row.data['secondary_muscles'], ['Glúteos', 'Isquios']);
      expect(row.data['category'], 'Fuerza');
      expect(row.data['equipment'], ['Mancuernas', 'Banco']);
      expect(row.data['instructions'], 'Bajar controlado');
      expect(row.data['video_url'], 'https://youtu.be/abc');
      expect(row.data['gif_url'], isNull);
      expect(row.data['image_urls'],
          ['https://x.com/a.jpg', 'https://x.com/b.png']);
      expect(row.imageFileKey, 'sentadilla bulgara');
      expect(r.importable, hasLength(1));
    });

    test('accepts comma and tab delimiters and english headers', () {
      final c = parseExercisesCsv('name,muscle_group\nPush up,Pecho\n');
      expect(c.importable.single.data['name'], 'Push up');
      final t = parseExercisesCsv('nombre\tmusculo\nRemo\tEspalda\n');
      expect(t.importable.single.data['muscle_group'], 'Espalda');
    });

    test('quoted fields keep delimiters and newlines', () {
      final r = parseExercisesCsv(
          'nombre;grupo_muscular;instrucciones\n"Press; banca";Pecho;"Paso 1\nPaso 2"\n');
      final row = r.rows.single;
      expect(row.data['name'], 'Press; banca');
      expect(row.data['instructions'], 'Paso 1\nPaso 2');
    });

    test('missing required headers is a file error', () {
      expect(parseExercisesCsv('grupo_muscular\nPecho').fileErrors.single,
          contains('nombre'));
      expect(parseExercisesCsv('nombre\nPress').fileErrors.single,
          contains('grupo_muscular'));
      expect(parseExercisesCsv('   ').fileErrors, isNotEmpty);
    });

    test('row errors: missing name/muscle, bad urls', () {
      final r = parseExercisesCsv('nombre;grupo_muscular;video_url;imagen\n'
          ';Pecho;;\n'
          'Remo;;;\n'
          'Curl;Brazos;javascript:alert(1);\n'
          'Dominada;Espalda;;ftp://x/y.jpg\n');
      expect(r.rows.map((e) => e.isValid), [false, false, false, false]);
      expect(r.rows[0].errors.join(), contains('nombre'));
      expect(r.rows[1].errors.join(), contains('grupo muscular'));
      expect(r.rows[2].errors.join(), contains('video_url'));
      expect(r.rows[3].errors.join(), contains('imagen'));
      expect(r.importable, isEmpty);
      expect(r.invalidCount, 4);
    });

    test('duplicates: against existing visible names and inside the file', () {
      final r = parseExercisesCsv(
        'nombre;grupo_muscular\nPress Banca;Pecho\npress  banca;Pecho\n'
        'Sentadilla;Piernas\n',
        existingNameKeys: {exerciseNameKey('SENTADILLA')},
      );
      expect(r.rows.map((e) => e.duplicate), [false, true, true]);
      expect(r.importable, hasLength(1));
      expect(r.duplicateCount, 2);
    });

    test('hidden names are not passed, so they do not block re-import', () {
      final r = parseExercisesCsv('nombre;grupo_muscular\nRemo;Espalda\n',
          existingNameKeys: const {});
      expect(r.importable, hasLength(1));
    });

    test('field length and row caps', () {
      final long = 'a' * (kMaxExerciseFieldLength + 1);
      final r = parseExercisesCsv('nombre;grupo_muscular\n$long;Pecho\n');
      expect(r.rows.single.isValid, isFalse);

      final many = StringBuffer('nombre;grupo_muscular\n');
      for (var i = 0; i < kMaxExerciseImportRows + 5; i++) {
        many.writeln('E$i;Pecho');
      }
      final big = parseExercisesCsv(many.toString());
      expect(big.rows, hasLength(kMaxExerciseImportRows));
      expect(big.fileErrors, isNotEmpty);
    });

    test('strips BOM and ignores unknown columns', () {
      final r =
          parseExercisesCsv('﻿nombre;foo;grupo_muscular\nPlancha;x;Core\n');
      expect(r.importable.single.data['name'], 'Plancha');
      expect(r.importable.single.data.containsKey('foo'), isFalse);
    });
  });

  group('image matching', () {
    test('imageFileKey normalizes folder, extension, separators, accents', () {
      expect(imageFileKey('fotos/Press_Banca-Plano.JPG'), 'press banca plano');
      expect(imageFileKey('Elevación  lateral.webp'), 'elevacion lateral');
      expect(imageFileKey('Remo 1.5 kg'), 'remo 1.5 kg');
    });

    test('matches by exercise name and by CSV imagen_archivo', () {
      final exercises = [
        {'id': 'a', 'name': 'Press banca plano'},
        {'id': 'b', 'name': 'Sentadilla búlgara'},
      ];
      final m = matchImagesToExercises(
        ['press_banca_plano.jpg', 'IMG_001.png', 'nada.jpg'],
        exercises,
        fileKeyToName: {
          imageFileKey('IMG_001.png'): exerciseNameKey('Sentadilla bulgara'),
        },
      );
      expect(m['press_banca_plano.jpg'], 'a');
      expect(m['IMG_001.png'], 'b');
      expect(m['nada.jpg'], isNull);
    });

    test('helpers', () {
      expect(fileExtension('a.JPeG'), 'jpeg');
      expect(fileExtension('noext'), '');
      expect(isHttpUrl('https://a.com/x.png'), isTrue);
      expect(isHttpUrl('data:image/png;base64,xx'), isFalse);
    });
  });
}
