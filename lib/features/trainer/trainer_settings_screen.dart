import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/auth_service.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';
import 'change_password_screen.dart';

// ---------------------------------------------------------------------------
// TrainerSettingsScreen (Figma "Configuración")
//
// Cuenta section (Datos personales / Email / Cambiar contraseña) + a
// Notificaciones section of toggles backed by trainer_notification_prefs.
// ---------------------------------------------------------------------------

class TrainerSettingsScreen extends ConsumerStatefulWidget {
  const TrainerSettingsScreen({super.key});

  @override
  ConsumerState<TrainerSettingsScreen> createState() =>
      _TrainerSettingsScreenState();
}

class _TrainerSettingsScreenState extends ConsumerState<TrainerSettingsScreen> {
  Map<String, bool> _prefs = Map.of(TrainerService.defaultNotificationPrefs);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await ref.read(trainerServiceProvider).getNotificationPrefs();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _loading = false;
    });
  }

  Future<void> _toggle(String key, bool value) async {
    final previous = _prefs[key] ?? false;
    setState(() => _prefs = {..._prefs, key: value});
    try {
      await ref.read(trainerServiceProvider).updateNotificationPref(key, value);
    } catch (_) {
      if (!mounted) return;
      // Revert on failure.
      setState(() => _prefs = {..._prefs, key: previous});
      showRedesignToast(
        context,
        title: 'No se pudo guardar',
        subtitle: 'Revisá tu conexión e intentá de nuevo.',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final email = user?.email ?? '';

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Configuración',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            _SectionLabel('Cuenta'),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  _NavRow(
                    title: 'Datos personales',
                    onTap: () => _stub(context),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    title: 'Email',
                    trailingText: email,
                    onTap: () => _stub(context),
                  ),
                  const _RowDivider(),
                  _NavRow(
                    title: 'Cambiar contraseña',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('Notificaciones'),
            const SizedBox(height: 10),
            _Card(
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: RedesignColors.actionPrimary,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _ToggleRow(
                          title: 'Alumno completó entrenamiento',
                          value: _prefs['workout_completed'] ?? false,
                          onChanged: (v) => _toggle('workout_completed', v),
                        ),
                        const _RowDivider(),
                        _ToggleRow(
                          title: 'Alumnos inactivo +7 días',
                          value: _prefs['inactive_7d'] ?? false,
                          onChanged: (v) => _toggle('inactive_7d', v),
                        ),
                        const _RowDivider(),
                        _ToggleRow(
                          title: 'Mensaje de alumnos',
                          value: _prefs['student_message'] ?? false,
                          onChanged: (v) => _toggle('student_message', v),
                        ),
                        const _RowDivider(),
                        _ToggleRow(
                          title: 'Novedades PRGS',
                          value: _prefs['prgs_news'] ?? false,
                          onChanged: (v) => _toggle('prgs_news', v),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _stub(BuildContext context) {
    showRedesignToast(
      context,
      title: 'Próximamente',
      subtitle: 'Esta función estará disponible pronto.',
      icon: Icons.access_time_rounded,
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: RedesignType.bodySm.copyWith(
        color: RedesignColors.primario50,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: RedesignColors.primario600);
}

class _NavRow extends StatelessWidget {
  final String title;
  final String? trailingText;
  final VoidCallback onTap;

  const _NavRow({
    required this.title,
    this.trailingText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailingText != null && trailingText!.isNotEmpty) ...[
              Flexible(
                child: Text(
                  trailingText!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario400),
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: RedesignColors.primario50,
            activeTrackColor: RedesignColors.actionPrimary,
            inactiveThumbColor: RedesignColors.primario400,
            inactiveTrackColor: RedesignColors.primario600,
          ),
        ],
      ),
    );
  }
}
