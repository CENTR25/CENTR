import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/auth_service.dart';
import 'widgets/redesign_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref
          .read(authProvider.notifier)
          .resetPassword(_emailController.text.trim());
      // Always show success — do not leak whether the email exists.
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _sent = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backToLogin() => context.go(AppRoutes.login);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: _sent ? _buildSent() : _buildForm(),
                  ),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '¿Olvidaste la\ncontraseña?',
            textAlign: TextAlign.center,
            style: RedesignType.headingMd.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
              fontSize: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ingresá tu email y te enviaremos\nlos pasos para restablecerla.',
            textAlign: TextAlign.center,
            style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
          ),
          const SizedBox(height: 28),
          RedesignTextField(
            controller: _emailController,
            hint: 'mail@mail.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSend(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresá tu email';
              }
              if (!value.contains('@')) return 'Ingresá un email válido';
              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: RedesignSpacing.inputHeight,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSend,
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
                      'Enviar',
                      style: RedesignType.buttonLg
                          .copyWith(color: RedesignColors.onActionPrimary),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          _backLink(),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: RedesignColors.success,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: RedesignColors.primario50, size: 34),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '¡Email enviado!',
          textAlign: TextAlign.center,
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Revisá tu bandeja de entrada para\ncontinuar. Si no lo encontrás, chequeá la\ncarpeta de spam.',
          textAlign: TextAlign.center,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: RedesignSpacing.inputHeight,
          child: ElevatedButton(
            onPressed: _backToLogin,
            child: Text(
              'Volver a iniciar sesión',
              style: RedesignType.buttonLg
                  .copyWith(color: RedesignColors.onActionPrimary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _backLink() => Center(
        child: TextButton(
          onPressed: _backToLogin,
          style: TextButton.styleFrom(
            foregroundColor: RedesignColors.primario300,
            textStyle: RedesignType.buttonSm,
          ),
          child: const Text('Volver a iniciar sesión'),
        ),
      );
}
