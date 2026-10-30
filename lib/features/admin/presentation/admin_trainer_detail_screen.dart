import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../../services/supabase_service.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_assign_subscription_sheet.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_redesign_sheet.dart';

/// Admin trainer detail (Figma First Batch): identity, subscription status with
/// "Asignar suscripción", Alumnos/Registro stats, phone, send-notification and
/// delete.
class AdminTrainerDetailScreen extends ConsumerWidget {
  final String trainerId;

  const AdminTrainerDetailScreen({super.key, required this.trainerId});

  void _openAssign(BuildContext context, String name) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminAssignSubscriptionSheet(
        trainerId: trainerId,
        trainerName: name,
      ),
    );
  }

  void _openEdit(BuildContext context, Map<String, dynamic> trainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditTrainerSheet(trainer: trainer),
    );
  }

  void _openNotify(BuildContext context, Map<String, dynamic> trainer) {
    final profileId = trainer['user_id'] as String?;
    if (profileId == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotifyTrainerSheet(
        profileId: profileId,
        trainerName: (trainer['name'] ?? 'Entrenador').toString(),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Eliminar entrenador',
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            '¿Seguro que querés eliminar a $name? Esta acción no se puede deshacer.',
            style:
                RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.primario50),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Eliminar',
                style: RedesignType.buttonSm
                    .copyWith(color: RedesignColors.danger),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(adminServiceProvider).deleteTrainer(trainerId);
      ref.invalidate(adminTrainersProvider);
      ref.invalidate(adminPendientesProvider);
      ref.invalidate(adminDashboardMetricsProvider);
      if (!context.mounted) return;
      Navigator.pop(context);
      showRedesignToast(
        context,
        title: 'Entrenador eliminado',
        subtitle: '$name fue eliminado.',
      );
    } catch (e) {
      if (!context.mounted) return;
      final msg = e.toString().contains('students')
          ? 'No se puede eliminar un entrenador con alumnos activos.'
          : '$e';
      showRedesignToast(
        context,
        title: 'No se pudo eliminar',
        subtitle: msg,
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(adminTrainerDetailProvider(trainerId));

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
          actions: [
            detailAsync.maybeWhen(
              data: (t) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => _openEdit(context, t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: RedesignColors.primario700,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: RedesignColors.secundario300
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_outlined,
                            color: RedesignColors.primario50, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'Editar',
                          style: RedesignType.buttonSm.copyWith(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        body: detailAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Error: $e',
              style: const TextStyle(color: RedesignColors.danger),
            ),
          ),
          data: (t) => _body(context, ref, t),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> t,
  ) {
    final name = (t['name'] ?? 'Entrenador').toString();
    final profile = t['profiles'] as Map<String, dynamic>?;
    final email = (profile?['email'] ?? '').toString();
    final photo = t['profile_photo'] as String?;
    final phone = (t['phone'] as String?)?.trim();
    final alumnos = t['alumnos_count'] as int? ?? 0;
    final registro = adminShortDate(t['created_at'] as String?);
    final sub = t['subscription'] as Map<String, dynamic>?;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'E';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: RedesignColors.primario700,
              backgroundImage: (photo != null && photo.isNotEmpty)
                  ? NetworkImage(photo)
                  : null,
              child: (photo == null || photo.isEmpty)
                  ? Text(
                      initial,
                      style: const TextStyle(
                        color: RedesignColors.primario50,
                        fontWeight: FontWeight.w700,
                        fontSize: 26,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _subscriptionCard(context, name, sub),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statCard('Alumnos', '$alumnos')),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Registro', registro)),
          ],
        ),
        const SizedBox(height: 16),
        AdminCard(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _infoRow(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                value: (phone != null && phone.isNotEmpty)
                    ? phone
                    : 'No registrado',
              ),
              const Divider(height: 1, color: RedesignColors.primario600),
              InkWell(
                onTap: () => _openNotify(context, t),
                child: _infoRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Enviar notificación',
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: RedesignColors.primario400, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => _confirmDelete(context, ref, name),
            child: Text(
              'Eliminar entrenador',
              style: RedesignType.buttonLg.copyWith(
                color: RedesignColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _subscriptionCard(
    BuildContext context,
    String name,
    Map<String, dynamic>? sub,
  ) {
    if (sub == null) {
      return AdminCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminStatusPill(
                label: '⚠ Suscripción', color: RedesignColors.warning),
            const SizedBox(height: 12),
            Text(
              'Sin suscripción activa',
              style: RedesignType.bodyMd.copyWith(
                color: RedesignColors.primario50,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No puede sumar alumnos hasta tener un plan.',
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _openAssign(context, name),
                child: const Text('Asignar suscripción'),
              ),
            ),
          ],
        ),
      );
    }

    final plan = sub['subscription_plans'] as Map<String, dynamic>?;
    final planName = plan?['name'] as String? ?? 'Plan';
    final renueva = adminShortDate(sub['ends_at'] as String?);
    return AdminCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminStatusPill(label: 'Suscripción', color: RedesignColors.success),
          const SizedBox(height: 12),
          Text(
            planName,
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Renueva el $renueva',
            style:
                RedesignType.label.copyWith(color: RedesignColors.primario300),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _openAssign(context, name),
              child: const Text('Cambiar plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return AdminCard(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                RedesignType.label.copyWith(color: RedesignColors.primario300),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: RedesignType.headingMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    String? value,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, color: RedesignColors.primario300, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (value != null)
            Text(
              value,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario400),
            ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}

// ── Edit trainer sheet (name + specialty) ────────────────────────────────
class _EditTrainerSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> trainer;
  const _EditTrainerSheet({required this.trainer});

  @override
  ConsumerState<_EditTrainerSheet> createState() => _EditTrainerSheetState();
}

class _EditTrainerSheetState extends ConsumerState<_EditTrainerSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _specialtyCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.trainer['name'] ?? '');
    _specialtyCtrl =
        TextEditingController(text: widget.trainer['specialty'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final id = widget.trainer['id'] as String;
      await ref.read(adminServiceProvider).updateTrainer(
            id,
            name: _nameCtrl.text.trim(),
            specialty: _specialtyCtrl.text.trim().isEmpty
                ? null
                : _specialtyCtrl.text.trim(),
          );
      ref.invalidate(adminTrainerDetailProvider(id));
      ref.invalidate(adminTrainersProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: 'Entrenador actualizado',
        subtitle: 'Los cambios se guardaron.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo guardar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        (widget.trainer['profiles'] as Map<String, dynamic>?)?['email'] ?? '';
    return AdminRedesignSheet(
      children: [
        Text(
          'Editar entrenador',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _nameCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'Nombre completo',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _specialtyCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'Especialidad',
            prefixIcon: Icon(Icons.fitness_center_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Email: $email (no se puede modificar)',
          style: RedesignType.label.copyWith(color: RedesignColors.primario400),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary,
                    ),
                  )
                : const Text('Guardar'),
          ),
        ),
      ],
    );
  }
}

// ── Notify a single trainer ───────────────────────────────────────────────
class _NotifyTrainerSheet extends ConsumerStatefulWidget {
  final String profileId;
  final String trainerName;
  const _NotifyTrainerSheet({
    required this.profileId,
    required this.trainerName,
  });

  @override
  ConsumerState<_NotifyTrainerSheet> createState() =>
      _NotifyTrainerSheetState();
}

class _NotifyTrainerSheetState extends ConsumerState<_NotifyTrainerSheet> {
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _messageCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(supabaseServiceProvider).createNotification(
            userId: widget.profileId,
            type: 'admin_message',
            title: _titleCtrl.text.trim(),
            message: _messageCtrl.text.trim(),
          );
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: 'Notificación enviada',
        subtitle: 'Se envió a ${widget.trainerName}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo enviar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRedesignSheet(
      children: [
        Text(
          'Enviar notificación',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Para ${widget.trainerName}',
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _titleCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(hintText: 'Título'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _messageCtrl,
          maxLines: 4,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'Mensaje',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _send,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(_loading ? 'Enviando...' : 'Enviar'),
          ),
        ),
      ],
    );
  }
}
