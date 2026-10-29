import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/active_workout_service.dart';
import '../../services/notification_providers.dart';
import '../../services/news_service.dart';
import '../../models/news_model.dart';
import '../shared/notifications_sheet.dart';
import 'student_meal_plan_screen.dart';
import 'student_weight_screen.dart';
import 'student_check_in_screen.dart';
import 'student_recipes_screen.dart';
import 'student_benefits_screen.dart';
import 'student_profile_screen.dart';
import 'required_reading_screen.dart';
import 'student_training_nav.dart';
import 'widgets/student_bottom_nav.dart';

class StudentDashboardScreen extends ConsumerWidget {
  const StudentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Theme(
      data: RedesignTheme.theme,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: RedesignColors.background,
          extendBody: true,
          drawer: const _StudentDrawer(),
          body: const _HomeContent(),
          bottomNavigationBar: StudentBottomNav(
            active: StudentNavTab.inicio,
            onInicioTap: () {},
            onEntrenarTap: () => openTraining(context, ref),
            onNutricionTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentMealPlanScreen()),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Home scroll body
// ---------------------------------------------------------------------------

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  static const double _hPad = 22;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top gradient overlay behind the header
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x6600203F), // primario900 semi-transparent
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        _hPad,
                        MediaQuery.of(context).padding.top.clamp(24.0, 100.0) + 14,
                        _hPad,
                        24,
                      ),
                      child: _Header(user: user, ref: ref),
                    ),
                  ),

                  // Seguimiento card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _hPad),
                    child: Consumer(
                      builder: (context, ref, _) {
                        final statusAsync = ref.watch(checkInStatusProvider);
                        return statusAsync.when(
                          data: (status) => _SeguimientoCard(status: status),
                          loading: () => const _SeguimientoCard(status: null),
                          error: (_, __) => const _SeguimientoCard(status: null),
                        );
                      },
                    ),
                  ),

                  // Entrenamiento en curso card (only while a workout is
                  // begun but not yet completed)
                  Consumer(
                    builder: (context, ref, _) {
                      final active = ref.watch(activeWorkoutProvider);
                      if (active == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: _hPad),
                          child: _EntrenamientoEnCursoCard(active: active),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Quick actions (Check-in · Peso · Suplementos · Beneficios)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _hPad),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.camera_alt_rounded,
                            label: 'Check-in',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentCheckInScreen(),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.monitor_weight_rounded,
                            label: 'Peso',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentWeightScreen(),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              return _QuickAction(
                                icon: Icons.medication_outlined,
                                label: 'Suplementos',
                                onTap: () async {
                                  final structured = await ref.read(
                                      myStructuredSupplementsProvider.future);
                                  final s = await ref
                                      .read(mySupplementsProvider.future);
                                  if (!context.mounted) return;
                                  _showSupplementInfo(
                                    context,
                                    structured,
                                    s['daily'] ?? '',
                                    s['chemical'] ?? '',
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.card_giftcard_rounded,
                            label: 'Beneficios',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StudentBenefitsScreen(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Recetario oficial card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _hPad),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentRecipesScreen(),
                        ),
                      ),
                      child: const _RecetarioCard(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Novedades
                  const _NovedadesSection(),

                  const Spacer(),
                  // Clearance for the floating bottom nav
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSupplementInfo(
    BuildContext context,
    List<Map<String, dynamic>> structured,
    String daily,
    String chemical,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplementInfoModal(
        structured: structured,
        daily: daily,
        chemical: chemical,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final dynamic user; // UserModel?
  final WidgetRef ref;

  const _Header({required this.user, required this.ref});

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final userId = user?.id as String?;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left text column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¡Hola!',
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario300,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name.isNotEmpty ? name : 'Atleta',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: RedesignColors.primario50,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '¿Listo para entrenar hoy?',
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        // Bell icon button
        Consumer(
          builder: (context, ref, _) {
            final count = userId != null
                ? (ref.watch(unreadCountProvider(userId)).valueOrNull ?? 0)
                : 0;

            return GestureDetector(
              onTap: () {
                if (userId != null) showNotificationsSheet(context, userId);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: RedesignColors.primario800,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.notifications_outlined,
                      color: RedesignColors.primario50,
                      size: 20,
                    ),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: RedesignColors.actionPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: RedesignColors.onActionPrimary,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 10),

        // Circular avatar with teal ring — tap opens the side drawer
        Builder(builder: (context) {
          final avatarUrl =
              ref.watch(myAthleteProfileProvider).valueOrNull?['avatar_url']
                  as String?;
          return GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: RedesignColors.secundario500,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: RedesignColors.primario800,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        initial,
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario50,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
              ),
            ),
          );
        }),
      ],
    );
  }

}

// ---------------------------------------------------------------------------
// Side drawer (opened from the header avatar)
// ---------------------------------------------------------------------------

class _StudentDrawer extends ConsumerWidget {
  const _StudentDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(myAthleteProfileProvider).valueOrNull;
    final name = user?.displayName ?? 'Atleta';
    final email = user?.email ?? '';
    final avatarUrl = (profile?['avatar_url'] as String?) ?? user?.avatarUrl;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    final reading = ref.watch(trainerRequiredReadingProvider).valueOrNull;
    final hasReading =
        reading != null && (reading.content?.trim().isNotEmpty ?? false);

    return Drawer(
      backgroundColor: RedesignColors.primario900,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: RedesignColors.secundario500,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: RedesignColors.primario800,
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Text(
                              initial,
                              style: const TextStyle(
                                fontFamily: 'Metropolis',
                                color: RedesignColors.primario50,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
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
                          style: const TextStyle(
                            fontFamily: 'Metropolis',
                            color: RedesignColors.primario50,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Metropolis',
                              color: RedesignColors.primario400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 12),

              // Mi perfil
              _DrawerItem(
                icon: Icons.person_outline_rounded,
                label: 'Mi perfil',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentProfileScreen(),
                    ),
                  );
                },
              ),

              // Lectura obligatoria
              _DrawerItem(
                icon: Icons.menu_book_rounded,
                label: 'Lectura obligatoria',
                onTap: () {
                  final content = ref
                      .read(trainerRequiredReadingProvider)
                      .valueOrNull
                      ?.content;
                  Navigator.pop(context);
                  if (hasReading && content != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequiredReadingScreen(content: content),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Tu entrenador no asignó lectura obligatoria.'),
                      ),
                    );
                  }
                },
              ),

              // Configuración
              _DrawerItem(
                icon: Icons.settings_outlined,
                label: 'Configuración',
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuración próximamente')),
                  );
                },
              ),

              const Spacer(),

              // Cerrar sesión
              GestureDetector(
                onTap: () async {
                  // Capture the notifier BEFORE popping the drawer: closing the
                  // drawer disposes this ConsumerWidget, after which `ref` can
                  // no longer be used (throws "Cannot use ref after the widget
                  // was disposed"). The notifier itself is long-lived, so a
                  // captured reference is safe to call once the dialog returns.
                  final authNotifier = ref.read(authProvider.notifier);
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      backgroundColor: RedesignColors.primario800,
                      title: const Text(
                        '¿Cerrar sesión?',
                        style: TextStyle(color: Colors.white),
                      ),
                      content: const Text(
                        '¿Estás seguro de que querés salir?',
                        style: TextStyle(color: Colors.white70),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, false),
                          child: const Text('Cancelar',
                              style: TextStyle(color: Colors.white54)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx, true),
                          child: const Text('Salir',
                              style: TextStyle(color: RedesignColors.peligro300)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await authNotifier.signOut();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: RedesignColors.peligro600.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: RedesignColors.secundario300, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario50,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Seguimiento card (teal-bordered)
// ---------------------------------------------------------------------------

class _SeguimientoCard extends StatelessWidget {
  final CheckInStatus? status;

  const _SeguimientoCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final isFirst = status?.isFirstCheckIn ?? false;
    final dueDate = status?.dueDate;
    final dateLabel = (dueDate != null && !isFirst)
        ? '${dueDate.day} de ${_monthName(dueDate.month)}'
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: RedesignColors.secundario900,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RedesignColors.secundario500,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seguimiento',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario50,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (isFirst) ...[
                  Text(
                    'Completá tu primer check-in',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.primario300,
                      fontSize: 14,
                    ),
                  ),
                ] else ...[
                  Text(
                    'Próximo check-in:',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.primario400,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel ?? 'Pendiente',
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // "Ir a Check-in" pill button
          // PITFALL: ElevatedButton inside a Row needs minimumSize override.
          ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentCheckInScreen(),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: RedesignColors.actionPrimary,
              foregroundColor: RedesignColors.onActionPrimary,
              minimumSize: const Size(0, 54), // override full-width theme default
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontFamily: 'Metropolis',
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Ir a Check-in'),
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) {
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
}

// ---------------------------------------------------------------------------
// Entrenamiento en curso card — shown while a workout is begun but unfinished.
// Tapping resumes that day's session.
// ---------------------------------------------------------------------------

class _EntrenamientoEnCursoCard extends ConsumerWidget {
  final ActiveWorkout active;

  const _EntrenamientoEnCursoCard({required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = active.routineName.trim();
    final subtitle =
        name.isNotEmpty ? '$name - Día ${active.dayNumber}' : 'Día ${active.dayNumber}';

    return GestureDetector(
      onTap: () => openTraining(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        decoration: BoxDecoration(
          color: const Color(0x8031363B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entrenamiento en curso',
                    style: RedesignType.label.copyWith(
                      color: RedesignColors.primario400,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: RedesignColors.secundario500,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: RedesignColors.secundario500,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action — circular icon badge + label (Check-in · Peso · etc.)
// ---------------------------------------------------------------------------

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: RedesignColors.primario700,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: RedesignColors.secundario300,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recetario oficial card
// ---------------------------------------------------------------------------

class _RecetarioCard extends StatelessWidget {
  const _RecetarioCard();

  @override
  Widget build(BuildContext context) {
    // Figma: radius 15, padding 20×30, fill = teal Linear gradient (100%)
    // with the food photo overlaid at 32%, drop shadow.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: double.infinity,
          child: Stack(
          children: [
            // Mint → light-grey gradient
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      RedesignColors.secundario200,
                      RedesignColors.secundario200,
                      Color(0xFFDEDFE4),
                    ],
                    stops: [0.0, 0.35, 0.85],
                  ),
                ),
              ),
            ),
            // Transparent-background bowl with a soft drop shadow
            Positioned(
              right: 8,
              top: 4,
              child: SizedBox(
                width: 124,
                height: 124,
                child: Stack(
                  children: [
                    // Shadow: black silhouette of the bowl, blurred + offset
                    Transform.translate(
                      offset: const Offset(0, 6),
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                        child: Image.asset(
                          'assets/images/recetario.png',
                          width: 124,
                          height: 124,
                          fit: BoxFit.contain,
                          color: Colors.black.withValues(alpha: 0.38),
                          colorBlendMode: BlendMode.srcIn,
                        ),
                      ),
                    ),
                    // The bowl
                    Image.asset(
                      'assets/images/recetario.png',
                      width: 124,
                      height: 124,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ),
            ),
            // Content (constrained to the left so text wraps before the bowl)
            Padding(
              padding: const EdgeInsets.only(left: 20, top: 30, bottom: 30, right: 150),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Recetario oficial',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario900, // Primario/900 #00203F
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '+100 Recetas saludables\na tu disposición',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.secundario900, // Secundario/900 #002820
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.25, // 20/16
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Novedades (news) — horizontal image cards. Content is published from the
// admin / trainer side (news_service); students see global + their trainer's
// articles here (studentNewsProvider).
// ---------------------------------------------------------------------------

class _NovedadesSection extends ConsumerWidget {
  const _NovedadesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(studentNewsProvider);
    return newsAsync.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Text(
                    'Novedades',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: RedesignColors.primario50, size: 26),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _NewsCard(article: list[i]),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;
  const _NewsCard({required this.article});

  String get _date {
    final d = article.createdAt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showArticle(context),
      child: SizedBox(
        width: 185,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
                Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: RedesignColors.primario700),
                )
              else
                const ColoredBox(color: RedesignColors.primario700),
              // Dark gradient for legibility
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)],
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _date,
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.primario200,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      article.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showArticle(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: RedesignColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: RedesignColors.primario600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  article.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 16),
            Text(_date,
                style: const TextStyle(
                    color: RedesignColors.primario300, fontSize: 13)),
            const SizedBox(height: 6),
            Text(article.title,
                style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Text(article.content,
                style: const TextStyle(
                    color: RedesignColors.primario200,
                    fontSize: 15,
                    height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supplement Info Modal (read-only) — preserved verbatim from old screen
// ---------------------------------------------------------------------------

class _SupplementInfoModal extends StatelessWidget {
  final List<Map<String, dynamic>> structured;
  final String daily;
  final String chemical;

  const _SupplementInfoModal({
    required this.structured,
    required this.daily,
    required this.chemical,
  });

  static const _timingLabels = {
    'al_despertar': 'Al despertar',
    'con_comidas': 'Con comidas',
    'post_entreno': 'Post entreno',
    'antes_dormir': 'Antes de dormir',
    'pre_entreno': 'Pre entreno',
  };
  static const _daysLabels = {
    'todos': 'Todos los días',
    'entreno': 'Días de entreno',
    'medio': 'Día por medio',
  };

  @override
  Widget build(BuildContext context) {
    final hasStructured = structured.isNotEmpty;
    final hasDaily = daily.trim().isNotEmpty;
    final hasChemical = chemical.trim().isNotEmpty;

    final diaria = structured
        .where((s) => (s['category'] as String? ?? 'diaria') != 'quimica')
        .toList();
    final quimica =
        structured.where((s) => s['category'] == 'quimica').toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Row(
                  children: [
                    const Icon(
                      Icons.medication_outlined,
                      color: RedesignColors.actionPrimary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Suplementación',
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: RedesignColors.primario50,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: RedesignColors.primario400,
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: RedesignColors.primario600),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasStructured) ...[
                    if (diaria.isNotEmpty)
                      _group(
                        title: 'Diaria',
                        icon: Icons.autorenew_rounded,
                        items: diaria,
                        bg: RedesignColors.secundario300,
                      ),
                    if (diaria.isNotEmpty && quimica.isNotEmpty)
                      const SizedBox(height: 18),
                    if (quimica.isNotEmpty)
                      _group(
                        title: 'Química',
                        icon: Icons.science_outlined,
                        items: quimica,
                        bg: RedesignColors.secundario200,
                      ),
                  ] else ...[
                    if (hasDaily)
                      _section(
                        icon: Icons.autorenew_rounded,
                        title: 'Diario',
                        body: daily.trim(),
                        color: RedesignColors.secundario300, // #81E1CA
                      ),
                    if (hasDaily && hasChemical) const SizedBox(height: 18),
                    if (hasChemical)
                      _section(
                        icon: Icons.science_outlined,
                        title: 'Química',
                        body: chemical.trim(),
                      ),
                  ],
                  if (!hasStructured && !hasDaily && !hasChemical)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          'Tu entrenador aún no asignó suplementos.',
                          style: TextStyle(
                            color: RedesignColors.primario400,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Structured supplement group (one coloured card per category, listing items).
  Widget _group({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required Color bg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RedesignColors.primario900, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario900,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  height: 1,
                  color: RedesignColors.primario900.withValues(alpha: 0.12),
                ),
              ),
            _suppItem(items[i]),
          ],
        ],
      ),
    );
  }

  Widget _suppItem(Map<String, dynamic> s) {
    final name = (s['name'] as String? ?? '').trim();
    final dose = (s['dose'] as String? ?? '').trim();
    final unit = (s['unit'] as String? ?? '').trim();
    final daysKey = s['days'] as String? ?? 'todos';
    final note = (s['note'] as String? ?? '').trim();
    final timing = (s['timing'] as List?)
            ?.map((e) => _timingLabels[e] ?? e.toString())
            .join(', ') ??
        '';
    final doseStr = [dose, unit].where((e) => e.isNotEmpty).join(' ');
    final meta = <String>[
      if (_daysLabels[daysKey] != null) _daysLabels[daysKey]!,
      if (timing.isNotEmpty) timing,
    ].join(' · ');

    const dark = RedesignColors.primario900;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: dark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (doseStr.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(
                doseStr,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: dark.withValues(alpha: 0.85),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            meta,
            style: TextStyle(
              fontFamily: 'Metropolis',
              color: dark.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            note,
            style: TextStyle(
              fontFamily: 'Metropolis',
              color: dark.withValues(alpha: 0.75),
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String body,
    Color color = RedesignColors.secundario200,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: RedesignColors.primario900, size: 22),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario900,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            body,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario900,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
