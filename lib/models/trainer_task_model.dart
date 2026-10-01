/// A trainer's personal dated to-do item ("pendiente"). Optionally linked to an
/// athlete. Backed by the `trainer_tasks` table.
class TrainerTask {
  final String id;
  final String trainerId;
  final String title;
  final String? notes;
  final DateTime? dueDate; // date-only (local)
  final bool isDone;
  final String? athleteId;
  final String? athleteName; // joined from athletes(name), read-only
  final DateTime? createdAt;

  TrainerTask({
    required this.id,
    required this.trainerId,
    required this.title,
    this.notes,
    this.dueDate,
    this.isDone = false,
    this.athleteId,
    this.athleteName,
    this.createdAt,
  });

  /// True when not done and due today or earlier (the home-card surface).
  bool get isDueTodayOrOverdue {
    if (isDone || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !dueDate!.isAfter(today);
  }

  bool get isOverdue {
    if (isDone || dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isBefore(today);
  }

  factory TrainerTask.fromJson(Map<String, dynamic> json) {
    // Coerce — Supabase JS on web can hand back non-String dynamics (web crash).
    String? asStr(Object? v) =>
        v == null ? null : (v is String ? v : v.toString());
    DateTime? asDate(Object? v) =>
        v == null ? null : DateTime.tryParse(v.toString());

    final athlete = json['athletes'];
    return TrainerTask(
      id: json['id']?.toString() ?? '',
      trainerId: asStr(json['trainer_id']) ?? '',
      title: asStr(json['title']) ?? '',
      notes: asStr(json['notes']),
      dueDate: asDate(json['due_date']),
      isDone: json['is_done'] == true,
      athleteId: asStr(json['athlete_id']),
      athleteName:
          athlete is Map ? asStr(athlete['name']) : asStr(json['athlete_name']),
      createdAt: asDate(json['created_at']),
    );
  }

  TrainerTask copyWith({bool? isDone}) => TrainerTask(
        id: id,
        trainerId: trainerId,
        title: title,
        notes: notes,
        dueDate: dueDate,
        isDone: isDone ?? this.isDone,
        athleteId: athleteId,
        athleteName: athleteName,
        createdAt: createdAt,
      );
}
