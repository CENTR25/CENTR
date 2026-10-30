import 'package:flutter/material.dart';
import '../../../core/theme/theme_redesign.dart';

/// Gradient header used at the top of every admin tab (navy fade), with a large
/// title and an optional trailing widget (icon button or avatar).
class AdminGradientHeader extends StatelessWidget {
  final String title;
  final String? greeting;
  final Widget? trailing;
  final List<Widget> actions;

  const AdminGradientHeader({
    super.key,
    required this.title,
    this.greeting,
    this.trailing,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top.clamp(24.0, 100.0);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x6600203F), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(22, safeTop + 14, 22, 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (greeting != null) ...[
                  Text(
                    greeting!,
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario300),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  title,
                  style: RedesignType.headingMd.copyWith(
                    color: RedesignColors.primario50,
                    fontSize: 28,
                  ),
                ),
              ],
            ),
          ),
          for (final a in actions) ...[a, const SizedBox(width: 12)],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Circular avatar with a teal ring, used in the admin header. Tapping opens
/// the profile screen.
class AdminHeaderAvatar extends StatelessWidget {
  final String? name;
  final String? avatarUrl;
  final VoidCallback onTap;

  const AdminHeaderAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()[0].toUpperCase()
        : 'A';
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

/// Round icon button in the header (matches the trainer bell/message buttons).
class AdminHeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const AdminHeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

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
        child: Icon(
          icon,
          color: iconColor ?? RedesignColors.primario50,
          size: 22,
        ),
      ),
    );
  }
}

/// Pill filter chip (exercise-library style): selected = teal border + teal
/// text, unselected = dark gray fill.
class AdminFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const AdminFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.transparent : RedesignColors.primario700,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? RedesignColors.actionPrimaryDark
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: RedesignType.buttonSm.copyWith(
            color: active
                ? RedesignColors.actionPrimaryDark
                : RedesignColors.primario50,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// Segmented pill tab bar (Contenido Noticias/Marcas/Ejercicios, etc.).
class AdminSegmentedPills extends StatelessWidget {
  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  const AdminSegmentedPills({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == activeIndex
                        ? RedesignColors.actionPrimary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: RedesignType.buttonSm.copyWith(
                      color: i == activeIndex
                          ? RedesignColors.onActionPrimary
                          : RedesignColors.primario50,
                      fontWeight: i == activeIndex
                          ? FontWeight.w700
                          : FontWeight.w500,
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

/// Small status badge (Activa / Borrador / Oculta / Publicada / Visible).
class AdminStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const AdminStatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: RedesignType.label.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Surface card (rounded, translucent navy fill) used for list rows & panels.
class AdminCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;

  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.14),
        ),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// Section label ("Pendientes", "Cuenta", …).
class AdminSectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const AdminSectionLabel(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Pill "+ Crear" button in the header (teal fill).
class AdminAddPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AdminAddPillButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: RedesignColors.actionPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded,
                color: RedesignColors.onActionPrimary, size: 18),
            const SizedBox(width: 4),
            Text(
              label,
              style: RedesignType.buttonSm.copyWith(
                color: RedesignColors.onActionPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared currency formatter for the admin screens: "$200.000" (es-AR style,
/// thousands with a dot, no decimals).
String adminFormatCurrency(num value) {
  final intPart = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  return '\$$buf';
}

/// Normalise a subscription plan's `features` jsonb (List or Map) into a flat
/// list of human labels.
List<String> adminFeatureLabels(dynamic features) {
  if (features == null) return const [];
  if (features is List) {
    return features.map((e) => e.toString()).toList();
  }
  if (features is Map) {
    return features.entries
        .where((e) => e.value == true || e.value == null)
        .map((e) => e.key.toString())
        .toList();
  }
  return const [];
}

/// Short date "dd/mm" from an ISO timestamp (local).
String adminShortDate(String? iso) {
  if (iso == null) return '—';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
