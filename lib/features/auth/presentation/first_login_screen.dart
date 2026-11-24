import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../shared/redesign_toast.dart';
import 'widgets/prgs_brand.dart';
import 'widgets/redesign_text_field.dart';

class FirstLoginScreen extends ConsumerStatefulWidget {
  final String token;

  const FirstLoginScreen({super.key, required this.token});

  @override
  ConsumerState<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends ConsumerState<FirstLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(child: _buildForm()),
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
              'Configurá tu contraseña',
              textAlign: TextAlign.center,
              style: RedesignType.headingMd.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bienvenido a PRGS. Elegí una contraseña segura para tu cuenta.',
              textAlign: TextAlign.center,
              style: RedesignType.bodySm
                  .copyWith(color: RedesignColors.primario300),
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
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                if (value.length < 8) return 'Mínimo 8 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),
            RedesignTextField(
              controller: _confirmPasswordController,
              hint: 'Confirmar contraseña',
              obscureText: _obscureConfirm,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _completeFirstLogin(),
              suffixIcon: _eye(
                _obscureConfirm,
                () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              validator: (value) => value != _passwordController.text
                  ? 'Las contraseñas no coinciden'
                  : null,
            ),
            const SizedBox(height: 14),
            Text(
              'Mínimo 8 caracteres, con mayúsculas, minúsculas y números.',
              textAlign: TextAlign.center,
              style:
                  RedesignType.label.copyWith(color: RedesignColors.primario400),
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
                onPressed: _isLoading ? null : _completeFirstLogin,
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
                        'Continuar',
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

  Widget _eye(bool obscured, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Icon(
          obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: RedesignColors.primario400,
          size: 20,
        ),
      );

  Future<void> _completeFirstLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final adminService = ref.read(adminServiceProvider);

      // Complete first login (updates password and marks as logged in)
      await adminService.completeFirstLogin(
        token: widget.token,
        newPassword: _passwordController.text,
      );

      if (mounted) {
        showRedesignToast(
          context,
          title: 'Contraseña establecida',
          subtitle: 'Iniciá sesión con tus credenciales.',
        );

        // Navigate to login screen
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  /// Never show raw exception text to the user.
  static String _friendlyError(Object e) {
    final t = e.toString().toLowerCase();
    if (t.contains('expired') ||
        t.contains('invalid token') ||
        t.contains('already used') ||
        t.contains('used')) {
      return 'El enlace expiró o ya fue usado. Pedile al administrador una nueva invitación.';
    }
    return 'No pudimos guardar tu contraseña. Revisá tu conexión e intentá de nuevo.';
  }
}
