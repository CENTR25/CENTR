import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/news_service.dart';
import '../../services/notification_providers.dart';
import '../../widgets/benefits_content.dart';
import '../shared/notifications_sheet.dart';
import 'student_meal_plan_screen.dart';
import 'student_weight_screen.dart';
import 'student_check_in_screen.dart';
import 'student_routine_screen.dart';
import 'student_recipes_screen.dart';
import 'student_check_in_history_screen.dart';
import 'required_reading_screen.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() =>
      _StudentDashboardScreenState();
}

class _StudentDashboardScreenState
    extends ConsumerState<StudentDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomeContent(),
    const StudentMealPlanScreen(),
    const BenefitsContent(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back gesture
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        endDrawer: _buildSideDrawer(context, ref),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _pages[_currentIndex],
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        extendBody: true, // Allows the body to flow behind the dock
        bottomNavigationBar: _buildCustomBottomDock(context),
      ),
    );
  }

  Widget _buildCustomBottomDock(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.06),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Inicio
          Expanded(
            child: _buildDockItem(
              context,
              icon: Icons.home_rounded,
              label: 'Inicio',
              isActive: _currentIndex == 0,
              onTap: () => _onItemTapped(0),
            ),
          ),
          // Entrenar (rectangular, destacado pero alineado al dock)
          _buildTrainButton(context),
          // Beneficio
          Expanded(
            child: _buildDockItem(
              context,
              icon: Icons.star_rounded,
              label: 'Beneficio',
              isActive: _currentIndex == 2,
              onTap: () => _onItemTapped(2),
            ),
          ),
          // Alimentación
          Expanded(
            child: _buildDockItem(
              context,
              icon: Icons.restaurant_rounded,
              label: 'Alim.',
              isActive: _currentIndex == 1,
              onTap: () => _onItemTapped(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentRoutineScreen(),
                fullscreenDialog: true,
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: const SizedBox(
            width: 78,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(height: 2),
                Text(
                  'ENTRENAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideDrawer(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // User Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?.displayName.isNotEmpty == true
                        ? user!.displayName[0]
                        : 'A')
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
            accountName: Text(
              user?.displayName ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

          // Menu Items
          ListTile(
            leading: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
            ),
            title: const Text(
              'Historial de Check-ins',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StudentCheckInHistoryScreen(),
                ),
              );
            },
          ),
          if ((ref.watch(trainerRequiredReadingProvider).valueOrNull?.content
                      ?.trim()
                      .isNotEmpty ??
              false))
            ListTile(
              leading: const Icon(Icons.visibility_outlined,
                  color: Colors.white),
              title: const Text(
                'Lectura Obligatoria',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                final content = ref
                    .read(trainerRequiredReadingProvider)
                    .valueOrNull
                    ?.content;
                Navigator.pop(context);
                if (content != null && content.trim().isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RequiredReadingScreen(content: content),
                    ),
                  );
                }
              },
            ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white),
            title: const Text(
              'Configuración',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuración próximamente')),
              );
            },
          ),

          const Spacer(),
          const Divider(color: Colors.white10),

          // Logout
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2A2A2A),
                    title: const Text(
                      '¿Cerrar sesión?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      '¿Estás seguro de que quieres salir?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text(
                          'Cancelar',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'Salir',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  if (context.mounted) Navigator.pop(context); // Close drawer
                  await ref.read(authProvider.notifier).signOut();
                  // Auth wrapper will handle redirection to login
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.4),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      // Add padding at the bottom to account for the dock
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            // Premium Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HOLA,',
                            style: TextStyle(
                              color: AppColors.textLight.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CAMPEÓN',
                            style: TextStyle(
                              color: AppColors.studentColor.withValues(
                                alpha: 0.75,
                              ),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.studentColor.withValues(
                                alpha: 0.3,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.displayName ?? 'Tu nombre',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¿Listo para entrenar hoy?',
                        style: TextStyle(
                          color: AppColors.textLight.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Subtle renewal-date reminder so the student knows
                      // when their next payment is due.
                      Consumer(
                        builder: (context, ref, _) {
                          final date =
                              ref.watch(myRenewalDateProvider).valueOrNull;
                          if (date == null) return const SizedBox.shrink();
                          final label =
                              '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
                          return Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              'Renovación: $label',
                              style: TextStyle(
                                color: AppColors.textLight.withValues(alpha: 0.3),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Notifications with Glass Effect
                Consumer(
                  builder: (context, ref, _) {
                    final userId = ref.watch(currentUserProvider)?.id;
                    final unreadAsync = userId != null
                        ? ref.watch(unreadCountProvider(userId))
                        : null;
                    final count = unreadAsync?.valueOrNull ?? 0;
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: IconButton(
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.notifications_none_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            if (count > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.studentColor,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.background,
                                      width: 1.5,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () {
                          if (userId != null) {
                            showNotificationsSheet(context, userId);
                          }
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(width: 16),

                // Premium Avatar with Glow
                GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          AppColors.studentColor,
                          AppColors.studentColor.withValues(alpha: 0.2),
                          AppColors.studentColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.studentColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.background,
                      child: Text(
                        (user?.displayName.isNotEmpty == true
                                ? user!.displayName[0]
                                : 'A')
                            .toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.studentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // -- BANNER: notificaciones nuevas --
            // Sin push notifications, atraemos la atención del alumno aquí.
            Consumer(
              builder: (context, ref, _) {
                final userId = ref.watch(currentUserProvider)?.id;
                final count = userId != null
                    ? (ref.watch(unreadCountProvider(userId)).valueOrNull ?? 0)
                    : 0;
                if (count == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: InkWell(
                    onTap: () => showNotificationsSheet(context, userId!),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.studentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.studentColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.studentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              count == 1
                                  ? 'Tienes una notificación nueva'
                                  : 'Tienes $count notificaciones nuevas',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // -- LECTURA OBLIGATORIA (per-trainer, only if set) --
            Consumer(
              builder: (context, ref, _) {
                final reading =
                    ref.watch(trainerRequiredReadingProvider).valueOrNull;
                final content = reading?.content;
                if (content == null ||
                    content.trim().isEmpty ||
                    (reading?.accepted ?? false)) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _RequiredReadingBanner(content: content),
                );
              },
            ),

            // -- CUOTA / RENEWAL CHIP --
            Consumer(
              builder: (context, ref, _) {
                final renewalAsync = ref.watch(myRenewalDateProvider);
                return renewalAsync.when(
                  data: (renewalDate) =>
                      _buildRenewalChip(context, renewalDate),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),

            const SizedBox(height: 24),

            // -- RENOVACIÓN / CHEQUEO MENSUAL --
            Consumer(
              builder: (context, ref, _) {
                final statusAsync = ref.watch(checkInStatusProvider);
                return statusAsync.when(
                  data: (status) => _buildRenovacionCard(context, status),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),
            const SizedBox(height: 24),

            // -- TU PRÓXIMO ENTRENAMIENTO --
            const Text(
              'TU PRÓXIMO ENTRENAMIENTO',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white54,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            _buildMainActionButton(
              icon: Icons.fitness_center_rounded,
              label: 'ENTRENAMIENTO',
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentRoutineScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildMainActionButton(
              icon: Icons.camera_alt_rounded,
              label: 'CHECK-IN',
              color: AppColors.accent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentCheckInScreen()),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentCheckInHistoryScreen(),
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                ),
                child: const Text(
                  'VER HISTORIAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildMainActionButton(
              icon: Icons.monitor_weight_rounded,
              label: 'REGISTRAR PESO',
              color: AppColors.success,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentWeightScreen()),
              ),
            ),
            const SizedBox(height: 32),

            // -- Flat links --
            _buildFlatLink(
              icon: Icons.medication_outlined,
              label: 'SUPLEMENTOS',
              onTap: () async {
                // Await the future so the first tap works even if the
                // provider hasn't resolved yet
                final s = await ref.read(mySupplementsProvider.future);
                if (!context.mounted) return;
                _showSupplementChecklist(
                  context,
                  s['daily'] ?? '',
                  s['chemical'] ?? '',
                );
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildFlatLink(
              icon: Icons.newspaper_rounded,
              label: 'NOVEDADES',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  // Consumer so the sheet rebuilds when the news load
                  builder: (_) => Consumer(
                    builder: (sheetContext, sheetRef, _) =>
                        _buildNewsSheet(sheetContext, sheetRef),
                  ),
                );
              },
            ),
            const Divider(color: Colors.white10, height: 1),
            _buildFlatLink(
              icon: Icons.star_rounded,
              label: 'BENEFICIOS EXCLUSIVOS',
              onTap: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
            const SizedBox(height: 24),

            // Recetario banner
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentRecipesScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.restaurant_menu_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'RECETARIO OFICIAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '+100 Recetas Saludables',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              color: Colors.white70,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----- New Home Content Helpers -----

  Widget _buildRenewalChip(BuildContext context, DateTime? renewalDate) {
    if (renewalDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final renewalDay = DateTime(
      renewalDate.year,
      renewalDate.month,
      renewalDate.day,
    );
    final daysLeft = renewalDay.difference(today).inDays;

    // Only show within 14 days
    if (daysLeft > 14 || daysLeft < 0) return const SizedBox.shrink();

    final isUrgent = daysLeft <= 5;
    final chipColor = isUrgent ? AppColors.error : AppColors.warning;
    final dateLabel =
        '${renewalDate.day.toString().padLeft(2, '0')}/${renewalDate.month.toString().padLeft(2, '0')}/${renewalDate.year}';
    final message = isUrgent
        ? 'Tu cuota vence en $daysLeft día${daysLeft == 1 ? '' : 's'}'
        : 'Tu cuota vence el $dateLabel';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isUrgent ? Icons.warning_rounded : Icons.schedule_rounded,
            color: chipColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: chipColor,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRenovacionCard(BuildContext context, CheckInStatus status) {
    final isPending = status.isPending;
    final isFirstCheckIn = status.isFirstCheckIn;
    final isDueToday = isPending && status.daysOverdue == 0;
    final daysOverdue = status.daysOverdue;
    final dueStr = status.dueDate != null
        ? '${status.dueDate!.day} de ${_monthName(status.dueDate!.month)}'
        : 'Pendiente';
    final accentColor = isPending ? AppColors.warning : AppColors.accent;
    final eyebrow = isFirstCheckIn
        ? 'PRIMER CHECK-IN'
        : isDueToday
        ? 'CHECK-IN DE HOY'
        : isPending
        ? 'RENOVACIÓN'
        : 'SEGUIMIENTO';
    final title = isFirstCheckIn
        ? 'Completa tu primer check-in'
        : isDueToday
        ? 'Tu check-in vence hoy'
        : isPending
        ? 'Check-in vencido hace $daysOverdue ${daysOverdue == 1 ? 'día' : 'días'}'
        : 'Próximo check-in: $dueStr';
    final buttonLabel = isFirstCheckIn
        ? 'COMENZAR'
        : isPending
        ? 'ACTUALIZAR'
        : 'VER CHECK-IN';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.12),
            accentColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPending
                        ? [AppColors.warning, AppColors.warningDark]
                        : [AppColors.accent, AppColors.accentDark],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isFirstCheckIn
                      ? Icons.add_a_photo_rounded
                      : isPending
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const StudentCheckInScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    buttonLabel,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.2)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlatLink({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white.withValues(alpha: 0.5)),
              const SizedBox(width: 14),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.2),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewsSheet(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(publishedNewsProvider);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'NOVEDADES',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: newsAsync.when(
              data: (newsList) => newsList.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay novedades recientes',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: newsList.length,
                      itemBuilder: (ctx, i) {
                        final news = newsList[i];
                        return _buildNewsCard(
                          title: news.title,
                          subtitle: news.content,
                          color: Color(
                            int.parse(news.accentColor.replaceAll('#', '0xFF')),
                          ),
                          icon: _getIconData(news.iconName),
                          imageAsset: news.imageUrl,
                        );
                      },
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return month >= 1 && month <= 12 ? names[month] : '';
  }

  void _showSupplementChecklist(
    BuildContext context,
    String daily,
    String chemical,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SupplementChecklistModal(daily: daily, chemical: chemical),
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
                errorBuilder: (_, __, ___) =>
                    Container(color: color.withValues(alpha: 0.1)),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [color.withValues(alpha: 0.2), Colors.transparent],
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
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.8)],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
      case 'newspaper':
        return Icons.newspaper_rounded;
      case 'checkroom':
        return Icons.checkroom_rounded;
      case 'restaurant':
        return Icons.restaurant_menu_rounded;
      case 'timer':
        return Icons.timer_outlined;
      case 'shopping_bag':
        return Icons.shopping_bag_rounded;
      case 'star':
        return Icons.star_rounded;
      case 'fitness_center':
        return Icons.fitness_center_rounded;
      default:
        return Icons.newspaper_rounded;
    }
  }
}

// ----- Lectura Obligatoria banner ----- //
class _RequiredReadingBanner extends StatelessWidget {
  final String content;

  const _RequiredReadingBanner({required this.content});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RequiredReadingScreen(content: content),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_outlined,
                color: AppColors.success, size: 22),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Lectura Obligatoria',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Leer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----- Supplement Checklist Modal Component ----- //
class _SupplementChecklistModal extends ConsumerStatefulWidget {
  final String daily;
  final String chemical;

  const _SupplementChecklistModal({
    required this.daily,
    required this.chemical,
  });

  @override
  ConsumerState<_SupplementChecklistModal> createState() =>
      _SupplementChecklistModalState();
}

class _SupplementChecklistModalState
    extends ConsumerState<_SupplementChecklistModal> {
  // We'll track checked items locally.
  // In a real app, you might parse the strings into lists.
  // For now, we'll treat lines as items.

  late List<String> dailyItems;
  late List<String> chemicalItems;

  // Set of checked items (composite key: section_index)
  final Set<String> _checkedItems = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parseItems();
    _loadProgress();
  }

  void _parseItems() {
    dailyItems = widget.daily
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();

    chemicalItems = widget.chemical
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
  }

  Future<void> _loadProgress() async {
    // Fetch today's log properly using the service
    final log = await ref.read(studentServiceProvider).getTodaySupplementLog();

    if (log != null && log['ticked_items'] != null) {
      final ticked = List<String>.from(log['ticked_items']);
      setState(() {
        _checkedItems.addAll(ticked);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleItem(String key) async {
    setState(() {
      if (_checkedItems.contains(key)) {
        _checkedItems.remove(key);
      } else {
        _checkedItems.add(key);
      }
    });

    // Persist immediately
    await ref
        .read(studentServiceProvider)
        .logSupplements(tickedItems: _checkedItems.toList());

    // Refresh the master provider to update streaks if we had any logic there
    // ref.refresh(mySupplementsProvider); // Not strictly needed unless checking completion
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Checklist Diario',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (dailyItems.isNotEmpty) ...[
                    const Text(
                      'SUPLEMENTOS DIARIOS',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...dailyItems.asMap().entries.map((e) {
                      final key = 'daily_${e.key}';
                      return _buildCheckItem(key, e.value);
                    }),
                    const SizedBox(height: 32),
                  ],

                  if (chemicalItems.isNotEmpty) ...[
                    const Text(
                      'QUÍMICA / CICLO',
                      style: TextStyle(
                        color: Colors.purpleAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...chemicalItems.asMap().entries.map((e) {
                      final key = 'chem_${e.key}';
                      return _buildCheckItem(key, e.value);
                    }),
                  ],

                  if (dailyItems.isEmpty && chemicalItems.isEmpty)
                    const Center(
                      child: Text(
                        'No hay items para mostrar',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String key, String label) {
    final isChecked = _checkedItems.contains(key);

    return InkWell(
      onTap: () => _toggleItem(key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isChecked
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isChecked ? AppColors.primary : Colors.white54,
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isChecked ? Colors.white : Colors.white70,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive Steps Card with bounce animation and goal completion
class _StepsCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_StepsCard> createState() => _StepsCardState();
}

class _StepsCardState extends ConsumerState<_StepsCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  void _showUpdateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Actualizar Pasos',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¿Cuántos pasos llevas hoy?',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final steps = int.tryParse(controller.text) ?? 0;
              if (steps > 0) {
                ref.read(dailyStepsProvider.notifier).updateSteps(steps);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepsAsync = ref.watch(dailyStepsProvider);

    return stepsAsync.when(
      loading: () => _buildCard(
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) =>
          _buildCard(child: const Icon(Icons.error_outline, color: Colors.red)),
      data: (data) {
        final steps = data['steps'] as int? ?? 0;
        final goal = data['goal'] as int? ?? 10000;
        final updatedToday = data['updatedToday'] as bool? ?? false;
        final goalCompleted = steps >= goal && updatedToday;
        final progress = goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;

        // Start bounce animation if not updated today
        if (!updatedToday && !_bounceController.isAnimating) {
          _bounceController.repeat(reverse: true);
        } else if (updatedToday && _bounceController.isAnimating) {
          _bounceController.stop();
          _bounceController.reset();
        }

        return GestureDetector(
          onTap: _showUpdateDialog,
          child: AnimatedBuilder(
            animation: _bounceAnimation,
            builder: (context, child) {
              final bounce = !updatedToday
                  ? (1 + 0.05 * _bounceAnimation.value)
                  : 1.0;
              return Transform.scale(scale: bounce, child: child);
            },
            child: _buildCard(
              highlighted: !updatedToday,
              goalCompleted: goalCompleted,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (goalCompleted) ...[
                    // Trophy celebration
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$steps',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFD700),
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '¡META!',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ] else if (!updatedToday) ...[
                    // Not updated - show prompt
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent.withValues(alpha: 0.15),
                          ),
                        ),
                        const Icon(
                          Icons.directions_walk_rounded,
                          color: AppColors.accent,
                          size: 28,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTUALIZAR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ] else ...[
                    // Updated but goal not completed - show progress
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            color: AppColors.accent,
                          ),
                        ),
                        const Icon(
                          Icons.directions_walk_rounded,
                          color: AppColors.accent,
                          size: 24,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$steps',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '/ $goal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required Widget child,
    bool highlighted = false,
    bool goalCompleted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: goalCompleted
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFFD700).withValues(alpha: 0.15),
                  const Color(0xFFFFA500).withValues(alpha: 0.08),
                ],
              )
            : null,
        color: goalCompleted ? null : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: highlighted
              ? AppColors.accent.withValues(alpha: 0.5)
              : goalCompleted
              ? const Color(0xFFFFD700).withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlighted
                ? AppColors.accent.withValues(alpha: 0.2)
                : goalCompleted
                ? const Color(0xFFFFD700).withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
