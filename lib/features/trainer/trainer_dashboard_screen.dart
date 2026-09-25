import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/supabase_service.dart';
import '../../../services/trainer_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/news_service.dart';
import '../../../services/notification_providers.dart';
import 'student_detail_screen.dart';
import 'routine_detail_screen.dart';
import 'meal_plan_detail_screen.dart';
import 'create_meal_plan_sheet.dart';
import 'exercise_library_screen.dart';
import 'required_reading_editor_screen.dart';
import 'trainer_benefits_screen.dart';
import '../shared/notifications_sheet.dart';

class TrainerDashboardScreen extends ConsumerStatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  ConsumerState<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends ConsumerState<TrainerDashboardScreen> {
  int _currentIndex = 0;
  late final PageController _pageController = PageController(initialPage: _currentIndex);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.people_rounded, label: 'Alumnos'),
    _NavItem(icon: Icons.fitness_center_rounded, label: 'Rutinas'),
    _NavItem(icon: Icons.restaurant_menu_rounded, label: 'Comidas'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        _HomeView(),
        _StudentsView(),
        _RoutinesView(),
        _MealPlansView(),
        _ProfileView(),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutQuart,
          );
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textLight,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        items: _navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        )).toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final statsAsync = ref.watch(trainerStatsProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accent, AppColors.primary],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.surface,
                    child: Text(
                      (user?.name ?? user?.email ?? 'E')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '¡Hola, ${user?.name ?? 'Entrenador'}!',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Stats cards
            statsAsync.when(
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.people,
                      value: '${stats['total_students'] ?? 0}',
                      label: 'Alumnos',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.fitness_center,
                      value: '${stats['total_routines'] ?? 0}',
                      label: 'Rutinas',
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      value: '${stats['active_students'] ?? 0}',
                      label: 'Activos hoy',
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              loading: () => Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.people, value: '...', label: 'Alumnos', color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.fitness_center, value: '...', label: 'Rutinas', color: AppColors.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.trending_up, value: '...', label: 'Activos hoy', color: AppColors.accent)),
                ],
              ),
              error: (_, __) => Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.people, value: '0', label: 'Alumnos', color: AppColors.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.fitness_center, value: '0', label: 'Rutinas', color: AppColors.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.trending_up, value: '0', label: 'Activos hoy', color: AppColors.accent)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Primeros pasos (auto-oculta cuando están todos completos)
            const _FirstStepsChecklist(),

            // Quick actions - Solo Invitar Alumno
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Acciones Rápidas',
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

            // Botón principal: Invitar Alumno
            _QuickActionCard(
              icon: Icons.person_add,
              label: 'Invitar nuevo alumno',
              color: AppColors.accent,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _InviteStudentSheet(),
                );
              },
            ),

            const SizedBox(height: 12),

            // Editar el listado de ejercicios (catálogo global + privados)
            _QuickActionCard(
              icon: Icons.fitness_center,
              label: 'Editar listado de ejercicios',
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ExerciseLibraryScreen(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Dashboard de Notificaciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: AppColors.primaryLight, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Notificaciones',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user?.id != null)
                      TextButton(
                        onPressed: () =>
                            showNotificationsSheet(context, user!.id),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primaryLight,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Ver todas',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded,
                          color: AppColors.primary),
                      tooltip: 'Enviar notificación a todos',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              const _BroadcastNotificationSheet(),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Notificaciones con colores
            const _NotificationsDashboard(),

            const SizedBox(height: 24),

            // Resumen del equipo
            const _TeamSummarySection(),
          ],
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
        'Invita tu primer alumno',
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
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag_rounded, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Primeros pasos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '$done/${items.length}',
                style: const TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            InkWell(
              onTap: item.$1 ? null : item.$3,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      item.$1
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: item.$1 ? AppColors.success : Colors.white38,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          color: item.$1 ? Colors.white54 : Colors.white,
                          fontSize: 14,
                          decoration:
                              item.$1 ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    if (!item.$1)
                      const Icon(Icons.chevron_right,
                          color: Colors.white38, size: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== TEAM SUMMARY ====================

class _TeamSummarySection extends ConsumerWidget {
  const _TeamSummarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final renewalsAsync = ref.watch(upcomingRenewalsProvider);
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
                  color: renewals.isEmpty ? AppColors.success : AppColors.warning,
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
                  ? DateTime(renewalDate.year, renewalDate.month, renewalDate.day)
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
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Text(
                        daysLeft <= 0
                            ? 'Vencido'
                            : '$daysLeft d · $dateLabel',
                        style: TextStyle(
                          color: daysLeft <= 2 ? AppColors.error : AppColors.warning,
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
                  style: TextStyle(
                    color: AppColors.textLight,
                    fontSize: 12,
                  ),
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
            ...pending.take(5).map((athlete) {
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
                          style: const TextStyle(color: Colors.white, fontSize: 14),
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
            Text(
              '+ ${pending.length - 5} más',
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 12,
                fontStyle: FontStyle.italic,
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color, color.withAlpha(200)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== NOTIFICATIONS DASHBOARD ====================
class _NotificationsDashboard extends ConsumerWidget {
  const _NotificationsDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final userId = user?.id;
    if (userId == null) return _EmptyNotificationsCard();

    final notificationsAsync = ref.watch(notificationsProvider(userId));
    
    return notificationsAsync.when(
      data: (notifications) {
        if (notifications.isEmpty) {
          return _EmptyNotificationsCard();
        }
        
        // Show up to 5 most recent
        final recent = notifications.take(5).toList();
        
        return Column(
          children: recent.map((notif) {
            return _NotificationCard(
              icon: notif.type.iconData,
              accentColor: notif.type.color,
              title: notif.title,
              subtitle: notif.message,
              date: notif.createdAt,
              onTap: () {
                if (!notif.isRead) {
                  final service = ref.read(supabaseServiceProvider);
                  service.markNotificationAsRead(notif.id);
                  ref.invalidate(notificationsProvider);
                  ref.invalidate(unreadCountProvider);
                }
                // Abrir el alumno relacionado si la notificación lo trae
                final athleteId = notif.data?['athlete_id'] as String?;
                if (athleteId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentDetailScreen(studentId: athleteId),
                    ),
                  );
                }
              },
            );
          }).toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primaryLight),
        ),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: TextStyle(color: AppColors.textLight)),
      ),
    );
  }
}

class _EmptyNotificationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_none_rounded, size: 48, color: Colors.white.withValues(alpha: 0.2)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin notificaciones',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las actualizaciones de tus alumnos aparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final DateTime? date;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    this.date,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono con color
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 14,
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: AppColors.textLight.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            _formatDate(date!),
                            style: TextStyle(
                              color: AppColors.textLight.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Flecha
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.3), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final date = dateTime.toLocal();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Hoy';
    } else if (diff.inDays == 1) {
      return 'Ayer';
    } else if (diff.inDays < 7) {
      return 'Hace ${diff.inDays} días';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ==================== BROADCAST NOTIFICATION SHEET ====================
class _BroadcastNotificationSheet extends ConsumerStatefulWidget {
  const _BroadcastNotificationSheet();

  @override
  ConsumerState<_BroadcastNotificationSheet> createState() => _BroadcastNotificationSheetState();
}

class _BroadcastNotificationSheetState extends ConsumerState<_BroadcastNotificationSheet> {
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
      var sent = 0;
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
        sent++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notificación enviada a $sent alumno(s)'),
            backgroundColor: AppColors.success,
          ),
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
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: AppColors.primaryLight, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enviar Notificación',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _sendToAll
                              ? 'Se enviará a todos tus alumnos'
                              : 'Se enviará a ${_selectedIds.length} alumno(s)',
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Todos'),
                    icon: Icon(Icons.groups_rounded),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Elegir'),
                    icon: Icon(Icons.person_search_rounded),
                  ),
                ],
                selected: {_sendToAll},
                onSelectionChanged: (s) =>
                    setState(() => _sendToAll = s.first),
              ),
              if (!_sendToAll) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final studentsAsync = ref.watch(myStudentsProvider);
                      return studentsAsync.when(
                        data: (students) {
                          if (students.isEmpty) {
                            return Text(
                              'No tienes alumnos asignados',
                              style: TextStyle(color: AppColors.textLight),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final pid = student['user_id'] as String?;
                              if (pid == null) return const SizedBox.shrink();
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
                                  style: const TextStyle(color: Colors.white),
                                ),
                                activeColor: AppColors.primaryLight,
                                contentPadding: EdgeInsets.zero,
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
                          style: const TextStyle(color: AppColors.error),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  prefixIcon: Icon(Icons.title),
                  hintText: 'Ej: ¡Nuevo reto disponible!',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un título';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensaje',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.message),
                  ),
                  hintText: 'Escribe tu mensaje aquí...',
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un mensaje';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white),
                  label: Text(
                    _isLoading
                        ? 'ENVIANDO...'
                        : (_sendToAll
                              ? 'ENVIAR A TODOS'
                              : 'ENVIAR A ${_selectedIds.length}'),
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // News Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      'Novedades',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 160,
                    child: Consumer(
                      builder: (context, ref, _) {
                        final newsAsync = ref.watch(publishedNewsProvider);
                        
                        return newsAsync.when(
                          data: (newsList) {
                            if (newsList.isEmpty) {
                              return Center(
                                child: Text(
                                  'No hay novedades recientes',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              );
                            }

                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              clipBehavior: Clip.none,
                              itemCount: newsList.length,
                              itemBuilder: (context, index) {
                                final news = newsList[index];
                                return _buildNewsCard(
                                  title: news.title,
                                  subtitle: news.content,
                                  color: Color(int.parse(news.accentColor.replaceAll('#', '0xFF'))),
                                  icon: _getIconData(news.iconName),
                                  imageAsset: news.imageUrl,
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const SizedBox(),
                        );
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 100), // Bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    String? imageAsset,
  }) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Background Image or Gradient
          if (imageAsset != null)
            Positioned.fill(
              child: Image.network(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: color.withValues(alpha: 0.1)),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
          // Content Overlay
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LEER MÁS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'newspaper': return Icons.newspaper_rounded;
      case 'checkroom': return Icons.checkroom_rounded;
      case 'restaurant': return Icons.restaurant_menu_rounded;
      case 'timer': return Icons.timer_outlined;
      case 'shopping_bag': return Icons.shopping_bag_rounded;
      case 'star': return Icons.star_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      default: return Icons.newspaper_rounded;
    }
  }
}

// ==================== STUDENTS VIEW ====================
class _StudentsView extends ConsumerWidget {
  const _StudentsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(myStudentsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis Alumnos'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.people_outline_rounded,
                        size: 64,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Sin alumnos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Envía una invitación para que tus alumnos puedan acceder a la app',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _showInviteStudent(context),
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Invitar alumno'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final profile = student['profiles'] as Map<String, dynamic>?;
              final name = student['name'] ?? 'Sin nombre';
              final email = profile?['email'] ?? 'Sin correo';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.surface,
                      child: Text(
                        (name.isNotEmpty ? name[0] : 'A').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name, 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                      ),
                      // Streak Badge
                      Consumer(
                        builder: (context, ref, _) {
                          final streaks = (student['streaks'] as List?) ?? [];
                          int currentStreak = 0;
                          if (streaks.isNotEmpty) {
                            final streakData = streaks.first as Map<String, dynamic>;
                            currentStreak = (streakData['current_count'] as int?) ?? 0;

                            // Live calculation
                            final lastWorkoutStr = streakData['last_activity_date'] as String?;
                            if (lastWorkoutStr != null) {
                              final lastWorkoutDate = DateTime.parse(lastWorkoutStr);
                              final now = DateTime.now();
                              final today = DateTime(now.year, now.month, now.day);
                              final yesterday = today.subtract(const Duration(days: 1));
                              final workoutDate = DateTime(lastWorkoutDate.year, lastWorkoutDate.month, lastWorkoutDate.day);
                              if (workoutDate.isBefore(yesterday) && workoutDate != today) {
                                currentStreak = 0;
                              }
                            }
                          }

                          if (currentStreak <= 0) return const SizedBox.shrink();

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '$currentStreak',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  subtitle: Text(email, style: TextStyle(color: AppColors.textLight)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentDetailScreen(studentId: student['id']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showInviteStudent(context),
        backgroundColor: AppColors.accent,
        elevation: 4,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }

  void _showInviteStudent(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _InviteStudentSheet(),
    );
  }
}

class _InviteStudentSheet extends ConsumerStatefulWidget {
  const _InviteStudentSheet();

  @override
  ConsumerState<_InviteStudentSheet> createState() => _InviteStudentSheetState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('¡Link copiado al portapapeles!'),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
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

  Future<void> _shareViaWhatsApp() async {
    if (_inviteLink == null) return;
    
    final message = Uri.encodeComponent(
      '¡Únete a mi equipo de entrenamiento! 💪\n\nRegístrate aquí: $_inviteLink'
    );
    final whatsappUrl = Uri.parse('https://wa.me/?text=$message');
    
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir WhatsApp'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header with icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.person_add_rounded, color: AppColors.primaryLight, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invitar Alumno',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Comparte tu link por WhatsApp, email o cualquier medio',
                        style: TextStyle(
                          color: AppColors.textLight,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Link display area
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
                      const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                      const SizedBox(height: 8),
                      Text('Error: $_error', style: const TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              )
            else ...[
              // Link container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, color: AppColors.primaryLight),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _inviteLink ?? '',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              // WhatsApp button (prominent)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _shareViaWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 22),
                  label: const Text('ENVIAR POR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              
              // Secondary buttons row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyLink,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('COPIAR'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareLink,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('OTROS'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Helper text
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.info, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cuando tu alumno use este link para registrarse, automáticamente quedará vinculado a tu cuenta.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ==================== ROUTINES VIEW ====================
class _RoutinesView extends ConsumerWidget {
  const _RoutinesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routinesAsync = ref.watch(myRoutinesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rutinas'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center, color: Colors.white),
            tooltip: 'Editar listado de ejercicios',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ExerciseLibraryScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: routinesAsync.when(
        data: (routines) {
          if (routines.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.fitness_center_rounded, size: 64, color: AppColors.success),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Sin rutinas', 
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Crea tu primera rutina de entrenamiento', 
                      textAlign: TextAlign.center, 
                      style: TextStyle(color: AppColors.textLight, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateRoutine(context), 
                      icon: const Icon(Icons.add_rounded), 
                      label: const Text('Crear rutina'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              final routine = routines[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RoutineDetailScreen(
                          routineId: routine['id'],
                          routineTitle: routine['title'] ?? 'Rutina',
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      if (routine['image_url'] != null)
                        // ponytail: Image.network (browser cache), not
                        // CachedNetworkImage — the latter's stream breaks on
                        // web after navigating away and back (shows grey box).
                        Image.network(
                          routine['image_url'],
                          key: ValueKey(routine['image_url']),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : Container(
                                  height: 160,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                          errorBuilder: (context, error, stack) => Container(
                            height: 160,
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: routine['image_url'] == null 
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fitness_center_rounded, color: AppColors.success),
                            )
                          : null,
                        title: Text(
                          routine['title'] ?? 'Rutina', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                        subtitle: Text(
                          routine['objective'] ?? 'Sin objetivo',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateRoutine(context),
        backgroundColor: AppColors.success,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showCreateRoutine(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateRoutineSheet(),
    );
  }
}

class _CreateRoutineSheet extends ConsumerStatefulWidget {
  const _CreateRoutineSheet();

  @override
  ConsumerState<_CreateRoutineSheet> createState() => _CreateRoutineSheetState();
}

class _CreateRoutineSheetState extends ConsumerState<_CreateRoutineSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _objectiveController = TextEditingController();
  String _level = 'beginner';
  int _daysPerWeek = 3;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _objectiveController.dispose();
    super.dispose();
  }
  
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (mounted) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    }
  }

  // Constants for generic images
  final List<String> _kGenericRoutineImages = [
    'https://images.unsplash.com/photo-1517836357463-d25dfeac3438?auto=format&fit=crop&w=800&q=80', // Gym
    'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?auto=format&fit=crop&w=800&q=80', // Dumbbells
    'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?auto=format&fit=crop&w=800&q=80', // Trainer
    'https://images.unsplash.com/photo-1584735935682-2f2b69dff9d2?auto=format&fit=crop&w=800&q=80', // Workout
    'https://images.unsplash.com/photo-1574680096145-d05b474e2155?auto=format&fit=crop&w=800&q=80', // Fitness
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
              content: Text('Ya existe una rutina con este nombre. Por favor elige otro.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      // 2. Determine Image (File or Generic URL)
      String? imageUrl;
      if (_selectedImage == null) {
        // Pick random generic image
        imageUrl = (_kGenericRoutineImages..shuffle()).first;
      }

      await trainerService.createRoutine(
        name: name,
        objective: _objectiveController.text.trim(),
        level: _level,
        daysPerWeek: _daysPerWeek,
        imageFile: _selectedImage,
        imageUrl: imageUrl, // Pass fallback URL
        storageService: storageService,
      );

      if (mounted) {
        // Refresh routines list
        ref.invalidate(myRoutinesProvider);
        ref.invalidate(trainerStatsProvider);
        
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rutina creada exitosamente'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear rutina: $e'),
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
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.fitness_center_rounded, color: AppColors.primaryLight, size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Nueva Rutina',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _createRoutine,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    image: _selectedImage != null
                        ? DecorationImage(
                            image: FileImage(_selectedImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedImage == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded, 
                                 size: 40, color: AppColors.primaryLight.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'Añadir portada',
                              style: TextStyle(
                                color: Colors.white54,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la rutina',
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa un nombre';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _objectiveController,
                decoration: const InputDecoration(
                  labelText: 'Objetivo (opcional)',
                  prefixIcon: Icon(Icons.track_changes),
                  hintText: 'Ej: Ganar masa muscular, Perder peso',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _level,
                decoration: const InputDecoration(
                  labelText: 'Nivel',
                  prefixIcon: Icon(Icons.bar_chart),
                ),
                items: const [
                  DropdownMenuItem(value: 'beginner', child: Text('Principiante')),
                  DropdownMenuItem(value: 'intermediate', child: Text('Intermedio')),
                  DropdownMenuItem(value: 'advanced', child: Text('Avanzado')),
                ],
                onChanged: (value) => setState(() => _level = value!),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Text(
                      'Días por semana:',
                      style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primaryLight,
                          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                          thumbColor: AppColors.primaryLight,
                          overlayColor: AppColors.primaryLight.withValues(alpha: 0.1),
                          valueIndicatorColor: AppColors.primary,
                        ),
                        child: Slider(
                          value: _daysPerWeek.toDouble(),
                          min: 1,
                          max: 7,
                          divisions: 6,
                          label: '$_daysPerWeek días',
                          onChanged: (value) => setState(() => _daysPerWeek = value.round()),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_daysPerWeek',
                        style: const TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}




// ==================== MEAL PLANS VIEW ====================
class _MealPlansView extends ConsumerWidget {
  const _MealPlansView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealPlansAsync = ref.watch(myMealPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Planes Alimenticios'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: mealPlansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.restaurant_menu_rounded,
                        size: 64,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Sin planes de comida',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Crea planes alimenticios para tus alumnos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateMealPlan(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear plan'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    // Navigate to detail
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MealPlanDetailScreen(
                          planId: plan['id'],
                          planName: plan['title'] ?? 'Plan',
                        ),
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      if (plan['image_url'] != null)
                        // ponytail: see routine card above — Image.network
                        // survives web back-navigation; CachedNetworkImage doesn't.
                        Image.network(
                          plan['image_url'],
                          key: ValueKey(plan['image_url']),
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : Container(
                                  height: 160,
                                  color: Colors.white.withValues(alpha: 0.05),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                          errorBuilder: (context, error, stack) => Container(
                            height: 160,
                            color: Colors.white.withValues(alpha: 0.05),
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: plan['image_url'] == null 
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.restaurant_rounded, color: AppColors.warning),
                            )
                          : null,
                        title: Text(
                          plan['title'] ?? 'Plan', 
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
                        ),
                        subtitle: Text(
                          '${((plan['meal_plan_items'] as List?) ?? []).length} comidas',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateMealPlan(context),
        backgroundColor: AppColors.warning,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  void _showCreateMealPlan(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateMealPlanSheet(),
    );
  }
}

// ==================== PROFILE VIEW ====================
class _ProfileView extends ConsumerWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        (user?.name ?? user?.email ?? 'E')[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.name ?? 'Entrenador',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'ENTRENADOR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats
            ref.watch(trainerStatsProvider).when(
              data: (stats) => Row(
                children: [
                  Expanded(
                    child: _ProfileStatCard(
                      value: '${stats['total_students'] ?? 0}',
                      label: 'Alumnos',
                      icon: Icons.people_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileStatCard(
                      value: '${stats['total_routines'] ?? 0}',
                      label: 'Rutinas',
                      icon: Icons.fitness_center_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProfileStatCard(
                      value: '0',
                      label: 'Planes',
                      icon: Icons.restaurant_rounded,
                    ),
                  ),
                ],
              ),
              loading: () => const Row(
                children: [
                  Expanded(child: Center(child: CircularProgressIndicator())),
                ],
              ),
              error: (_, __) => Row(
                children: [
                   Expanded(child: _ProfileStatCard(value: '0', label: 'Alumnos', icon: Icons.people_rounded)),
                   const SizedBox(width: 12),
                   Expanded(child: _ProfileStatCard(value: '0', label: 'Rutinas', icon: Icons.fitness_center_rounded)),
                   const SizedBox(width: 12),
                   Expanded(child: _ProfileStatCard(value: '0', label: 'Planes', icon: Icons.restaurant_rounded)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Menu items
            _MenuItem(
              icon: Icons.menu_book_rounded,
              title: 'Lectura Obligatoria',
              subtitle: 'Aviso que verán tus alumnos al iniciar',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RequiredReadingEditorScreen(),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.star_rounded,
              title: 'Beneficios',
              subtitle: 'Descuentos de marcas afiliadas',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrainerBenefitsScreen(),
                ),
              ),
            ),
            _MenuItem(
              icon: Icons.card_membership_rounded,
              title: 'Mi Suscripción',
              subtitle: 'Plan actual y límites',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.bar_chart_rounded,
              title: 'Estadísticas',
              subtitle: 'Rendimiento de tus alumnos',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.settings_rounded,
              title: 'Configuración',
              subtitle: 'Notificaciones y preferencias',
              onTap: () {},
            ),
            _MenuItem(
              icon: Icons.help_outline_rounded,
              title: 'Ayuda',
              subtitle: 'Centro de soporte',
              onTap: () {},
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).signOut(),
                icon: const Icon(Icons.logout_rounded, color: AppColors.notificationRed),
                label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppColors.notificationRed.withValues(alpha: 0.5)),
                  foregroundColor: AppColors.notificationRed,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
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

class _ProfileStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _ProfileStatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppColors.primaryLight),
              ),
              title: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 13,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
