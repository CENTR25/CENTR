import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/auth_service.dart';
import 'widgets/prgs_brand.dart';
import 'widgets/redesign_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _authError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _authError = null;
    });

    try {
      // NOTE: backend authenticates by EMAIL (signInWithEmail). The field is
      // labelled "Nombre" per the Figma design — see the Nombre-vs-email flag.
      await ref.read(authProvider.notifier).signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );

      if (!mounted) return;
      // Only an explicit errorMessage means failure. On success the user is
      // populated ASYNC by the auth-state listener, so user==null right here is
      // NOT an error — the router's refreshListenable redirects to the dashboard.
      final authState = ref.read(authProvider);
      if (authState.errorMessage != null) {
        setState(() => _authError = authState.errorMessage);
        ref.read(authProvider.notifier).clearError();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _authError = 'El usuario o la contraseña no son correctos.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.75),
              radius: 1.1,
              colors: [
                Color(0x1A01D2B2), // subtle teal glow behind the logo
                RedesignColors.background,
              ],
              stops: [0.0, 0.55],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 90), // ring top ≈ Figma Y137

                          // ── Brand lockup (teal ring + "prgs") ────────────
                          const Center(child: PrgsLogoLockup()),

                          const SizedBox(height: 41), // wordmark → form top (Y342)

                          // ── Title block ──────────────────────────────────
                          Text(
                            'Iniciar sesión',
                            textAlign: TextAlign.center,
                            style: RedesignType.headingMd.copyWith(
                              color: RedesignColors.primario50,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Ingresá tus datos para continuar',
                            textAlign: TextAlign.center,
                            style: RedesignType.bodySm.copyWith(
                              color: RedesignColors.primario300,
                            ),
                          ),

                          const SizedBox(height: 36), // form auto-layout gap

                          // ── Form ─────────────────────────────────────────
                          Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                RedesignTextField(
                                  controller: _emailController,
                                  hint: 'Nombre',
                                  textInputAction: TextInputAction.next,
                                  validator: (value) =>
                                      (value == null || value.trim().isEmpty)
                                          ? 'Ingresá tu nombre'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                RedesignTextField(
                                  controller: _passwordController,
                                  hint: 'Contraseña',
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _handleLogin(),
                                  suffixIcon: GestureDetector(
                                    onTap: () => setState(
                                      () => _obscurePassword = !_obscurePassword,
                                    ),
                                    child: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: RedesignColors.primario400,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                          ? 'Ingresá tu contraseña'
                                          : null,
                                ),

                                // Inline auth error (matches Figma error state)
                                if (_authError != null) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        size: 15,
                                        color: RedesignColors.peligro300,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          _authError!,
                                          style: RedesignType.label.copyWith(
                                            color: RedesignColors.peligro300,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 36),

                                // Forgot password — centered
                                Center(
                                  child: TextButton(
                                    onPressed: () =>
                                        context.push(AppRoutes.forgotPassword),
                                    style: TextButton.styleFrom(
                                      foregroundColor: RedesignColors.primario300,
                                      textStyle: RedesignType.buttonSm,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('¿Olvidaste tu contraseña?'),
                                  ),
                                ),

                                const SizedBox(height: 36),

                                SizedBox(
                                  height: RedesignSpacing.inputHeight,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                RedesignColors.onActionPrimary,
                                              ),
                                            ),
                                          )
                                        : Text(
                                            'Iniciar sesión',
                                            style: RedesignType.buttonLg.copyWith(
                                              color:
                                                  RedesignColors.onActionPrimary,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
