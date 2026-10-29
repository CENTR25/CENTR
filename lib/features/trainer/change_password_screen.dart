import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/auth_service.dart';
import '../shared/redesign_toast.dart';

// ---------------------------------------------------------------------------
// ChangePasswordScreen (Figma "Cambiar contraseña")
//
// Three password fields with eye toggles, a live rule checklist under the new
// password, and an "Actualizar contraseña" button. On success it pops back to
// Configuración with a success toast — the session stays active.
// ---------------------------------------------------------------------------

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(() => setState(() {}));
    _confirmCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _newCtrl.text.length >= 8;
  bool get _hasNumber => RegExp(r'\d').hasMatch(_newCtrl.text);
  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_newCtrl.text);
  bool get _passwordsMatch =>
      _newCtrl.text.isNotEmpty && _newCtrl.text == _confirmCtrl.text;

  bool get _canSubmit =>
      _currentCtrl.text.isNotEmpty &&
      _hasMinLength &&
      _hasNumber &&
      _hasUppercase &&
      _passwordsMatch &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .changePassword(_currentCtrl.text, _newCtrl.text);

    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    showRedesignToast(
      context,
      title: 'Contraseña actualizada',
      subtitle: 'Tu contraseña se cambió correctamente.',
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
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
            'Cambiar contraseña',
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
            _PasswordField(
              label: 'Contraseña actual',
              controller: _currentCtrl,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 20),
            _PasswordField(
              label: 'Nueva contraseña',
              controller: _newCtrl,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 14),
            _RuleRow(label: 'Al menos 8 caracteres', satisfied: _hasMinLength),
            const SizedBox(height: 8),
            _RuleRow(label: 'Un número', satisfied: _hasNumber),
            const SizedBox(height: 8),
            _RuleRow(label: 'Una mayúscula', satisfied: _hasUppercase),
            const SizedBox(height: 20),
            _PasswordField(
              label: 'Repetir nueva contraseña',
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            if (_confirmCtrl.text.isNotEmpty && !_passwordsMatch) ...[
              const SizedBox(height: 10),
              Text(
                'Las contraseñas no coinciden.',
                style: RedesignType.label.copyWith(color: RedesignColors.danger),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: RedesignColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(RedesignRadius.banner),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: RedesignColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error!,
                        style: RedesignType.label
                            .copyWith(color: RedesignColors.peligro200),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RedesignColors.onActionPrimary,
                      ),
                    )
                  : const Text('Actualizar contraseña'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PasswordField — label + frosted rounded input with an eye toggle
// ---------------------------------------------------------------------------

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: InputDecoration(
            hintText: '••••••••',
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _RuleRow — a single password-rule line, teal check when satisfied
// ---------------------------------------------------------------------------

class _RuleRow extends StatelessWidget {
  final String label;
  final bool satisfied;

  const _RuleRow({required this.label, required this.satisfied});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          satisfied
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 20,
          color: satisfied
              ? RedesignColors.actionPrimaryDark
              : RedesignColors.primario500,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: RedesignType.label.copyWith(
            color: satisfied
                ? RedesignColors.actionPrimaryDark
                : RedesignColors.primario300,
            fontWeight: satisfied ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
