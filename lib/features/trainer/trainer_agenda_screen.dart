import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/trainer_task_model.dart';
import '../../models/athlete_schedule_slot.dart';
import '../../services/trainer_service.dart';

/// Trainer "Organización / Agenda": dated pendientes + weekly athlete schedule.
class TrainerAgendaScreen extends ConsumerStatefulWidget {
  const TrainerAgendaScreen({super.key});

  @override
  ConsumerState<TrainerAgendaScreen> createState() =>
      _TrainerAgendaScreenState();
}

class _TrainerAgendaScreenState extends ConsumerState<TrainerAgendaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Agenda'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.textLight,
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Horarios'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [_TasksTab(), _ScheduleTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        onPressed: () => _tabs.index == 0
            ? _openTaskSheet(context, ref)
            : _openSlotSheet(context, ref),
        icon: const Icon(Icons.add),
        label: Text(_tabs.index == 0 ? 'Pendiente' : 'Horario'),
      ),
    );
  }
}

// ==================== PENDIENTES ====================

class _TasksTab extends ConsumerWidget {
  const _TasksTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(trainerTasksProvider);
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return _EmptyState(
            icon: Icons.checklist_rounded,
            text: 'Sin pendientes.\nTocá + para agregar uno.',
          );
        }
        final overdue = tasks.where((t) => t.isOverdue).toList();
        final today = tasks.where((t) {
          if (t.isDone || t.dueDate == null) return false;
          final n = DateTime.now();
          final d = t.dueDate!;
          return d.year == n.year && d.month == n.month && d.day == n.day;
        }).toList();
        final upcoming = tasks
            .where((t) =>
                !t.isDone &&
                !t.isOverdue &&
                !today.contains(t) &&
                t.dueDate != null)
            .toList();
        final noDate =
            tasks.where((t) => !t.isDone && t.dueDate == null).toList();
        final done = tasks.where((t) => t.isDone).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _section('Vencidos', overdue, ref, color: AppColors.error),
            _section('Hoy', today, ref, color: AppColors.warning),
            _section('Próximos', upcoming, ref),
            _section('Sin fecha', noDate, ref),
            _section('Completados', done, ref, color: AppColors.success),
          ],
        );
      },
    );
  }

  Widget _section(String title, List<TrainerTask> items, WidgetRef ref,
      {Color? color}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: color ?? AppColors.textLight,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...items.map((t) => _TaskTile(task: t)),
      ],
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final TrainerTask task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateLabel = task.dueDate != null
        ? '${task.dueDate!.day.toString().padLeft(2, '0')}/${task.dueDate!.month.toString().padLeft(2, '0')}'
        : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: task.isOverdue
              ? AppColors.error.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openTaskSheet(context, ref, existing: task),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  task.isDone
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: task.isDone ? AppColors.success : AppColors.textLight,
                ),
                onPressed: () async {
                  await ref
                      .read(trainerServiceProvider)
                      .setTaskDone(task.id, !task.isDone);
                  ref.invalidate(trainerTasksProvider);
                },
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        decoration: task.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (task.athleteName != null || dateLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          [
                            if (dateLabel != null) dateLabel,
                            if (task.athleteName != null) task.athleteName!,
                          ].join(' · '),
                          style: TextStyle(
                            color: task.isOverdue
                                ? AppColors.error
                                : AppColors.textLight,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.textLight, size: 20),
                onPressed: () async {
                  await ref.read(trainerServiceProvider).deleteTask(task.id);
                  ref.invalidate(trainerTasksProvider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openTaskSheet(BuildContext context, WidgetRef ref,
    {TrainerTask? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TaskSheet(existing: existing),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  final TrainerTask? existing;
  const _TaskSheet({this.existing});

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _dueDate = widget.existing?.dueDate;
  late String? _athleteId = widget.existing?.athleteId;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final service = ref.read(trainerServiceProvider);
    try {
      if (widget.existing == null) {
        await service.createTask(
          title: _title.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          dueDate: _dueDate,
          athleteId: _athleteId,
        );
      } else {
        await service.updateTask(
          id: widget.existing!.id,
          title: _title.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          dueDate: _dueDate,
          athleteId: _athleteId,
        );
      }
      ref.invalidate(trainerTasksProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'Nuevo pendiente' : 'Editar pendiente',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Título (ej: Armar dieta de Juan)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: _dec('Notas (opcional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _dueDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                    icon: const Icon(Icons.event, size: 18),
                    label: Text(
                      _dueDate == null
                          ? 'Fecha'
                          : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (_dueDate != null)
                  IconButton(
                    icon: Icon(Icons.clear, color: AppColors.textLight),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _athleteId,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Alumno (opcional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Ninguno')),
                ...students.map((s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                        (s['name'] as String?) ?? 'Alumno',
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
              ],
              onChanged: (v) => setState(() => _athleteId = v),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== HORARIOS ====================

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(trainerScheduleProvider);
    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (slots) {
        if (slots.isEmpty) {
          return _EmptyState(
            icon: Icons.calendar_month_rounded,
            text: 'Sin horarios cargados.\nTocá + para agregar el horario\nde un alumno.',
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            for (var day = 0; day < 7; day++)
              _dayGroup(day, slots.where((s) => s.dayOfWeek == day).toList(),
                  ref),
          ],
        );
      },
    );
  }

  Widget _dayGroup(int day, List<AthleteScheduleSlot> slots, WidgetRef ref) {
    if (slots.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            kWeekdayNamesEs[day],
            style: const TextStyle(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ...slots.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s.startTime,
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  s.athleteName ?? 'Alumno',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: s.notes != null
                    ? Text(s.notes!,
                        style: TextStyle(
                            color: AppColors.textLight, fontSize: 12))
                    : null,
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline_rounded,
                      color: AppColors.textLight, size: 20),
                  onPressed: () async {
                    await ref
                        .read(trainerServiceProvider)
                        .deleteScheduleSlot(s.id);
                    ref.invalidate(trainerScheduleProvider);
                  },
                ),
              ),
            )),
      ],
    );
  }
}

Future<void> _openSlotSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SlotSheet(),
  );
}

class _SlotSheet extends ConsumerStatefulWidget {
  const _SlotSheet();

  @override
  ConsumerState<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends ConsumerState<_SlotSheet> {
  String? _athleteId;
  int _day = 0;
  TimeOfDay? _time;
  final TextEditingController _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_athleteId == null || _time == null) return;
    setState(() => _saving = true);
    final hhmm =
        '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    try {
      await ref.read(trainerServiceProvider).createScheduleSlot(
            athleteId: _athleteId!,
            dayOfWeek: _day,
            startTime: hhmm,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      ref.invalidate(trainerScheduleProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nuevo horario',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _athleteId,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Alumno'),
              items: students
                  .map((s) => DropdownMenuItem(
                        value: s['id'] as String,
                        child: Text(
                          (s['name'] as String?) ?? 'Alumno',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _athleteId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _day,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Día'),
              items: [
                for (var d = 0; d < 7; d++)
                  DropdownMenuItem(value: d, child: Text(kWeekdayNamesEs[d])),
              ],
              onChanged: (v) => setState(() => _day = v ?? 0),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time ?? const TimeOfDay(hour: 8, minute: 0),
                );
                if (picked != null) setState(() => _time = picked);
              },
              icon: const Icon(Icons.schedule, size: 18),
              label: Text(_time == null
                  ? 'Hora'
                  : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              style: const TextStyle(color: Colors.white),
              decoration: _dec('Notas (opcional)'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_saving || _athleteId == null || _time == null)
                    ? null
                    : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SHARED ====================

InputDecoration _dec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.background.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textLight.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
