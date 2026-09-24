import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/models/notification_model.dart';

// The DB stores notification `type` in both camelCase and snake_case; parsing
// must map both to the same enum so "Nuevo alumno activo" gets the login icon.
NotificationModel _make(String type) => NotificationModel.fromJson({
      'id': '1',
      'user_id': 'u',
      'type': type,
      'title': 't',
      'message': 'm',
      'created_at': DateTime(2026).toIso8601String(),
    });

void main() {
  test('camelCase and snake_case map to the same type', () {
    expect(_make('firstLogin').type, NotificationType.firstLogin);
    expect(_make('first_login').type, NotificationType.firstLogin);
    expect(_make('new_student').type, NotificationType.newStudent);
    expect(_make('workoutCompleted').type, NotificationType.workoutCompleted);
  });

  test('unknown type falls back to general', () {
    expect(_make('checkInReceived').type, NotificationType.general);
    expect(_make('totally_unknown').type, NotificationType.general);
  });
}
