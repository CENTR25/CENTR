/// A recurring weekly training slot for an athlete (e.g. Lunes 08:00). Backed by
/// `athlete_training_schedule`. Repeats every week.
class AthleteScheduleSlot {
  final String id;
  final String athleteId;
  final int dayOfWeek; // 0=Mon .. 6=Sun
  final String startTime; // "HH:mm" (24h, local gym time)
  final String? notes;
  final String? athleteName; // joined from athletes(name), read-only

  AthleteScheduleSlot({
    required this.id,
    required this.athleteId,
    required this.dayOfWeek,
    required this.startTime,
    this.notes,
    this.athleteName,
  });

  /// "HH:mm" trimmed from a Postgres `time` value which may arrive as "HH:mm:ss".
  static String _hhmm(Object? v) {
    final s = v?.toString() ?? '';
    final parts = s.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return s;
  }

  factory AthleteScheduleSlot.fromJson(Map<String, dynamic> json) {
    String? asStr(Object? v) =>
        v == null ? null : (v is String ? v : v.toString());
    final athlete = json['athletes'];
    return AthleteScheduleSlot(
      id: json['id']?.toString() ?? '',
      athleteId: asStr(json['athlete_id']) ?? '',
      dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
      startTime: _hhmm(json['start_time']),
      notes: asStr(json['notes']),
      athleteName:
          athlete is Map ? asStr(athlete['name']) : asStr(json['athlete_name']),
    );
  }
}

const List<String> kWeekdayNamesEs = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];
