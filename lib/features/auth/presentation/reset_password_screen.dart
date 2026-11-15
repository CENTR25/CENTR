import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/auth_service.dart';
import '../../shared/redesign_toast.dart';
import 'widgets/prgs_brand.dart';
import 'widgets/redesign_text_field.dart';

/// Landing screen of the password-recovery email link
/// (`/reset-password?token_hash=…&type=recovery`).
///
/// The token is verified only when the user taps "Continuar" — never on load —
/// because email link scanners prefetch GET links and only this client-side
/// POST (`verifyOTP`) consumes the one-time token. Once verified, the router
/// keeps the recovery session pinned here (token stripped from the URL) until
/// a new password is set. An invalid / expired / used link offers a new email.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.tokenHash, this.type});

  final String? tokenHash;
  final String? type;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _verifying = false;
  bool _verifyFailed = false;
  String? _error;

  bool get _hasToken =>
      (widget.tokenHash?.isNotEmpty ?? false) && widget.type == 'recovery';

  Future<void> _handleVerify() async {
    setState(() => _verifying = true);
    final ok = await ref
        .read(authProvider.notifier)
        .verifyRecoveryToken(widget.tokenHash!);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _verifying = false;
        _verifyFailed = true;
      });
      return;
    }
    // Drop the spent token from the URL (history entry is replaced on web).
    // The router's recovery pin does the same if this tree is rebuilt first.
    context.go(AppRoutes.resetPassword);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final error = await ref
        .read(authProvider.notifier)
        .completePasswordRecovery(_passwordController.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = error;
        _isLoading = false;
      });
      return;
    }
    // On success the router redirects to the user's dashboard.
    showRedesignToast(
      context,
      title: 'Contraseña actualizada',
      subtitle: 'Ya podés usar tu nueva contraseña.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final recoveryPending = ref.read(authProvider.notifier).isPasswordRecovery;
    final isResolving = authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading;

    final Widget body;
    if (recoveryPending && authState.status == AuthStatus.authenticated) {
      body = _buildForm();
    } else if (recoveryPending || _verifying || isResolving) {
      body = const CircularProgressIndicator(
        color: RedesignColors.actionPrimary,
      );
    } else if (_hasToken && !_verifyFailed) {
      body = _buildContinue();
    } else {
      body = _buildInvalidLink();
    }

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: body),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            const Center(child: PrgsLogoLockup()),
            const SizedBox(height: 41),
            Text(
              'Nueva contraseña',
              textAlign: TextAlign.center,
              style: RedesignType.headingMd.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Elegí una nueva contraseña para tu cuenta',
              textAlign: TextAlign.center,
              style:
                  RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
            ),
            const SizedBox(height: 36),
            RedesignTextField(
              controller: _passwordController,
              hint: 'Nueva contraseña',
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              suffixIcon: _eye(
                _obscurePassword,
                () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresá una contraseña';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            RedesignTextField(
              controller: _confirmController,
              hint: 'Confirmar contraseña',
              obscureText: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSave(),
              suffixIcon: _eye(
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (v) => v != _passwordController.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: RedesignType.label
                    .copyWith(color: RedesignColors.peligro300),
              ),
            ],
            const SizedBox(height: 36),
            SizedBox(
              height: RedesignSpacing.inputHeight,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSave,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            RedesignColors.onActionPrimary,
                          ),
                        ),
                      )
                    : Text(
                        'Guardar contraseña',
                        style: RedesignType.buttonLg
                            .copyWith(color: RedesignColors.onActionPrimary),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContinue() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 32),
        const Center(child: PrgsLogoLockup()),
        const SizedBox(height: 41),
        Text(
          'Restablecer contraseña',
          textAlign: TextAlign.center,
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Tocá Continuar para elegir una nueva contraseña',
          textAlign: TextAlign.center,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 36),
        SizedBox(
          height: RedesignSpacing.inputHeight,
          child: ElevatedButton(
            onPressed: _handleVerify,
            child: Text(
              'Continuar',
              style: RedesignType.buttonLg
                  .copyWith(color: RedesignColors.onActionPrimary),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildInvalidLink() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enlace no válido',
          textAlign: TextAlign.center,
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'El enlace para restablecer la contraseña expiró o ya fue usado.\nPedí uno nuevo para continuar.',
          textAlign: TextAlign.center,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: RedesignSpacing.inputHeight,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.forgotPassword),
            child: Text(
              'Pedir un nuevo enlace',
              style: RedesignType.buttonLg
                  .copyWith(color: RedesignColors.onActionPrimary),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.login),
            style: TextButton.styleFrom(
              foregroundColor: RedesignColors.primario300,
              textStyle: RedesignType.buttonSm,
            ),
            child: const Text('Volver a iniciar sesión'),
          ),
        ),
      ],
    );
  }

  Widget _eye(bool obscured, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: RedesignColors.primario400,
          size: 20,
        ),
      );
}
