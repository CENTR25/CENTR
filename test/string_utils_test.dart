import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/core/utils/string_utils.dart';

void main() {
  test('foldSearch is accent and case insensitive', () {
    expect(foldSearch('BÍCEPS').contains('biceps'), isTrue);
    expect(foldSearch('Sentadilla').contains(foldSearch('sentadílla')), isTrue);
    expect(foldSearch('Pingüino').contains('pinguino'), isTrue);
  });
}
