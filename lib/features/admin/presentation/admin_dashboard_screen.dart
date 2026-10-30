import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../widgets/admin_bottom_nav.dart';
import '../widgets/admin_common.dart';
import 'admin_home_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_trainers_screen.dart';

/// PRGS admin shell — 4-tab information architecture (Inicio · Entrenadores ·
/// Suscripciones · Contenido). Profile is reached from the Inicio header avatar.
/// Mirrors the trainer shell: internal PageController nav, no nested routes.
class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;
  late final PageController _pageController =
      PageController(initialPage: _currentIndex);

  static const _tabs = [
    AdminNavTab.inicio,
    AdminNavTab.entrenadores,
    AdminNavTab.suscripciones,
    AdminNavTab.contenido,
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
          children: [
            AdminHomeView(
              onOpenEntrenadores: () => _goTo(1),
              onOpenSuscripciones: () => _goTo(2),
            ),
            const AdminTrainersView(),
            const AdminSubscriptionsView(),
            const _ComingSoonView(title: 'Contenido'),
          ],
        ),
        bottomNavigationBar: AdminBottomNav(
          active: _tabs[_currentIndex],
          onInicioTap: () => _goTo(0),
          onEntrenadoresTap: () => _goTo(1),
          onSuscripcionesTap: () => _goTo(2),
          onContenidoTap: () => _goTo(3),
        ),
      ),
    );
  }
}

/// Temporary placeholder for tabs delivered in later batches.
class _ComingSoonView extends StatelessWidget {
  final String title;
  const _ComingSoonView({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminGradientHeader(title: title),
        const Expanded(
          child: Center(
            child: Text(
              'Próximamente',
              style: TextStyle(color: RedesignColors.primario300),
            ),
          ),
        ),
      ],
    );
  }
}
