import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../../services/auth_service.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_broadcast_sheet.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_invite_trainer_sheet.dart';
import 'admin_profile_screen.dart';

/// Admin Inicio — "Panel PRGS": header metrics, Invitar/Notificar actions and
/// the Pendientes list. `onOpenEntrenadores` / `onOpenSuscripciones` switch the
/// shell's bottom-nav tab.
class AdminHomeView extends ConsumerWidget {
  final VoidCallback onOpenEntrenadores;
  final VoidCallback onOpenSuscripciones;

  const AdminHomeView({
    super.key,
    required this.onOpenEntrenadores,
    required this.onOpenSuscripciones,
  });

  void _openInvite(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminInviteTrainerSheet(),
    );
  }

  void _openNotify(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminBroadcastSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final metricsAsync = ref.watch(adminDashboardMetricsProvider);
    final metrics = metricsAsync.valueOrNull;

    return RefreshIndicator(
      color: RedesignColors.actionPrimary,
      backgroundColor: RedesignColors.primario800,
      onRefresh: () async {
        ref.invalidate(adminDashboardMetricsProvider);
        ref.invalidate(adminPendientesProvider);
        await ref.read(adminPendientesProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminGradientHeader(
              greeting: '¡Hola admin!',
              title: 'Panel PRGS',
              trailing: AdminHeaderAvatar(
                name: user?.name ?? user?.email,
                avatarUrl: user?.avatarUrl,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminProfileScreen(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetricsCard(metrics: metrics),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openInvite(context),
                          icon: const Icon(Icons.person_add_alt_1_rounded,
                              size: 18),
                          label: const Text('Invitar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openNotify(context),
                          icon: const Icon(
                              Icons.notifications_none_rounded,
                              size: 18),
                          label: const Text('Notificar'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const AdminSectionLabel('Pendientes'),
                  const SizedBox(height: 12),
                  _PendientesList(
                    onOpenEntrenadores: onOpenEntrenadores,
                    onOpenSuscripciones: onOpenSuscripciones,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final Map<String, dynamic>? metrics;

  const _MetricsCard({required this.metrics});

  num _num(String key) => (metrics?[key] as num?) ?? 0;

  @override
  Widget build(BuildContext context) {
    final loading = metrics == null;
    return AdminCard(
      radius: 28,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  label: 'Ingresos / mes',
                  value: loading
                      ? '–'
                      : adminFormatCurrency(_num('ingresos_mes')),
                  highlight: true,
                ),
              ),
              _vDivider(),
              Expanded(
                child: _metric(
                  label: 'Suscripciones activas',
                  value: loading ? '–' : '${_num('suscripciones_activas')}',
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: RedesignColors.primario600),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  label: 'Entrenadores',
                  value: loading ? '–' : '${_num('total_trainers')}',
                ),
              ),
              _vDivider(),
              Expanded(
                child: _metric(
                  label: 'Alumnos',
                  value: loading ? '–' : '${_num('total_alumnos')}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        color: RedesignColors.primario50.withValues(alpha: 0.08),
      );

  Widget _metric({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: RedesignType.headingMd.copyWith(
            color: highlight
                ? RedesignColors.secundario300
                : RedesignColors.primario50,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PendientesList extends ConsumerWidget {
  final VoidCallback onOpenEntrenadores;
  final VoidCallback onOpenSuscripciones;

  const _PendientesList({
    required this.onOpenEntrenadores,
    required this.onOpenSuscripciones,
  });

  Future<void> _resendAll(
    BuildContext context,
    WidgetRef ref,
    List<Map<String, dynamic>> invites,
  ) async {
    final admin = ref.read(adminServiceProvider);
    try {
      for (final i in invites) {
        await admin.resendInvitation(i['user_id'] as String);
      }
      if (!context.mounted) return;
      ref.invalidate(adminPendientesProvider);
      showRedesignToast(
        context,
        title: 'Invitaciones reenviadas',
        subtitle: 'Se generaron nuevos enlaces de invitación.',
      );
    } catch (e) {
      if (!context.mounted) return;
      showRedesignToast(
        context,
        title: 'No se pudo reenviar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendientesAsync = ref.watch(adminPendientesProvider);

    return pendientesAsync.when(
      loading: () => const _PendienteSkeleton(),
      error: (e, _) => Text(
        'No se pudieron cargar los pendientes',
        style: RedesignType.label.copyWith(color: RedesignColors.primario400),
      ),
      data: (p) {
        final rows = <Widget>[];

        if (p.withoutSubscription.isNotEmpty) {
          final n = p.withoutSubscription.length;
          rows.add(_PendienteRow(
            icon: Icons.workspace_premium_outlined,
            iconColor: RedesignColors.warning,
            title:
                '$n entrenador${n == 1 ? '' : 'es'} sin suscripción',
            subtitle: 'No pueden sumar alumnos',
            actionLabel: 'Asignar',
            onAction: onOpenEntrenadores,
          ));
        }

        for (final s in p.expiring) {
          final trainerName =
              (s['trainers'] as Map<String, dynamic>?)?['name'] as String? ??
                  'Entrenador';
          final planName =
              (s['subscription_plans'] as Map<String, dynamic>?)?['name']
                      as String? ??
                  'Plan';
          final days = _daysUntil(s['ends_at'] as String?);
          rows.add(_PendienteRow(
            icon: Icons.schedule_rounded,
            iconColor: RedesignColors.warning,
            title: 'Suscripción vence en $days día${days == 1 ? '' : 's'}',
            subtitle: '$trainerName ($planName)',
            actionLabel: 'Ver',
            onAction: onOpenSuscripciones,
          ));
        }

        if (p.invitations.isNotEmpty) {
          final n = p.invitations.length;
          rows.add(_PendienteRow(
            icon: Icons.mail_outline_rounded,
            iconColor: RedesignColors.actionPrimaryDark,
            title: '$n invitaci${n == 1 ? 'ón' : 'ones'} sin aceptar',
            subtitle: 'Reenviá el enlace de invitación',
            actionLabel: 'Reenviar',
            onAction: () => _resendAll(context, ref, p.invitations),
          ));
        }

        if (rows.isEmpty) {
          return AdminCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: RedesignColors.success, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Todo al día — no hay pendientes.',
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i != rows.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  int _daysUntil(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return 0;
    final now = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return diff < 0 ? 0 : diff;
  }
}

class _PendienteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onAction;

  const _PendienteRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: RedesignType.label
                      .copyWith(color: RedesignColors.primario300),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: RedesignColors.actionPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionLabel,
                style: RedesignType.buttonSm.copyWith(
                  color: RedesignColors.onActionPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendienteSkeleton extends StatelessWidget {
  const _PendienteSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 68,
          decoration: BoxDecoration(
            color: RedesignColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }
}
