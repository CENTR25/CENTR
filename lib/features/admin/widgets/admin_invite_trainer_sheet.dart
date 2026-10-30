import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../shared/redesign_toast.dart';
import 'admin_redesign_sheet.dart';

/// "Invitar entrenador" modal (Figma First Batch). Collects email / name /
/// optional specialty, creates the trainer via the admin-auth Edge Function,
/// then shows the invitation link + temp password for the admin to share.
class AdminInviteTrainerSheet extends ConsumerStatefulWidget {
  const AdminInviteTrainerSheet({super.key});

  @override
  ConsumerState<AdminInviteTrainerSheet> createState() =>
      _AdminInviteTrainerSheetState();
}

class _AdminInviteTrainerSheetState
    extends ConsumerState<AdminInviteTrainerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _specialtyCtrl = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _created;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _nameCtrl.dispose();
    _specialtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await ref.read(adminServiceProvider).createTrainer(
            email: _emailCtrl.text.trim(),
            name: _nameCtrl.text.trim(),
            specialty: _specialtyCtrl.text.trim().isEmpty
                ? null
                : _specialtyCtrl.text.trim(),
          );
      ref.invalidate(adminTrainersProvider);
      ref.invalidate(adminPendientesProvider);
      ref.invalidate(adminDashboardMetricsProvider);
      if (!mounted) return;
      setState(() {
        _created = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo invitar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRedesignSheet(
      children: _created == null ? _form() : _success(),
    );
  }

  List<Widget> _form() {
    return [
      Row(
        children: [
          const Icon(Icons.person_add_alt_1_rounded,
              color: RedesignColors.primario50, size: 24),
          const SizedBox(width: 10),
          Text(
            'Invitar entrenador',
            style: RedesignType.headingMd.copyWith(
              color: RedesignColors.primario50,
              fontSize: 26,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario50),
              decoration: const InputDecoration(
                hintText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                if (!v.contains('@')) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario50),
              decoration: const InputDecoration(
                hintText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _specialtyCtrl,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario50),
              decoration: const InputDecoration(
                hintText: 'Especialidad (opcional)',
                prefixIcon: Icon(Icons.fitness_center_rounded),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: RedesignColors.advertencia800.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(RedesignRadius.banner),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: RedesignColors.advertencia300, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se creará una cuenta y se enviará un mail de invitación '
                      'con las credenciales.',
                      style: RedesignType.label.copyWith(
                        color: RedesignColors.advertencia100,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
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
        ),
      ),
    ];
  }

  List<Widget> _success() {
    final token = _created!['invitation_token'] as String;
    final tempPassword = _created!['temp_password'] as String;
    final link = '${AppConstants.firstLoginBaseUrl}?token=$token';
    final email = _emailCtrl.text.trim();

    return [
      Center(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: RedesignColors.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: RedesignColors.primario50, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              '¡Entrenador invitado!',
              style: RedesignType.bodyMd.copyWith(
                color: RedesignColors.primario50,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuenta creada para $email',
              textAlign: TextAlign.center,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario300),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _CopyField(label: 'Link de invitación', value: link),
      const SizedBox(height: 12),
      _CopyField(label: 'Contraseña temporal', value: tempPassword),
      const SizedBox(height: 20),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: const Text('Listo'),
        ),
      ),
    ];
  }
}

class _CopyField extends StatelessWidget {
  final String label;
  final String value;

  const _CopyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: RedesignColors.primario900,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: RedesignColors.primario50,
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: value));
                  showRedesignToast(
                    context,
                    title: 'Copiado',
                    subtitle: 'Se copió al portapapeles.',
                  );
                },
                child: const Icon(Icons.copy_rounded,
                    color: RedesignColors.actionPrimaryDark, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
