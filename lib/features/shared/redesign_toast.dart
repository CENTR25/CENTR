import 'package:flutter/material.dart';
import '../../core/theme/theme_redesign.dart';

/// PRGS redesign success toast (Figma "Enlace copiado" / "¡Notificación enviada!").
///
/// A centred navy card with a green check badge, bold title and muted subtitle,
/// shown as a transient overlay that fades in/out and auto-dismisses.
void showRedesignToast(
  BuildContext context, {
  required String title,
  String? subtitle,
  IconData icon = Icons.check_rounded,
  Duration duration = const Duration(milliseconds: 1700),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _ToastCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      duration: duration,
      onDismissed: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _ToastCard extends StatefulWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _ctrl.reverse();
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(_fade),
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: RedesignColors.primario900, // deep navy card
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 30,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: RedesignColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon,
                        color: RedesignColors.primario50, size: 30),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: RedesignType.bodyMd.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.primario300,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
