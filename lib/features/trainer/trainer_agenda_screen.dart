import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../models/trainer_task_model.dart';
import '../../models/athlete_schedule_slot.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';

// ---------------------------------------------------------------------------
// Trainer "Agenda" — redesigned for PRGS design system.
// Structure:
//   TrainerAgendaScreen (full-screen push, own Scaffold)
//     └─ segmented Pendientes | Horarios toggle
//         ├─ _PendientesTab
//         │   ├─ _TaskCard (section-coloured)
//         │   └─ opens _TaskSheet (new + edit)
//         └─ _HorariosTab
//             ├─ _DayPillRow
//             ├─ _SlotCard
//             └─ opens _SlotSheet (new)
//
// Sheet widgets are private (_TaskSheet, _SlotSheet) — same file per spec.
// ---------------------------------------------------------------------------

/// Day abbreviations (L M X J V S D → Mon..Sun, index 0..6).
const List<String> _kDayAbbrev = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

class TrainerAgendaScreen extends ConsumerStatefulWidget {
  const TrainerAgendaScreen({super.key});

  @override
  ConsumerState<TrainerAgendaScreen> createState() =>
      _TrainerAgendaScreenState();
}

class _TrainerAgendaScreenState extends ConsumerState<TrainerAgendaScreen> {
  int _tab = 0; // 0 = Pendientes, 1 = Horarios

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Agenda',
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Column(
          children: [
            _SegmentedToggle(
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
            Expanded(
              child: _tab == 0
                  ? _PendientesTab(onAdd: () => _openTaskSheet(context, ref))
                  : _HorariosTab(onAdd: () => _openSlotSheet(context, ref)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segmented toggle ────────────────────────────────────────────────────────

class _SegmentedToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
        ),
        child: Row(
          children: [
            _pill('Pendientes', 0),
            _pill('Horarios', 1),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, int index) {
    final active = selected == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: active
                ? RedesignColors.secundario300
                : Colors.transparent,
            borderRadius: BorderRadius.circular(RedesignRadius.buttonSm - 2),
          ),
          child: Center(
            child: Text(
              label,
              style: RedesignType.buttonSm.copyWith(
                color: active
                    ? RedesignColors.secundario900
                    : RedesignColors.primario300,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PENDIENTES TAB
// ============================================================

class _PendientesTab extends ConsumerWidget {
  final VoidCallback onAdd;
  const _PendientesTab({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(trainerTasksProvider);
    return tasksAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: RedesignColors.actionPrimary)),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: RedesignType.label.copyWith(color: RedesignColors.danger)),
      ),
      data: (tasks) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        bool isToday(DateTime? d) =>
            d != null &&
            d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;

        // Atrasado: not done, has due date, strictly before today
        final overdue =
            tasks.where((t) => !t.isDone && t.isOverdue).toList();

        // Hoy: due today (done or not done)
        final todayTasks = tasks.where((t) => isToday(t.dueDate)).toList();

        // Próximos: not done, not overdue, not today (includes no-date tasks)
        final upcoming = tasks
            .where((t) =>
                !t.isDone &&
                !t.isOverdue &&
                !isToday(t.dueDate) &&
                !overdue.contains(t))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            // "+" button
            _AddButton(label: '+ Nuevo pendiente', onTap: onAdd),
            const SizedBox(height: 16),
            _taskSection('Atrasado', overdue, ref, context,
                titleColor: RedesignColors.danger, isDanger: true),
            _taskSection('Hoy', todayTasks, ref, context),
            _taskSection('Próximos', upcoming, ref, context),
            if (overdue.isEmpty && todayTasks.isEmpty && upcoming.isEmpty)
              _emptyState(Icons.checklist_rounded,
                  'Sin pendientes.\nTocá + para agregar uno.'),
          ],
        );
      },
    );
  }

  Widget _taskSection(
    String title,
    List<TrainerTask> items,
    WidgetRef ref,
    BuildContext context, {
    Color? titleColor,
    bool isDanger = false,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: RedesignType.label.copyWith(
              color: titleColor ?? RedesignColors.primario400,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items.map(
          (t) => _TaskCard(task: t, isDanger: isDanger && !t.isDone),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48,
              color: RedesignColors.primario400.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(text,
              textAlign: TextAlign.center,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario400)),
        ],
      ),
    );
  }
}

// ── Task card ───────────────────────────────────────────────────────────────

class _TaskCard extends ConsumerWidget {
  final TrainerTask task;
  final bool isDanger;
  const _TaskCard({required this.task, this.isDanger = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = task.isDone;

    Color cardBg;
    Color cardBorder;
    Color checkColor;

    if (isDanger) {
      cardBg = RedesignColors.danger.withValues(alpha: 0.10);
      cardBorder = RedesignColors.danger.withValues(alpha: 0.45);
      checkColor = RedesignColors.danger;
    } else if (done) {
      cardBg = RedesignColors.secundario300.withValues(alpha: 0.08);
      cardBorder = RedesignColors.secundario300.withValues(alpha: 0.30);
      checkColor = RedesignColors.actionPrimary;
    } else {
      cardBg = RedesignColors.surface;
      cardBorder = RedesignColors.primario600.withValues(alpha: 0.50);
      checkColor = RedesignColors.primario400;
    }

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        await ref.read(trainerServiceProvider).deleteTask(task.id);
        ref.invalidate(trainerTasksProvider);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: RedesignColors.danger.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(RedesignRadius.card),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: RedesignColors.danger, size: 22),
      ),
      child: GestureDetector(
        onTap: () => _openTaskSheet(context, ref, existing: task),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(RedesignRadius.card),
            border: Border.all(color: cardBorder, width: 1),
          ),
          child: Row(
            children: [
              // Circular check
              GestureDetector(
                onTap: () async {
                  await ref
                      .read(trainerServiceProvider)
                      .setTaskDone(task.id, !done);
                  ref.invalidate(trainerTasksProvider);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? RedesignColors.actionPrimary.withValues(alpha: 0.20)
                        : Colors.transparent,
                    border: Border.all(
                      color: checkColor,
                      width: done ? 0 : 1.5,
                    ),
                  ),
                  child: done
                      ? Icon(Icons.check_rounded, color: checkColor, size: 18)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: RedesignType.bodySm.copyWith(
                        color: done
                            ? RedesignColors.primario400
                            : RedesignColors.primario50,
                        fontWeight: FontWeight.w600,
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        decorationColor: RedesignColors.primario400,
                      ),
                    ),
                    if (task.athleteName != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        task.athleteName!,
                        style: RedesignType.label.copyWith(
                          color: isDanger
                              ? RedesignColors.danger.withValues(alpha: 0.80)
                              : RedesignColors.primario400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Chevron hint to open edit
              Icon(Icons.chevron_right_rounded,
                  color: RedesignColors.primario500, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RedesignColors.primario800,
        title: Text('Eliminar pendiente',
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario50)),
        content: Text('¿Seguro que querés eliminar este pendiente?',
            style: RedesignType.label
                .copyWith(color: RedesignColors.primario300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.primario300)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HORARIOS TAB
// ============================================================

class _HorariosTab extends ConsumerStatefulWidget {
  final VoidCallback onAdd;
  const _HorariosTab({required this.onAdd});

  @override
  ConsumerState<_HorariosTab> createState() => _HorariosTabState();
}

class _HorariosTabState extends ConsumerState<_HorariosTab> {
  late int _selectedDay = DateTime.now().weekday - 1; // 0=Mon..6=Sun

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(trainerScheduleProvider);
    final todayDow = DateTime.now().weekday - 1;

    String dayLabel(int d) {
      if (d == todayDow) return 'Hoy';
      return kWeekdayNamesEs[d];
    }

    return slotsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: RedesignColors.actionPrimary)),
      error: (e, _) => Center(
        child: Text('Error: $e',
            style: RedesignType.label.copyWith(color: RedesignColors.danger)),
      ),
      data: (slots) {
        final daySlots = slots
            .where((s) => s.dayOfWeek == _selectedDay)
            .toList()
          ..sort((a, b) => a.startTime.compareTo(b.startTime));

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
          children: [
            // Day pill row
            _DayPillRow(
              selected: _selectedDay,
              onChanged: (d) => setState(() => _selectedDay = d),
            ),
            const SizedBox(height: 16),
            // "+" button
            _AddButton(label: '+ Nuevo horario', onTap: widget.onAdd),
            const SizedBox(height: 16),
            // Section title
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                dayLabel(_selectedDay).toUpperCase(),
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario400,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // Slots
            if (daySlots.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        size: 48,
                        color: RedesignColors.primario400
                            .withValues(alpha: 0.50)),
                    const SizedBox(height: 16),
                    Text(
                      'Sin horarios para este día',
                      textAlign: TextAlign.center,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario400),
                    ),
                  ],
                ),
              )
            else
              ...daySlots.map((s) => _SlotCard(slot: s)),
          ],
        );
      },
    );
  }
}

// ── Day pill row ─────────────────────────────────────────────────────────────

class _DayPillRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  const _DayPillRow({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final active = selected == i;
          return GestureDetector(
            onTap: () => onChanged(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active
                    ? RedesignColors.secundario300
                    : RedesignColors.secundario300.withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(RedesignRadius.buttonSm),
                border: Border.all(
                  color: RedesignColors.secundario300
                      .withValues(alpha: active ? 1 : 0.40),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  _kDayAbbrev[i],
                  style: RedesignType.buttonSm.copyWith(
                    color: active
                        ? RedesignColors.secundario900
                        : RedesignColors.secundario300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Slot card ────────────────────────────────────────────────────────────────

class _SlotCard extends ConsumerWidget {
  final AthleteScheduleSlot slot;
  const _SlotCard({required this.slot});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('slot-${slot.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) async {
        await ref
            .read(trainerServiceProvider)
            .deleteScheduleSlot(slot.id);
        ref.invalidate(trainerScheduleProvider);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: RedesignColors.danger.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(RedesignRadius.card),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: RedesignColors.danger, size: 22),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: RedesignColors.surface,
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          border: Border.all(
            color: RedesignColors.primario600.withValues(alpha: 0.50),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Time badge
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: RedesignColors.secundario300
                    .withValues(alpha: 0.15),
                borderRadius:
                    BorderRadius.circular(RedesignRadius.buttonSm),
                border: Border.all(
                  color: RedesignColors.secundario300
                      .withValues(alpha: 0.40),
                  width: 0.5,
                ),
              ),
              child: Text(
                slot.startTime,
                style: RedesignType.buttonSm.copyWith(
                  color: RedesignColors.actionPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Athlete + notes
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.athleteName ?? 'Alumno',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (slot.notes != null) ...[
                    const SizedBox(height: 2),
                    // NOTE: shows slot.notes as subtitle (Figma shows a routine
                    // name here, but schedule_slots has no routine join — only
                    // notes). FLAG: if routine is added later, join and show
                    // routine.name instead.
                    Text(
                      slot.notes!,
                      style: RedesignType.label.copyWith(
                          color: RedesignColors.primario400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario500, size: 20),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: RedesignColors.primario800,
        title: Text('Eliminar horario',
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario50)),
        content: Text('¿Seguro que querés eliminar este horario?',
            style: RedesignType.label
                .copyWith(color: RedesignColors.primario300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.primario300)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.danger)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED ADD BUTTON
// ============================================================

class _AddButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AddButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius:
              BorderRadius.circular(RedesignRadius.buttonLg),
          border: Border.all(
            color: RedesignColors.actionPrimaryDark,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: RedesignType.buttonLg.copyWith(
              color: RedesignColors.actionPrimaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SHEET SCAFFOLD (navy→teal gradient, drag handle, close X)
// Replicates trainer_dashboard_screen._RedesignSheet locally.
// ============================================================

class _Sheet extends StatelessWidget {
  final List<Widget> children;
  const _Sheet({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            RedesignColors.primario900,
            RedesignColors.secundario900,
          ],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50
                        .withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: RedesignColors.primario300,
                        size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared input decoration ──────────────────────────────────────────────────

InputDecoration _inputDec(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: RedesignType.label
          .copyWith(color: RedesignColors.neutral100),
      filled: true,
      fillColor: RedesignColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: RedesignRadius.inputBr,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: RedesignRadius.inputBr,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: RedesignRadius.inputBr,
        borderSide: const BorderSide(
            color: RedesignColors.inputBorderFocused, width: 1),
      ),
    );

// ============================================================
// TASK SHEET (create + edit)
// ============================================================

void _openTaskSheet(BuildContext context, WidgetRef ref,
    {TrainerTask? existing}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _TaskSheet(existing: existing),
    ),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  final TrainerTask? existing;
  const _TaskSheet({this.existing});

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _titleCtrl =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _notesCtrl =
      TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _dueDate = widget.existing?.dueDate;
  late String? _athleteId = widget.existing?.athleteId;
  // 0=none, 1=today, 2=tomorrow, 3=custom
  int _dueDateOption = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Initialise option index from existing dueDate
    if (widget.existing?.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final d = widget.existing!.dueDate!;
      if (d == today) {
        _dueDateOption = 1;
      } else if (d == today.add(const Duration(days: 1))) {
        _dueDateOption = 2;
      } else {
        _dueDateOption = 3;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _dueDateLabel() {
    if (_dueDate == null) return 'Sin fecha';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    if (_dueDate == today) return 'Hoy - ${_fmt(_dueDate!)}';
    if (_dueDate == tomorrow) return 'Mañana - ${_fmt(_dueDate!)}';
    return _fmt(_dueDate!);
  }

  String _fmt(DateTime d) {
    const months = [
      '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${d.day} ${months[d.month]}';
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dueDateOption = 3;
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final service = ref.read(trainerServiceProvider);
    try {
      if (widget.existing == null) {
        await service.createTask(
          title: _titleCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          dueDate: _dueDate,
          athleteId: _athleteId,
        );
      } else {
        await service.updateTask(
          id: widget.existing!.id,
          title: _titleCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
          dueDate: _dueDate,
          athleteId: _athleteId,
        );
      }
      ref.invalidate(trainerTasksProvider);
      if (mounted) {
        Navigator.pop(context);
        showRedesignToast(context, title: 'Guardado');
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final students = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return _Sheet(children: [
      // Title
      Text(
        widget.existing == null
            ? 'Nuevo pendiente'
            : 'Editar pendiente',
        style: RedesignType.bodyMd.copyWith(
          color: RedesignColors.primario50,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 20),

      // Nombre
      TextField(
        controller: _titleCtrl,
        style: RedesignType.bodySm
            .copyWith(color: RedesignColors.primario50),
        decoration: _inputDec('Nombre'),
      ),
      const SizedBox(height: 14),

      // Para cuándo
      Text(
        'Para cuándo',
        style: RedesignType.label.copyWith(
          color: RedesignColors.primario300,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _DueDateChip(
            label: 'Hoy',
            selected: _dueDateOption == 1,
            onTap: () => setState(() {
              _dueDateOption = 1;
              _dueDate = today;
            }),
          ),
          _DueDateChip(
            label: 'Mañana',
            selected: _dueDateOption == 2,
            onTap: () => setState(() {
              _dueDateOption = 2;
              _dueDate = tomorrow;
            }),
          ),
          _DueDateChip(
            label: _dueDateOption == 3 ? _dueDateLabel() : 'Elegir fecha',
            selected: _dueDateOption == 3,
            onTap: _pickCustomDate,
          ),
          _DueDateChip(
            label: 'Sin fecha',
            selected: _dueDateOption == 0,
            onTap: () => setState(() {
              _dueDateOption = 0;
              _dueDate = null;
            }),
          ),
        ],
      ),
      const SizedBox(height: 14),

      // Alumno (optional) — chips
      Text(
        'Alumno (opcional)',
        style: RedesignType.label.copyWith(
          color: RedesignColors.primario300,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StudentChip(
            name: 'Ninguno',
            selected: _athleteId == null,
            onTap: () => setState(() => _athleteId = null),
          ),
          ...students.map((s) {
            final id = s['id'] as String?;
            final name = (s['name'] as String?) ?? 'Alumno';
            return _StudentChip(
              name: name,
              selected: _athleteId == id,
              onTap: () => setState(() => _athleteId = id),
            );
          }),
        ],
      ),
      const SizedBox(height: 14),

      // Nota (optional)
      TextField(
        controller: _notesCtrl,
        style: RedesignType.bodySm
            .copyWith(color: RedesignColors.primario50),
        maxLines: 2,
        decoration: _inputDec('Nota (opcional)'),
      ),
      const SizedBox(height: 24),

      // Save button
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: RedesignColors.actionPrimary,
            foregroundColor: RedesignColors.onActionPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: RedesignRadius.buttonLgBr),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary))
              : Text('Guardar',
                  style: RedesignType.buttonLg.copyWith(
                      color: RedesignColors.onActionPrimary)),
        ),
      ),
    ]);
  }
}

// ── Due-date option chip ─────────────────────────────────────────────────────

class _DueDateChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _DueDateChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300
                  .withValues(alpha: 0.12),
          borderRadius:
              BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300
                .withValues(alpha: selected ? 1 : 0.40),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.secundario900
                : RedesignColors.secundario300,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ── Student chip (single-select) ─────────────────────────────────────────────

class _StudentChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback onTap;
  const _StudentChip(
      {required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.actionPrimary.withValues(alpha: 0.20)
              : RedesignColors.inputFill,
          borderRadius:
              BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: selected
                ? RedesignColors.actionPrimary
                : RedesignColors.primario600,
            width: 0.75,
          ),
        ),
        child: Text(
          name,
          style: RedesignType.buttonSm.copyWith(
            color: selected
                ? RedesignColors.actionPrimary
                : RedesignColors.primario300,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SLOT SHEET (create — multi-day)
// ============================================================

void _openSlotSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: const _SlotSheet(),
    ),
  );
}

class _SlotSheet extends ConsumerStatefulWidget {
  const _SlotSheet();

  @override
  ConsumerState<_SlotSheet> createState() => _SlotSheetState();
}

class _SlotSheetState extends ConsumerState<_SlotSheet> {
  String? _athleteId;
  final Set<int> _selectedDays = {};
  TimeOfDay _time = const TimeOfDay(hour: 16, minute: 30);
  final TextEditingController _notesCtrl = TextEditingController();
  String _search = '';
  bool _saving = false;

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  String _hhmm() =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_athleteId == null || _selectedDays.isEmpty) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(trainerServiceProvider);
      for (final day in _selectedDays) {
        await service.createScheduleSlot(
          athleteId: _athleteId!,
          dayOfWeek: day,
          startTime: _hhmm(),
          notes: _notesCtrl.text.trim().isEmpty
              ? null
              : _notesCtrl.text.trim(),
        );
      }
      ref.invalidate(trainerScheduleProvider);
      if (mounted) {
        Navigator.pop(context);
        showRedesignToast(context, title: 'Guardado');
      }
    } catch (e) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allStudents = ref.watch(myStudentsProvider).valueOrNull ?? [];
    final filtered = _search.isEmpty
        ? allStudents
        : allStudents.where((s) {
            final name =
                ((s['name'] as String?) ?? '').toLowerCase();
            return name.contains(_search.toLowerCase());
          }).toList();

    final canSave = _athleteId != null && _selectedDays.isNotEmpty;

    return _Sheet(children: [
      // Title
      Text(
        'Nuevo horario',
        style: RedesignType.bodyMd.copyWith(
          color: RedesignColors.primario50,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 20),

      // Search athletes
      TextField(
        style: RedesignType.bodySm
            .copyWith(color: RedesignColors.primario50),
        onChanged: (v) => setState(() => _search = v),
        decoration: _inputDec('Buscar alumno'),
      ),
      const SizedBox(height: 12),

      // Athlete chips
      if (filtered.isEmpty)
        Text('Sin alumnos',
            style: RedesignType.label
                .copyWith(color: RedesignColors.primario400))
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: filtered.map((s) {
            final id = s['id'] as String?;
            final name = (s['name'] as String?) ?? 'Alumno';
            return _StudentChip(
              name: name,
              selected: _athleteId == id,
              onTap: () => setState(() => _athleteId = id),
            );
          }).toList(),
        ),
      const SizedBox(height: 18),

      // Days header
      Text(
        'Días (podés marcar varios)',
        style: RedesignType.label.copyWith(
          color: RedesignColors.primario300,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 10),
      // Multi-select day pills
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final active = _selectedDays.contains(i);
          return GestureDetector(
            onTap: () => setState(() {
              if (active) {
                _selectedDays.remove(i);
              } else {
                _selectedDays.add(i);
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: active
                    ? RedesignColors.secundario300
                    : RedesignColors.secundario300
                        .withValues(alpha: 0.12),
                borderRadius:
                    BorderRadius.circular(RedesignRadius.buttonSm),
                border: Border.all(
                  color: RedesignColors.secundario300
                      .withValues(alpha: active ? 1 : 0.40),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  _kDayAbbrev[i],
                  style: RedesignType.buttonSm.copyWith(
                    color: active
                        ? RedesignColors.secundario900
                        : RedesignColors.secundario300,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 18),

      // Hora + Nota side by side
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hora picker
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) {
                  setState(() => _time = picked);
                }
              },
              child: Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: RedesignColors.inputFill,
                  borderRadius: RedesignRadius.inputBr,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: RedesignColors.neutral100, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _hhmm(),
                      style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nota
          Expanded(
            child: TextField(
              controller: _notesCtrl,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario50),
              decoration: _inputDec('Nota (opcional)'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // Save
      SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (canSave && !_saving) ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: RedesignColors.actionPrimary,
            foregroundColor: RedesignColors.onActionPrimary,
            disabledBackgroundColor:
                RedesignColors.disabledFill,
            disabledForegroundColor:
                RedesignColors.disabledText,
            shape: RoundedRectangleBorder(
                borderRadius: RedesignRadius.buttonLgBr),
            elevation: 0,
          ),
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary))
              : Text('Guardar',
                  style: RedesignType.buttonLg.copyWith(
                      color: RedesignColors.onActionPrimary)),
        ),
      ),
    ]);
  }
}
