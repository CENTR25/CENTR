import 'dart:async';

import 'package:flutter/material.dart';

import '../core/pwa/install_prompt_bridge.dart';
import '../core/theme/theme_redesign.dart';

/// "Agregar a Inicio" pop-up (web only; renders nothing on android/ios builds).
///
/// - Android/Chrome: "Instalar app" button -> native `beforeinstallprompt`.
/// - iOS Safari: manual hint (Compartir -> Agregar a Inicio).
/// - Hidden when already running standalone or after the user dismissed it.
class InstallAppPrompt extends StatefulWidget {
  const InstallAppPrompt({super.key});

  @override
  State<InstallAppPrompt> createState() => _InstallAppPromptState();
}

class _InstallAppPromptState extends State<InstallAppPrompt> {
  final _bridge = InstallPromptBridge();
  Timer? _iosTimer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (!_bridge.isSupported || _bridge.isStandalone || _bridge.wasDismissed) {
      return;
    }
    _bridge.listen(_refresh);
    _refresh();
    if (_bridge.isIosSafari) {
      // No install event on iOS: show the manual hint after a beat.
      _iosTimer = Timer(const Duration(milliseconds: 1500), _refresh);
    }
  }

  void _refresh() {
    if (!mounted) return;
    final next = !_bridge.isStandalone &&
        !_bridge.wasDismissed &&
        (_bridge.canPromptNative || _bridge.isIosSafari);
    if (next != _show) setState(() => _show = next);
  }

  void _dismiss() {
    _bridge.rememberDismissed();
    setState(() => _show = false);
  }

  Future<void> _install() async {
    await _bridge.promptNative();
    _refresh();
  }

  @override
  void dispose() {
    _iosTimer?.cancel();
    _bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    final canNative = _bridge.canPromptNative;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          // Lifted above the floating bottom-nav pill.
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 92),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Material(
                color: RedesignColors.primario800,
                elevation: 12,
                shadowColor: Colors.black54,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: RedesignColors.secundario300.withValues(alpha: 0.25),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(13),
                                child: Image.network(
                                  'icons/Icon-192.png',
                                  width: 48,
                                  height: 48,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox(width: 48, height: 48),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 22),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Instala PRGS',
                                        style: RedesignType.bodySm.copyWith(
                                          color: RedesignColors.primario50,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Agrégala a tu pantalla de inicio para abrirla como app, a pantalla completa.',
                                        style: RedesignType.label.copyWith(
                                          color: RedesignColors.primario300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (canNative)
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _install,
                                style: FilledButton.styleFrom(
                                  backgroundColor: RedesignColors.actionPrimary,
                                  foregroundColor: RedesignColors.onActionPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text('Instalar app',
                                    style: RedesignType.buttonSm),
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: RedesignColors.primario700,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text('Toca',
                                      style: RedesignType.label.copyWith(
                                          color: RedesignColors.primario200)),
                                  const Icon(Icons.ios_share_rounded,
                                      size: 18,
                                      color: RedesignColors.secundario300),
                                  Text('Compartir',
                                      style: RedesignType.label.copyWith(
                                          color: RedesignColors.primario200)),
                                  Text('y luego',
                                      style: RedesignType.label.copyWith(
                                          color: RedesignColors.primario200)),
                                  Text('«Agregar a Inicio»',
                                      style: RedesignType.label.copyWith(
                                        color: RedesignColors.primario50,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ],
                              ),
                            ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _dismiss,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: RedesignColors.primario700,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded,
                                size: 15, color: RedesignColors.primario300),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
