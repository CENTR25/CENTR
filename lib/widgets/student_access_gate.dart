import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/theme_redesign.dart';
import '../services/access_status_service.dart';
import '../services/auth_service.dart';

/// Wraps the whole app. When the signed-in student is blocked (manual block or
/// automatic cutoff) every route is replaced by [_SuspendedScreen]. Re-checks
/// on app resume so unblocking / paying takes effect without a restart.
class StudentAccessGate extends ConsumerStatefulWidget {
  final Widget child;
  const StudentAccessGate({super.key, required this.child});

  @override
  ConsumerState<StudentAccessGate> createState() => _StudentAccessGateState();
}

class _StudentAccessGateState extends ConsumerState<StudentAccessGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accessStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(accessStatusProvider).valueOrNull;
    if (status != null && status.blocked) {
      return _SuspendedScreen(status: status);
    }
    return widget.child;
  }
}

class _SuspendedScreen extends ConsumerWidget {
  final AccessStatus status;
  const _SuspendedScreen({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainer = status.trainerName;
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.primario900,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded,
                        size: 56, color: RedesignColors.secundario300),
                    const SizedBox(height: 20),
                    Text(
                      'Acceso suspendido',
                      textAlign: TextAlign.center,
                      style: RedesignType.headingMd
                          .copyWith(color: RedesignColors.primario50),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      [
                        if (status.reason?.trim().isNotEmpty ?? false)
                          status.reason!.trim(),
                        'Hablá con ${trainer ?? 'tu entrenador'} para '
                            'regularizar tu cuota y volver a entrar. '
                            'Tus datos y tu progreso están guardados.',
                      ].join('\n\n'),
                      textAlign: TextAlign.center,
                      style: RedesignType.bodySm
                          .copyWith(color: RedesignColors.primario200),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => ref.invalidate(accessStatusProvider),
                        child: const Text('Ya pagué, actualizar'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(authProvider.notifier).signOut(),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
