import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/trainer_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/notification_providers.dart';
import '../../../models/trainer_task_model.dart';
import '../../../models/notification_model.dart';
import 'student_detail_screen.dart';
import 'routine_detail_screen.dart';
import 'meal_plan_detail_screen.dart';
import 'nuevo_plan_screen.dart';
import 'exercise_library_screen.dart';
import 'trainer_agenda_screen.dart';
import 'required_reading_editor_screen.dart';
import 'mi_suscripcion_screen.dart';
import 'elegir_plan_screen.dart';
import '../shared/redesign_toast.dart';
import 'widgets/trainer_bottom_nav.dart';

class TrainerDashboardScreen extends ConsumerStatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  ConsumerState<TrainerDashboardScreen> createState() =>
      _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState
    extends ConsumerState<TrainerDashboardScreen> {
  // New PRGS information architecture: Inicio · Alumnos · Planes.
  // Agenda + Ejercicios are reached from home buttons, Perfil from the header
  // avatar, and notifications from the header bell (per Figma "Entrenador").
  int _currentIndex = 0;
  late final PageController _pageController = PageController(
    initialPage: _currentIndex,
  );

  static const _tabs = [
    TrainerNavTab.inicio,
    TrainerNavTab.alumnos,
    TrainerNavTab.planes,
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutQuart,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        extendBody: true,
        body: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: const [_HomeView(), _StudentsView(), _PlanesView()],
        ),
        bottomNavigationBar: TrainerBottomNav(
          active: _tabs[_currentIndex],
          onInicioTap: () => _goTo(0),
          onAlumnosTap: () => _goTo(1),
          onPlanesTap: () => _goTo(2),
        ),
      ),
    );
  }
}

// ==================== HOME VIEW ====================
class _HomeView extends ConsumerStatefulWidget {
  const _HomeView();

  @override
  ConsumerState<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<_HomeView> {
  @override
  void initState() {
    super.initState();
    // Fire-and-forget: check for upcoming renewals once per trainer home open.
    // Notifications are stamped with today's date so re-opens don't duplicate.
    Future.microtask(() async {
      if (!mounted) return;
      final svc = ref.read(trainerServiceProvider);
      final supabaseSvc = ref.read(supabaseServiceProvider);
      await svc.checkAndNotifyUpcomingRenewals(supabaseSvc);
    });
  }

  void _openInvite(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InviteStudentSheet(),
    );
  }

  void _openNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BroadcastNotificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(trainerStatsProvider);
    final studentsAsync = ref.watch(myStudentsProvider);

    // "Por revisar" = students with a pending check-in (never, or > 7 days ago).
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final pendingReview = studentsAsync.maybeWhen(
      data: (students) => students.where((s) {
        final raw = s['last_check_in_at'] as String?;
        if (raw == null) return true;
        final last = DateTime.tryParse(raw);
        return last == null || last.isBefore(sevenDaysAgo);
      }).length,
      orElse: () => null,
    );

    final hasUnread = user?.id == null
        ? false
        : ref
              .watch(unreadCountProvider(user!.id))
              .maybeWhen(data: (n) => n > 0, orElse: () => false);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header: greeting + bell + avatar ──────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x6600203F), Colors.transparent],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                22,
                MediaQuery.of(context).padding.top.clamp(24.0, 100.0) + 14,
                22,
                24,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '¡Hola entrenador!',
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario300,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name ?? 'Entrenador',
                          style: RedesignType.headingMd.copyWith(
                            color: RedesignColors.primario50,
                            fontSize: 28,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderBellButton(
                    hasUnread: hasUnread,
                    onTap: () => _openNotifications(context),
                  ),
                  const SizedBox(width: 12),
                  _HeaderAvatar(
                    name: user?.name ?? user?.email,
                    avatarUrl: user?.avatarUrl,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _ProfileView()),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stat strip — Por revisar · Alumnos · Activos hoy
                _StatStrip(
                  porRevisar: pendingReview,
                  alumnos: statsAsync.valueOrNull?['total_students'] as int?,
                  activos: statsAsync.valueOrNull?['active_students'] as int?,
                ),
                const SizedBox(height: 22),

                // Primary action: Invitar nuevo alumno
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openInvite(context),
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                    label: const Text('Invitar nuevo alumno'),
                  ),
                ),
                const SizedBox(height: 12),

                // Secondary actions: Agenda · Ejercicios
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryActionButton(
                        icon: Icons.calendar_today_rounded,
                        label: 'Agenda',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrainerAgendaScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SecondaryActionButton(
                        icon: Icons.fitness_center_rounded,
                        label: 'Ejercicios',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ExerciseLibraryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Primeros pasos (auto-hides when all complete)
                const _FirstStepsChecklist(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Home header widgets ─────────────────────────────────────────────────

class _HeaderBellButton extends StatelessWidget {
  final bool hasUnread;
  final VoidCallback onTap;

  const _HeaderBellButton({required this.hasUnread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          shape: BoxShape.circle,
          border: Border.all(
            color: RedesignColors.secundario300.withValues(alpha: 0.25),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: RedesignColors.primario50,
              size: 22,
            ),
            if (hasUnread)
              Positioned(
                top: 11,
                right: 12,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: RedesignColors.actionPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: RedesignColors.primario700,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String? name;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _HeaderAvatar({
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()[0].toUpperCase()
        : 'E';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: RedesignColors.actionPrimary,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 21,
          backgroundColor: RedesignColors.primario700,
          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? NetworkImage(avatarUrl!)
              : null,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  final int? porRevisar;
  final int? alumnos;
  final int? activos;

  const _StatStrip({
    required this.porRevisar,
    required this.alumnos,
    required this.activos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _cell(porRevisar, 'Por revisar')),
          _divider(),
          Expanded(child: _cell(alumnos, 'Alumnos')),
          _divider(),
          Expanded(child: _cell(activos, 'Activos hoy')),
        ],
      ),
    );
  }

  Widget _divider() => Container(
    width: 1,
    height: 36,
    color: RedesignColors.primario50.withValues(alpha: 0.10),
  );

  Widget _cell(int? value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value?.toString() ?? '–',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
      ],
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

// ── Shared redesign bottom-sheet scaffold ───────────────────────────────
// Navy→teal gradient, top-rounded, drag handle + close button, scrollable.
class _RedesignSheet extends StatelessWidget {
  final List<Widget> children;

  const _RedesignSheet({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [RedesignColors.primario900, RedesignColors.secundario900],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50.withValues(alpha: 0.30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: RedesignColors.primario300,
                      size: 24,
                    ),
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

// ==================== PRIMEROS PASOS ====================

class _FirstStepsChecklist extends ConsumerWidget {
  const _FirstStepsChecklist();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = ref.watch(trainerFirstStepsProvider).valueOrNull;
    if (steps == null) return const SizedBox.shrink();

    // Nothing left to do → hide the whole section.
    if (steps.hasStudent &&
        steps.hasRoutine &&
        steps.hasReading &&
        steps.hasVideo) {
      return const SizedBox.shrink();
    }

    void refresh() => ref.invalidate(trainerFirstStepsProvider);

    final items = <(bool, String, VoidCallback)>[
      (
        steps.hasStudent,
        'Invita a tu primer alumno',
        () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _InviteStudentSheet(),
        ).then((_) => refresh()),
      ),
      (
        steps.hasRoutine,
        'Crea tu primera rutina',
        () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const _CreateRoutineSheet(),
        ).then((_) => refresh()),
      ),
      (
        steps.hasReading,
        'Completa la sección de lectura obligatoria',
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const RequiredReadingEditorScreen(),
          ),
        ).then((_) => refresh()),
      ),
      (
        steps.hasVideo,
        'Agrega tus propios videos al listado de ejercicios',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen()),
        ).then((_) => refresh()),
      ),
    ];

    final done = items.where((i) => i.$1).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Primeros pasos',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const Spacer(),
              Text(
                '$done/${items.length}',
                style: RedesignType.label.copyWith(
                  color: RedesignColors.secundario300,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final item in items) ...[
            const Divider(height: 1),
            InkWell(
              onTap: item.$1 ? null : item.$3,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      item.$1
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: item.$1
                          ? RedesignColors.success
                          : RedesignColors.primario400,
                      size: 24,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: RedesignType.bodySm.copyWith(
                          color: item.$1
                              ? RedesignColors.primario400
                              : RedesignColors.primario50,
                          decoration: item.$1
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                    if (!item.$1)
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: RedesignColors.primario400,
                        size: 22,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== TEAM SUMMARY ====================

class _TeamSummarySection extends ConsumerStatefulWidget {
  const _TeamSummarySection();

  @override
  ConsumerState<_TeamSummarySection> createState() =>
      _TeamSummarySectionState();
}

class _TeamSummarySectionState extends ConsumerState<_TeamSummarySection> {
  bool _renewalsExpanded = false;
  bool _checkInsExpanded = false;

  @override
  Widget build(BuildContext context) {
    // Collapsed = next 5 days; expanded = next 30 days + recently vencidos.
    final renewalsAsync = ref.watch(
      _renewalsExpanded ? expandedRenewalsProvider : upcomingRenewalsProvider,
    );
    final studentsAsync = ref.watch(myStudentsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.groups_rounded, color: AppColors.primaryLight, size: 20),
            SizedBox(width: 8),
            Text(
              'Resumen del Equipo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Card A — Vencimientos próximos
        renewalsAsync.when(
          data: (renewals) => _buildRenewalsCard(context, renewals),
          loading: () => const _SummaryCardShimmer(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 12),

        // Card B — Check-ins pendientes
        studentsAsync.when(
          data: (students) => _buildPendingCheckInsCard(context, students, ref),
          loading: () => const _SummaryCardShimmer(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildRenewalsCard(
    BuildContext context,
    List<Map<String, dynamic>> renewals,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: renewals.isEmpty
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                renewals.isEmpty
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                color: renewals.isEmpty ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Vencimientos próximos',
                style: TextStyle(
                  color: renewals.isEmpty
                      ? AppColors.success
                      : AppColors.warning,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (renewals.isEmpty)
            Text(
              'Todo al día',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            )
          else
            ...renewals.map((athlete) {
              final name = athlete['name'] as String? ?? 'Alumno';
              final renewalStr = athlete['next_renewal_date'] as String;
              final renewalDate = DateTime.tryParse(renewalStr);
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final renewalDay = renewalDate != null
                  ? DateTime(
                      renewalDate.year,
                      renewalDate.month,
                      renewalDate.day,
                    )
                  : today;
              final daysLeft = renewalDay.difference(today).inDays;
              final dateLabel = renewalDate != null
                  ? '${renewalDate.day.toString().padLeft(2, '0')}/${renewalDate.month.toString().padLeft(2, '0')}'
                  : '';

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentDetailScreen(studentId: athlete['id'] as String),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        daysLeft <= 0 ? 'Vencido' : '$daysLeft d · $dateLabel',
                        style: TextStyle(
                          color: daysLeft <= 2
                              ? AppColors.error
                              : AppColors.warning,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.2),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }),
          _ExpandToggle(
            expanded: _renewalsExpanded,
            collapsedLabel: 'Ver todos los vencimientos',
            onTap: () => setState(() => _renewalsExpanded = !_renewalsExpanded),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCheckInsCard(
    BuildContext context,
    List<Map<String, dynamic>> students,
    WidgetRef ref,
  ) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final pending = students.where((s) {
      final raw = s['last_check_in_at'] as String?;
      if (raw == null) return true; // never checked in
      final last = DateTime.tryParse(raw);
      return last == null || last.isBefore(sevenDaysAgo);
    }).toList();

    // Most overdue first: never-checked-in (null) at top, then oldest check-in.
    pending.sort((a, b) {
      final ar = a['last_check_in_at'] as String?;
      final br = b['last_check_in_at'] as String?;
      if (ar == null && br == null) return 0;
      if (ar == null) return -1;
      if (br == null) return 1;
      return DateTime.parse(ar).compareTo(DateTime.parse(br));
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: pending.isEmpty
              ? AppColors.success.withValues(alpha: 0.25)
              : AppColors.info.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pending.isEmpty
                    ? Icons.check_circle_rounded
                    : Icons.camera_alt_rounded,
                color: pending.isEmpty ? AppColors.success : AppColors.info,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Check-ins pendientes',
                style: TextStyle(
                  color: pending.isEmpty ? AppColors.success : AppColors.info,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (pending.isNotEmpty) ...[
                const Spacer(),
                Text(
                  '${pending.length} alumno${pending.length == 1 ? '' : 's'}',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            Text(
              'Todos han hecho check-in esta semana',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            )
          else
            ...(_checkInsExpanded ? pending : pending.take(5)).map((athlete) {
              final name = athlete['name'] as String? ?? 'Alumno';
              final raw = athlete['last_check_in_at'] as String?;
              final last = raw != null ? DateTime.tryParse(raw) : null;
              final daysSince = last != null
                  ? DateTime.now().difference(last).inDays
                  : null;
              final subtitle = daysSince != null
                  ? 'Hace $daysSince día${daysSince == 1 ? '' : 's'}'
                  : 'Sin check-in';

              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        StudentDetailScreen(studentId: athlete['id'] as String),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.2),
                        size: 16,
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (pending.length > 5)
            _ExpandToggle(
              expanded: _checkInsExpanded,
              collapsedLabel: 'Ver todos (${pending.length})',
              onTap: () =>
                  setState(() => _checkInsExpanded = !_checkInsExpanded),
            ),
        ],
      ),
    );
  }
}

/// Shared "Ver todos / Ver menos" toggle used by the team-summary cards.
class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final String collapsedLabel;
  final VoidCallback onTap;

  const _ExpandToggle({
    required this.expanded,
    required this.collapsedLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              expanded ? 'Ver menos' : collapsedLabel,
              style: const TextStyle(
                color: AppColors.primaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: AppColors.primaryLight,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Home card — tasks due today or overdue. Taps through to the Agenda screen.
class _PendingTasksCard extends ConsumerStatefulWidget {
  const _PendingTasksCard();

  @override
  ConsumerState<_PendingTasksCard> createState() => _PendingTasksCardState();
}

class _PendingTasksCardState extends ConsumerState<_PendingTasksCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(trainerTasksProvider);
    return tasksAsync.when(
      loading: () => const _SummaryCardShimmer(),
      error: (_, __) => const SizedBox.shrink(),
      data: (tasks) {
        final pending = tasks.where((t) => t.isDueTodayOrOverdue).toList();
        final shown = _expanded ? pending : pending.take(3).toList();
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: pending.isEmpty
                  ? AppColors.success.withValues(alpha: 0.25)
                  : AppColors.warning.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    pending.isEmpty
                        ? Icons.check_circle_rounded
                        : Icons.checklist_rounded,
                    color: pending.isEmpty
                        ? AppColors.success
                        : AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Pendientes',
                    style: TextStyle(
                      color: pending.isEmpty
                          ? AppColors.success
                          : AppColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrainerAgendaScreen(),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryLight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Ver agenda',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (pending.isEmpty)
                Text(
                  'Sin pendientes para hoy',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                    fontSize: 14,
                  ),
                )
              else
                ...shown.map(_taskRow),
              if (pending.length > 3)
                _ExpandToggle(
                  expanded: _expanded,
                  collapsedLabel: 'Ver todos (${pending.length})',
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _taskRow(TrainerTask t) {
    final dateLabel = t.dueDate != null
        ? '${t.dueDate!.day.toString().padLeft(2, '0')}/${t.dueDate!.month.toString().padLeft(2, '0')}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t.athleteName != null ? '${t.title} · ${t.athleteName}' : t.title,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          Text(
            t.isOverdue
                ? 'Vencido${dateLabel != null ? ' · $dateLabel' : ''}'
                : 'Hoy',
            style: TextStyle(
              color: t.isOverdue ? AppColors.error : AppColors.warning,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCardShimmer extends StatelessWidget {
  const _SummaryCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

// ==================== BROADCAST NOTIFICATION SHEET ====================
class _BroadcastNotificationSheet extends ConsumerStatefulWidget {
  const _BroadcastNotificationSheet();

  @override
  ConsumerState<_BroadcastNotificationSheet> createState() =>
      _BroadcastNotificationSheetState();
}

class _BroadcastNotificationSheetState
    extends ConsumerState<_BroadcastNotificationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isLoading = false;

  // Recipient filter: all students, or a hand-picked subset (profile ids).
  bool _sendToAll = true;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_sendToAll && _selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona al menos un alumno'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final trainerService = ref.read(trainerServiceProvider);
      final students = await trainerService.getMyStudents();

      final supabaseService = ref.read(supabaseServiceProvider);

      // Enviar notificación a cada alumno destinatario.
      // notifications.user_id referencia profiles(id), no athletes(id)
      for (var student in students) {
        final profileId = student['user_id'] as String?;
        if (profileId == null) continue;
        if (!_sendToAll && !_selectedIds.contains(profileId)) continue;
        await supabaseService.createNotification(
          userId: profileId,
          type: 'broadcast',
          title: _titleController.text.trim(),
          message: _messageController.text.trim(),
        );
      }

      if (mounted) {
        final nav = Navigator.of(context);
        nav.pop();
        showRedesignToast(
          nav.context,
          title: '¡Notificación enviada!',
          subtitle: 'Se enviaron exitosamente',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserProvider)?.id;
    return _RedesignSheet(
      children: [
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notificaciones',
                style: RedesignType.headingMd.copyWith(
                  color: RedesignColors.primario50,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _sendToAll
                    ? 'Se enviará a todos los alumnos'
                    : 'Se enviará a ${_selectedIds.length} alumno(s)',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario300,
                ),
              ),
              const SizedBox(height: 18),

              // Todos / Elegir
              Row(
                children: [
                  _FilterPill(
                    label: 'Todos',
                    selected: _sendToAll,
                    onTap: () => setState(() => _sendToAll = true),
                  ),
                  const SizedBox(width: 10),
                  _FilterPill(
                    label: 'Elegir',
                    selected: !_sendToAll,
                    onTap: () => setState(() => _sendToAll = false),
                  ),
                ],
              ),

              if (!_sendToAll) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final studentsAsync = ref.watch(myStudentsProvider);
                      return studentsAsync.when(
                        data: (students) {
                          if (students.isEmpty) {
                            return Text(
                              'No tienes alumnos asignados',
                              style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.primario300,
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final pid = student['user_id'] as String?;
                              if (pid == null) {
                                return const SizedBox.shrink();
                              }
                              final name = student['name'] ?? 'Sin nombre';
                              return CheckboxListTile(
                                dense: true,
                                value: _selectedIds.contains(pid),
                                onChanged: (val) => setState(() {
                                  if (val == true) {
                                    _selectedIds.add(pid);
                                  } else {
                                    _selectedIds.remove(pid);
                                  }
                                }),
                                title: Text(
                                  name,
                                  style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.primario50,
                                  ),
                                ),
                                activeColor: RedesignColors.actionPrimary,
                                checkColor: RedesignColors.onActionPrimary,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          );
                        },
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (e, s) => Text(
                          'Error: $e',
                          style: const TextStyle(color: RedesignColors.danger),
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                ),
                decoration: const InputDecoration(hintText: 'Título'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un título'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                ),
                decoration: const InputDecoration(
                  hintText: 'Mensaje',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Ingresa un mensaje'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendNotification,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.onActionPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isLoading
                        ? 'Enviando...'
                        : (_sendToAll
                              ? 'Enviar a todos'
                              : 'Enviar a ${_selectedIds.length}'),
                  ),
                ),
              ),

              const SizedBox(height: 26),
              Text(
                'Novedades',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              if (userId != null)
                Consumer(
                  builder: (context, ref, _) {
                    final notifsAsync = ref.watch(
                      notificationsProvider(userId),
                    );
                    return notifsAsync.when(
                      data: (notifs) {
                        if (notifs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No hay novedades recientes',
                              style: RedesignType.label.copyWith(
                                color: RedesignColors.primario400,
                              ),
                            ),
                          );
                        }
                        final recent = notifs.take(8).toList();
                        return Column(
                          children: [
                            for (final n in recent) _NovedadRow(notif: n),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Notification sheet sub-widgets ──────────────────────────────────────

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? RedesignColors.secundario300
              : RedesignColors.secundario300.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          border: Border.all(
            color: RedesignColors.secundario300.withValues(
              alpha: selected ? 1 : 0.4,
            ),
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

class _NovedadRow extends StatelessWidget {
  final NotificationModel notif;

  const _NovedadRow({required this.notif});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(
              _relTime(notif.createdAt),
              style: RedesignType.label.copyWith(
                color: RedesignColors.primario400,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notif.title,
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notif.message.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    notif.message,
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.primario300,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!notif.isRead)
            Container(
              margin: const EdgeInsets.only(top: 6, left: 8),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: RedesignColors.actionPrimary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact relative timestamp for the Novedades feed: HH:mm today, "Ayer"
/// yesterday, otherwise "d MMM" (Spanish month abbreviation).
String _relTime(DateTime dtUtc) {
  final dt = dtUtc.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
  if (diff == 1) return 'Ayer';
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${dt.day} ${months[dt.month - 1]}';
}

// ==================== STUDENTS VIEW ====================
class _StudentsView extends ConsumerStatefulWidget {
  const _StudentsView();

  @override
  ConsumerState<_StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends ConsumerState<_StudentsView> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openInvite() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InviteStudentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(myStudentsProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x6600203F), Colors.transparent],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.of(context).padding.top.clamp(24.0, 100.0) + 14,
              22,
              20,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Mis alumnos',
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                      fontSize: 28,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _openInvite,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: RedesignColors.primario700,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RedesignColors.secundario300.withValues(
                          alpha: 0.35,
                        ),
                      ),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1_rounded,
                      color: RedesignColors.secundario300,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Buscar alumno',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 18),

                studentsAsync.when(
                  data: (students) {
                    if (students.isEmpty)
                      return _EmptyStudents(onInvite: _openInvite);
                    final filtered = _query.isEmpty
                        ? students
                        : students.where((s) {
                            final name = (s['name'] ?? '')
                                .toString()
                                .toLowerCase();
                            final profile =
                                s['profiles'] as Map<String, dynamic>?;
                            final email = (profile?['email'] ?? '')
                                .toString()
                                .toLowerCase();
                            return name.contains(_query) ||
                                email.contains(_query);
                          }).toList();
                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'Sin resultados para "$_query"',
                          style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario300,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final s in filtered) _StudentRow(student: s),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: RedesignColors.danger),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Map<String, dynamic> student;

  const _StudentRow({required this.student});

  @override
  Widget build(BuildContext context) {
    final name = (student['name'] ?? 'Sin nombre').toString();
    final profile = student['profiles'] as Map<String, dynamic>?;
    final email = (profile?['email'] ?? 'Sin correo').toString();
    final avatarUrl =
        (student['avatar_url'] as String?) ??
        (profile?['avatar_url'] as String?);
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(studentId: student['id']),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: RedesignColors.primario700,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.primario300,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RedesignColors.primario300,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStudents extends StatelessWidget {
  final VoidCallback onInvite;

  const _EmptyStudents({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: RedesignColors.secundario300.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.people_outline_rounded,
              size: 56,
              color: RedesignColors.secundario300,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sin alumnos',
            style: RedesignType.headingMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Invitá a tus alumnos para que puedan acceder a la app',
            textAlign: TextAlign.center,
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario300,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onInvite,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Invitar alumno'),
          ),
        ],
      ),
    );
  }
}

class _InviteStudentSheet extends ConsumerStatefulWidget {
  const _InviteStudentSheet();

  @override
  ConsumerState<_InviteStudentSheet> createState() =>
      _InviteStudentSheetState();
}

class _InviteStudentSheetState extends ConsumerState<_InviteStudentSheet> {
  String? _inviteLink;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInviteLink();
  }

  Future<void> _loadInviteLink() async {
    try {
      final trainerService = ref.read(trainerServiceProvider);
      final link = await trainerService.getMyInviteLink();
      if (mounted) {
        setState(() {
          _inviteLink = link;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyLink() async {
    if (_inviteLink == null) return;
    await Clipboard.setData(ClipboardData(text: _inviteLink!));
    if (mounted) {
      showRedesignToast(
        context,
        title: 'Enlace copiado',
        subtitle: 'Se copió el enlace',
      );
    }
  }

  Future<void> _shareLink() async {
    if (_inviteLink == null) return;
    await Share.share(
      '¡Únete a mi equipo de entrenamiento! Regístrate aquí: $_inviteLink',
      subject: 'Invitación a North Star',
    );
  }

  @override
  Widget build(BuildContext context) {
    return _RedesignSheet(
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_add_alt_1_rounded,
              color: RedesignColors.secundario300,
              size: 26,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Invitar alumno',
                style: RedesignType.headingMd.copyWith(
                  color: RedesignColors.primario50,
                  fontSize: 26,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Compartí el link mediante cualquier medio',
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario300,
          ),
        ),
        const SizedBox(height: 18),
        const Divider(color: Color(0x1AFFFFFF)),
        const SizedBox(height: 18),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: RedesignColors.danger,
                    size: 48,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $_error',
                    style: const TextStyle(color: RedesignColors.danger),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Link pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: RedesignColors.inputFill,
              borderRadius: BorderRadius.circular(RedesignRadius.input),
            ),
            child: Text(
              _inviteLink ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario200,
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Copiar · Enviar
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Enviar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RedesignColors.primario700,
                    foregroundColor: RedesignColors.primario50,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RedesignColors.advertencia800.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(RedesignRadius.banner),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: RedesignColors.advertencia400,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cuando tu alumno use este link para registrarse, '
                    'automáticamente quedará vinculado a tu cuenta.',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.advertencia100,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ==================== PLANES VIEW ====================

enum _PlanesTab { rutinas, alimentacion }

class _PlanesView extends ConsumerStatefulWidget {
  const _PlanesView();

  @override
  ConsumerState<_PlanesView> createState() => _PlanesViewState();
}

class _PlanesViewState extends ConsumerState<_PlanesView> {
  _PlanesTab _tab = _PlanesTab.rutinas;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routinesAsync = ref.watch(myRoutinesProvider);
    final mealPlansAsync = ref.watch(myMealPlansProvider);

    final isRutinas = _tab == _PlanesTab.rutinas;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header ──────────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x6600203F), Colors.transparent],
              ),
            ),
            padding: EdgeInsets.fromLTRB(
              22,
              MediaQuery.of(context).padding.top.clamp(24.0, 100.0) + 14,
              22,
              20,
            ),
            child: Text(
              'Planes',
              style: RedesignType.headingMd.copyWith(
                color: RedesignColors.primario50,
                fontSize: 28,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Segmented toggle ────────────────────────────────────
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario700,
                    borderRadius: BorderRadius.circular(
                      RedesignRadius.buttonLg,
                    ),
                    border: Border.all(
                      color: RedesignColors.secundario300.withValues(
                        alpha: 0.20,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      _TabSegment(
                        label: 'Rutinas',
                        selected: isRutinas,
                        onTap: () {
                          setState(() {
                            _tab = _PlanesTab.rutinas;
                            _query = '';
                            _searchCtrl.clear();
                          });
                        },
                      ),
                      _TabSegment(
                        label: 'Alimentación',
                        selected: !isRutinas,
                        onTap: () {
                          setState(() {
                            _tab = _PlanesTab.alimentacion;
                            _query = '';
                            _searchCtrl.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // ── Search ──────────────────────────────────────────────
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                  ),
                  decoration: InputDecoration(
                    hintText: isRutinas ? 'Buscar rutina' : 'Buscar plan',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Create button ───────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (isRutinas) {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const _CreateRoutineSheet(),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NuevoPlanScreen(),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: Text(isRutinas ? 'Nueva rutina' : 'Nuevo plan'),
                  ),
                ),
                const SizedBox(height: 16),

                // ── List ────────────────────────────────────────────────
                if (isRutinas)
                  routinesAsync.when(
                    data: (routines) {
                      final filtered = _query.isEmpty
                          ? routines
                          : routines
                                .where(
                                  (r) => (r['title'] as String? ?? '')
                                      .toLowerCase()
                                      .contains(_query),
                                )
                                .toList();
                      if (filtered.isEmpty) {
                        return _PlanesEmptyState(
                          message: _query.isEmpty
                              ? 'Sin rutinas'
                              : 'Sin resultados para "$_query"',
                        );
                      }
                      return Column(
                        children: [
                          for (final r in filtered) ...[
                            _PlanRow(
                              title: (r['title'] as String?) ?? 'Rutina',
                              subtitle: () {
                                final days = r['days_per_week'] as int?;
                                if (days != null) return '$days días';
                                return (r['objective'] as String?) ??
                                    'Sin objetivo';
                              }(),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RoutineDetailScreen(
                                    routineId: r['id'],
                                    routineTitle: r['title'] ?? 'Rutina',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: RedesignColors.danger),
                      ),
                    ),
                  )
                else
                  mealPlansAsync.when(
                    data: (plans) {
                      final filtered = _query.isEmpty
                          ? plans
                          : plans
                                .where(
                                  (p) => (p['title'] as String? ?? '')
                                      .toLowerCase()
                                      .contains(_query),
                                )
                                .toList();
                      if (filtered.isEmpty) {
                        return _PlanesEmptyState(
                          message: _query.isEmpty
                              ? 'Sin planes'
                              : 'Sin resultados para "$_query"',
                        );
                      }
                      return Column(
                        children: [
                          for (final p in filtered) ...[
                            _PlanRow(
                              title: (p['title'] as String?) ?? 'Plan',
                              subtitle: () {
                                final kcal = p['target_calories'] as int?;
                                final items =
                                    (p['meal_plan_items'] as List?) ?? const [];
                                final days =
                                    (p['days'] as int?) ??
                                    (items
                                            .map((i) => i['day_number'])
                                            .toSet()
                                            .length)
                                        .clamp(1, 9999);
                                final kcalStr = kcal != null
                                    ? '$kcal kcal'
                                    : 'Sin calorías';
                                final daysStr =
                                    '$days día${days == 1 ? '' : 's'}';
                                return '$kcalStr - $daysStr';
                              }(),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MealPlanDetailScreen(
                                    planId: p['id'],
                                    planName: p['title'] ?? 'Plan',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: RedesignColors.danger),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Planes tab segment ──────────────────────────────────────────────────────
class _TabSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? RedesignColors.secundario300 : Colors.transparent,
            borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: RedesignType.buttonSm.copyWith(
              color: selected
                  ? RedesignColors.secundario900
                  : RedesignColors.primario300,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared plan/routine row ─────────────────────────────────────────────────
class _PlanRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlanRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: RedesignColors.surface,
      borderRadius: BorderRadius.circular(RedesignRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RedesignRadius.card),
            border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario300,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: RedesignColors.primario300,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────
class _PlanesEmptyState extends StatelessWidget {
  final String message;

  const _PlanesEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Text(
        message,
        style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
      ),
    );
  }
}

class _CreateRoutineSheet extends ConsumerStatefulWidget {
  const _CreateRoutineSheet();

  @override
  ConsumerState<_CreateRoutineSheet> createState() =>
      _CreateRoutineSheetState();
}

class _CreateRoutineSheetState extends ConsumerState<_CreateRoutineSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _objectiveController = TextEditingController();
  String _level = 'beginner';
  int _daysPerWeek = 3;
  // Web-safe image state: bytes + extension instead of dart:io File
  Uint8List? _imageBytes;
  String _imageExt = 'jpg';
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final ext = x.name.split('.').last.toLowerCase();
    if (mounted) {
      setState(() {
        _imageBytes = bytes;
        _imageExt = ext.isEmpty ? 'jpg' : ext;
      });
    }
  }

  // Constants for generic images
  final List<String> _kGenericRoutineImages = [
    'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?auto=format&fit=crop&w=800&q=80',
    'https://images.unsplash.com/photo-1574680096145-d05b474e2155?auto=format&fit=crop&w=800&q=80',
  ];

  Future<void> _createRoutine() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trainerService = ref.read(trainerServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      // 1. Check for duplicate name
      final name = _titleController.text.trim();
      final exists = await trainerService.checkRoutineNameExists(name);

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ya existe una rutina con este nombre. Por favor elige otro.',
              ),
              backgroundColor: RedesignColors.danger,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // 2. Determine image URL: upload bytes if picked, else random generic
      String? imageUrl;
      if (_imageBytes != null) {
        final userId = trainerService.currentUserId;
        if (userId != null) {
          imageUrl = await storageService.uploadRoutineImageBytes(
            _imageBytes!,
            _imageExt,
            userId,
          );
        }
      } else {
        imageUrl = (_kGenericRoutineImages..shuffle()).first;
      }

      await trainerService.createRoutine(
        name: name,
        objective: _objectiveController.text.trim(),
        level: _level,
        daysPerWeek: _daysPerWeek,
        imageUrl: imageUrl,
        storageService: storageService,
      );

      if (mounted) {
        ref.invalidate(myRoutinesProvider);
        ref.invalidate(trainerStatsProvider);
        Navigator.pop(context);
        showRedesignToast(context, title: 'Rutina creada exitosamente');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear rutina: $e'),
            backgroundColor: RedesignColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levels = const [
      ('beginner', 'Principiante'),
      ('intermediate', 'Intermedio'),
      ('advanced', 'Avanzado'),
    ];

    return Theme(
      data: RedesignTheme.theme,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [RedesignColors.primario900, RedesignColors.secundario900],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: RedesignColors.primario50.withValues(
                          alpha: 0.30,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Close button
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      behavior: HitTestBehavior.opaque,
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          color: RedesignColors.primario300,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Title
                  Text(
                    'Nueva Rutina',
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configura el nombre, objetivo y estructura',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario300,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Photo picker — dashed box
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 130,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: RedesignColors.primario800,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: RedesignColors.secundario300.withValues(
                            alpha: 0.35,
                          ),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _imageBytes != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(_imageBytes!, fit: BoxFit.cover),
                                Container(
                                  color: RedesignColors.primario900.withValues(
                                    alpha: 0.45,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.edit_rounded,
                                    color: RedesignColors.primario50,
                                    size: 28,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: RedesignColors.secundario300
                                      .withValues(alpha: 0.6),
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Añadir foto',
                                  style: RedesignType.bodySm.copyWith(
                                    color: RedesignColors.secundario300
                                        .withValues(alpha: 0.7),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nombre
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la rutina',
                      prefixIcon: Icon(Icons.fitness_center_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return 'Ingresa un nombre';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Objetivo
                  TextFormField(
                    controller: _objectiveController,
                    decoration: const InputDecoration(
                      labelText: 'Objetivo (opcional)',
                      prefixIcon: Icon(Icons.track_changes_rounded),
                      hintText: 'Ej: Ganar masa muscular, Perder peso',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Nivel — teal pills
                  Text(
                    'Nivel',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario300,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: levels.map((entry) {
                      final (value, label) = entry;
                      return _FilterPill(
                        label: label,
                        selected: _level == value,
                        onTap: () => setState(() => _level = value),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Días por semana — teal pills 1–7
                  Text(
                    'Días por semana',
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario300,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      return _FilterPill(
                        label: '$day',
                        selected: _daysPerWeek == day,
                        onTap: () => setState(() => _daysPerWeek = day),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createRoutine,
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: RedesignColors.primario950,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== PROFILE VIEW ====================

class _ProfileView extends ConsumerWidget {
  const _ProfileView();

  /// Strip leading "Plan " prefix for display ("Plan Básico" → "Básico").
  static String _stripPlanPrefix(String name) {
    if (name.startsWith('Plan ')) return name.substring(5);
    return name;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final subAsync = ref.watch(myTrainerSubscriptionProvider);
    final studentsAsync = ref.watch(myStudentsProvider);

    final studentCount = studentsAsync.maybeWhen(
      data: (s) => s.length,
      orElse: () => 0,
    );

    final sub = subAsync.maybeWhen(data: (s) => s, orElse: () => null);
    final plan = sub?['subscription_plans'] as Map<String, dynamic>?;
    final planName = _stripPlanPrefix((plan?['name'] as String?) ?? 'Básico');
    final maxStudents = plan?['max_students'] as int? ?? 10;

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: RedesignColors.primario50,
              size: 20,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Perfil',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        bottomNavigationBar: TrainerBottomNav(
          active: TrainerNavTab.inicio,
          onInicioTap: () => Navigator.of(context).pop(),
          onAlumnosTap: () => Navigator.of(context).pop(),
          onPlanesTap: () => Navigator.of(context).pop(),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
          children: [
            // ── Avatar + name + email ───────────────────────────────────
            _AvatarSection(user: user),
            const SizedBox(height: 24),

            // ── Plan card ──────────────────────────────────────────────
            _ProfilePlanCard(
              planName: planName,
              studentCount: studentCount,
              maxStudents: maxStudents,
              onImprove: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ElegirPlanScreen()),
              ),
            ),
            const SizedBox(height: 16),

            // ── Menu card ──────────────────────────────────────────────
            _ProfileMenuCard(
              items: [
                _ProfileMenuRow(
                  icon: Icons.card_membership_rounded,
                  title: 'Mi suscripción',
                  subtitle: 'Plan actual y límites',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MiSuscripcionScreen(),
                    ),
                  ),
                ),
                _ProfileMenuRow(
                  icon: Icons.bar_chart_rounded,
                  title: 'Estadísticas',
                  subtitle: 'Rendimiento de tus alumnos',
                  onTap: () => _stub(context),
                ),
                _ProfileMenuRow(
                  icon: Icons.settings_rounded,
                  title: 'Configuración',
                  subtitle: 'Notificaciones y preferencias',
                  onTap: () => _stub(context),
                ),
                _ProfileMenuRow(
                  icon: Icons.help_outline_rounded,
                  title: 'Ayuda',
                  subtitle: 'Centro de soporte',
                  onTap: () => _stub(context),
                  hasDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // ── Sign out ───────────────────────────────────────────────
            Center(
              child: TextButton.icon(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: RedesignColors.danger,
                  size: 18,
                ),
                label: Text(
                  'Cerrar sesión',
                  style: RedesignType.buttonSm.copyWith(
                    color: RedesignColors.danger,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  void _stub(BuildContext context) {
    showRedesignToast(
      context,
      title: 'Próximamente',
      subtitle: 'Esta función estará disponible pronto.',
      icon: Icons.access_time_rounded,
    );
  }
}

// ── Avatar section ──────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final dynamic user; // UserModel?

  const _AvatarSection({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = (user?.name as String?) ?? 'Entrenador';
    final email = (user?.email as String?) ?? '';
    final avatarUrl = user?.avatarUrl as String?;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'E';

    return Column(
      children: [
        // Teal ring → avatar
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: RedesignColors.secundario300, width: 3),
          ),
          child: CircleAvatar(
            radius: 54,
            backgroundColor: RedesignColors.primario700,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: RedesignType.bodyMd.copyWith(
                      color: RedesignColors.actionPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 32,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name,
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
      ],
    );
  }
}

// ── Plan card ───────────────────────────────────────────────────────────────

/// Frosted "liquid glass" card: a gradient rim-light over a blurred,
/// translucent navy fill. Used for the profile plan + menu cards.
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    const radius = 20.0;
    return DecoratedBox(
      // Soft outer glow so the glass floats off the background.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        // Faint hairline rim: just a touch brighter at the top, fading out.
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              RedesignColors.primario50.withValues(alpha: 0.14),
              RedesignColors.primario50.withValues(alpha: 0.03),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 1),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                // Deep navy fill with a gentle top-to-bottom gradient.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    RedesignColors.primario700.withValues(alpha: 0.92),
                    RedesignColors.primario800.withValues(alpha: 0.94),
                  ],
                ),
              ),
              foregroundDecoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [
                    RedesignColors.primario50.withValues(alpha: 0.03),
                    RedesignColors.primario50.withValues(alpha: 0.0),
                  ],
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfilePlanCard extends StatelessWidget {
  final String planName;
  final int studentCount;
  final int maxStudents;
  final VoidCallback onImprove;

  const _ProfilePlanCard({
    required this.planName,
    required this.studentCount,
    required this.maxStudents,
    required this.onImprove,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (maxStudents > 0)
        ? (studentCount / maxStudents).clamp(0.0, 1.0)
        : 0.0;

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Header row ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu plan',
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario300,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      planName,
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: onImprove,
                style: OutlinedButton.styleFrom(
                  foregroundColor: RedesignColors.secundario300,
                  side: const BorderSide(
                    color: RedesignColors.secundario300,
                    width: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 13,
                  ),
                  shape: const StadiumBorder(),
                  textStyle: RedesignType.bodySm.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Mejorar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ── Students usage ────────────────────────────────────────────
          Row(
            children: [
              Text(
                'Alumnos',
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario300,
                ),
              ),
              const Spacer(),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$studentCount',
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' de $maxStudents',
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: RedesignColors.primario600,
              valueColor: const AlwaysStoppedAnimation<Color>(
                RedesignColors.actionPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Menu card + rows ─────────────────────────────────────────────────────────

class _ProfileMenuCard extends StatelessWidget {
  final List<_ProfileMenuRow> items;

  const _ProfileMenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(child: Column(children: items));
  }
}

class _ProfileMenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool hasDivider;

  const _ProfileMenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.hasDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: RedesignColors.primario50.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(
                      RedesignRadius.iconBadge,
                    ),
                  ),
                  child: Icon(icon, color: RedesignColors.primario50, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.primario300,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: RedesignColors.primario400,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (hasDivider)
          const Divider(
            height: 1,
            thickness: 1,
            color: RedesignColors.primario600,
            indent: 20,
            endIndent: 20,
          ),
      ],
    );
  }
}
