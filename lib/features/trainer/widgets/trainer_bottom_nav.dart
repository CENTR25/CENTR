import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../../../core/theme/theme_redesign.dart';

/// Active tab for the PRGS trainer bottom nav.
enum TrainerNavTab { inicio, alumnos, planes }

/// PRGS trainer bottom nav (Figma "Navbar entrenador"): full-bleed, top-rounded,
/// frosted teal glass bar with a raised glowing "Alumnos" FAB in the centre.
/// Mirrors [StudentBottomNav]. Use with `extendBody: true`.
class TrainerBottomNav extends StatelessWidget {
  final TrainerNavTab active;
  final VoidCallback? onInicioTap;
  final VoidCallback? onAlumnosTap;
  final VoidCallback? onPlanesTap;

  const TrainerBottomNav({
    super.key,
    required this.active,
    this.onInicioTap,
    this.onAlumnosTap,
    this.onPlanesTap,
  });

  static const double _barHeight = 88;
  static const double _fabRaise = 22;
  static const double _fabSize = 62;
  static const double _topRadius = 32;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding.bottom;

    return SizedBox(
      height: _barHeight + _fabRaise + safe,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Bar (full-bleed, top-rounded, frosted teal glass) ──────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(_topRadius)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(_topRadius)),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    height: _barHeight + safe,
                    padding: EdgeInsets.only(bottom: safe),
                    decoration: BoxDecoration(
                      color: RedesignColors.navbarBackground, // #01B69A @25%
                      border: Border(
                        top: BorderSide(
                          color: RedesignColors.secundario300
                              .withValues(alpha: 0.30),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.home_rounded,
                            label: 'Inicio',
                            isActive: active == TrainerNavTab.inicio,
                            onTap: onInicioTap,
                          ),
                        ),
                        // Centre slot — FAB floats above, label sits under it.
                        Expanded(
                          child: _NavItem(
                            icon: null,
                            label: 'Alumnos',
                            isActive: active == TrainerNavTab.alumnos,
                            onTap: onAlumnosTap,
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.menu_book_rounded,
                            label: 'Planes',
                            isActive: active == TrainerNavTab.planes,
                            onTap: onPlanesTap,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Raised Alumnos FAB ─────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onAlumnosTap,
                child: Container(
                  width: _fabSize,
                  height: _fabSize,
                  decoration: BoxDecoration(
                    color: RedesignColors.actionPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: RedesignColors.actionPrimary
                            .withValues(alpha: 0.55),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: RedesignColors.onActionPrimary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData? icon;
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
          // Reserve the icon slot so the centre label lines up with the sides.
          SizedBox(
            height: 24,
            child: icon == null ? null : Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Metropolis',
              color: color,
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
