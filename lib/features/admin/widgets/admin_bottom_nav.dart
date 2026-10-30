import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../core/theme/theme_redesign.dart';

/// Active tab for the PRGS admin bottom nav.
enum AdminNavTab { inicio, entrenadores, suscripciones, contenido }

/// PRGS admin bottom nav: full-bleed, top-rounded, frosted teal glass bar with
/// four flat tabs (no centre FAB). Mirrors [TrainerBottomNav]. Use with
/// `extendBody: true`.
class AdminBottomNav extends StatelessWidget {
  final AdminNavTab active;
  final VoidCallback? onInicioTap;
  final VoidCallback? onEntrenadoresTap;
  final VoidCallback? onSuscripcionesTap;
  final VoidCallback? onContenidoTap;

  const AdminBottomNav({
    super.key,
    required this.active,
    this.onInicioTap,
    this.onEntrenadoresTap,
    this.onSuscripcionesTap,
    this.onContenidoTap,
  });

  static const double _barHeight = 88;
  static const double _topRadius = 32;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(_topRadius)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: _barHeight + safe,
          padding: EdgeInsets.only(bottom: safe),
          decoration: BoxDecoration(
            color: RedesignColors.navbarBackground, // #01B69A @25%
            border: Border(
              top: BorderSide(
                color: RedesignColors.secundario300.withValues(alpha: 0.30),
                width: 1,
              ),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_rounded,
                  label: 'Inicio',
                  isActive: active == AdminNavTab.inicio,
                  onTap: onInicioTap,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.groups_rounded,
                  label: 'Entrenadores',
                  isActive: active == AdminNavTab.entrenadores,
                  onTap: onEntrenadoresTap,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Suscripciones',
                  isActive: active == AdminNavTab.suscripciones,
                  onTap: onSuscripcionesTap,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.menu_book_rounded,
                  label: 'Contenido',
                  isActive: active == AdminNavTab.contenido,
                  onTap: onContenidoTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? RedesignColors.primario50 : RedesignColors.primario300;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Metropolis',
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
