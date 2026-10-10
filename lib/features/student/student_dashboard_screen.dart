import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import '../../services/notification_providers.dart';
import '../../services/news_service.dart';
import '../../models/news_model.dart';
import '../shared/notifications_sheet.dart';
import 'student_meal_plan_screen.dart';
import 'student_weight_screen.dart';
import 'student_check_in_screen.dart';
import 'student_routine_screen.dart';
import 'student_recipes_screen.dart';
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
          body: const _HomeContent(),
          bottomNavigationBar: StudentBottomNav(
            active: StudentNavTab.inicio,
            onInicioTap: () {},
            onEntrenarTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StudentRoutineScreen(),
                fullscreenDialog: true,
              ),
            ),
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

                  const SizedBox(height: 32),

                  // Three action pill rows
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _hPad),
                    child: Column(
                      children: [
                        _ActionRow(
                          icon: Icons.camera_alt_rounded,
                          label: 'CHECK-IN',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentCheckInScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ActionRow(
                          icon: Icons.monitor_weight_rounded,
                          label: 'REGISTRAR PESO',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentWeightScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer(
                          builder: (context, ref, _) {
                            return _ActionRow(
                              icon: Icons.medication_outlined,
                              label: 'SUPLEMENTOS',
                              onTap: () async {
                                final s =
                                    await ref.read(mySupplementsProvider.future);
                                if (!context.mounted) return;
                                _showSupplementInfo(
                                  context,
                                  s['daily'] ?? '',
                                  s['chemical'] ?? '',
                                );
                              },
                            );
                          },
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

  void _showSupplementInfo(BuildContext context, String daily, String chemical) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _SupplementInfoModal(daily: daily, chemical: chemical),
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

        // Circular avatar with teal ring
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
            radius: 18,
            backgroundColor: RedesignColors.primario800,
            child: Text(
              initial,
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario50,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
// Action pill rows
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        // Figma "Tarjetas": padding 20×15 (hug → ~74.8 tall), radius 40,
        // fill #31363B @ 50%, drop shadow.
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 19),
        decoration: BoxDecoration(
          color: const Color(0x8031363B),
          borderRadius: BorderRadius.circular(40),
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
            // Circular icon badge
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: RedesignColors.secundario600,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: RedesignColors.primario50,
                size: 25,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario50,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: RedesignColors.primario400,
              size: 24,
            ),
          ],
        ),
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
  final String daily;
  final String chemical;

  const _SupplementInfoModal({
    required this.daily,
    required this.chemical,
  });

  @override
  Widget build(BuildContext context) {
    final hasDaily = daily.trim().isNotEmpty;
    final hasChemical = chemical.trim().isNotEmpty;

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
                  if (!hasDaily && !hasChemical)
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
