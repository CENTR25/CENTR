import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/models/first_step_config.dart';

void main() {
  test('merge falls back to defaults when nothing is stored', () {
    final r = FirstStepConfig.merge(null);
    expect(r.map((e) => e.id), ['student', 'routine', 'mealplan', 'intake', 'reading', 'video']);
    expect(r.every((e) => e.enabled), isTrue);
  });

  test('merge keeps stored order/edits, drops unknown ids, appends missing', () {
    final r = FirstStepConfig.merge([
      {'id': 'video', 'label': 'Subí un video', 'enabled': true},
      {'id': 'ghost', 'label': 'x', 'enabled': true},
      {'id': 'student', 'label': '  ', 'enabled': false},
    ]);
    expect(r.map((e) => e.id), ['video', 'student', 'routine', 'mealplan', 'intake', 'reading']);
    expect(r[0].label, 'Subí un video');
    expect(r[1].enabled, isFalse);
    expect(r[1].label, 'Invita a tu primer alumno'); // blank label -> default
  });
}
