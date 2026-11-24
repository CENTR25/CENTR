import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/supabase_service.dart';
import '../../shared/redesign_toast.dart';
import 'widgets/prgs_brand.dart';
import 'widgets/redesign_text_field.dart';

/// Student self-registration screen, opened via the trainer's invite link.
///
/// URL format: /register?trainer={trainer_id}[&email={invited_email}]
///
/// Security contract (enforced here):
/// - role is ALWAYS hardcoded to 'student' — never taken from the URL.
/// - trainer_id from the URL is used ONLY to associate the new athlete record;
///   it conveys no privilege.
/// - user_id in the athlete INSERT is always auth.uid() after signup.
/// - No service_role key is used anywhere in this flow.
class StudentRegisterScreen extends ConsumerStatefulWidget {
  /// The trainer's `trainers.id` value extracted from the invite URL query param.
  final String? trainerId;

  /// Optional invited email from the link (`&email=`), used only to prefill
  /// the email field. The trainer id is NEVER put in any text field.
  final String? initialEmail;

  const StudentRegisterScreen({super.key, this.trainerId, this.initialEmail});

  @override
  ConsumerState<StudentRegisterScreen> createState() =>
      _StudentRegisterScreenState();
}

class _StudentRegisterScreenState extends ConsumerState<StudentRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final email = widget.initialEmail?.trim();
    if (email != null && email.contains('@')) _emailController.text = email;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final client = ref.read(supabaseClientProvider);

    try {
      // Validate that trainer_id looks like a UUID before trusting it.
      final uuidPattern = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      final trainerId =
          widget.trainerId != null && uuidPattern.hasMatch(widget.trainerId!)
              ? widget.trainerId
              : null;

      // Create the auth user. Role is ALWAYS 'student' — not from the URL.
      // The profiles and athletes rows are created server-side by the
      // on_auth_user_created trigger (add_student_signup_trigger.sql): with
      // email confirmation enabled there is no session yet, so client-side
      // inserts would be rejected by RLS. The trigger also validates that
      // trainer_id references a real trainer before linking it.
      final authResponse = await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'name': _nameController.text.trim(),
          'role': 'student',
          if (trainerId != null) 'trainer_id': trainerId,
        },
      );

      if (authResponse.user == null) {
        throw Exception('No se pudo crear la cuenta. Intenta de nuevo.');
      }

      // Navigate — auth state listener in AuthNotifier will handle the rest.
      if (mounted) {
        showRedesignToast(context, title: '¡Cuenta creada!');
        context.go(AppRoutes.login);
      }
    } on AuthException catch (e) {
      setState(() {
        _error = _localizeAuthError(e.message);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _localizeAuthError(String message) {
    if (message.contains('already registered') ||
        message.contains('already been registered')) {
      return 'Este correo ya está registrado. Usa "Iniciar sesión".';
    }
    if (message.contains('Password should be')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (message.contains('Invalid email')) {
      return 'El correo no es válido.';
    }
    if (message.contains('rate limit') || message.contains('rate_limit')) {
      return 'Demasiados intentos seguidos. Espera unos minutos e intenta de nuevo.';
    }
    // handle_new_user fails when the inviting trainer is at their plan's
    // student cap (athletes trigger); GoTrue masks it as a generic DB error.
    if (message.contains('Database error saving new user')) {
      return 'No pudimos crear tu cuenta. Es posible que tu entrenador haya alcanzado el límite de alumnos de su plan: avisale e intentá de nuevo más tarde.';
    }
    return message;
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
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 48),

                          // ── Brand lockup (same as login) ──────────────────
                          const Center(child: PrgsLogoLockup()),

                          const SizedBox(height: 41),

                          // ── Title block ──────────────────────────────────
                          Text(
                            'Crear cuenta',
                            textAlign: TextAlign.center,
                            style: RedesignType.headingMd.copyWith(
                              color: RedesignColors.primario50,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.trainerId != null
                                ? 'Tu entrenador te invitó a Progress'
                                : 'Regístrate en Progress',
                            textAlign: TextAlign.center,
                            style: RedesignType.bodySm.copyWith(
                              color: RedesignColors.primario300,
                            ),
                          ),

                          const SizedBox(height: 36),

                          // ── Form ─────────────────────────────────────────
                          RedesignTextField(
                            controller: _nameController,
                            hint: 'Nombre completo',
                            keyboardType: TextInputType.name,
                            autofillHints: const [AutofillHints.name],
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu nombre';
                              }
                              if (v.trim().length < 2) {
                                return 'Mínimo 2 caracteres';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          RedesignTextField(
                            controller: _emailController,
                            hint: 'Correo electrónico',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Ingresa tu correo';
                              }
                              if (!v.contains('@')) {
                                return 'Correo no válido';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          RedesignTextField(
                            controller: _passwordController,
                            hint: 'Contraseña',
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.newPassword],
                            textInputAction: TextInputAction.next,
                            suffixIcon: _eye(
                              _obscurePassword,
                              () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Ingresa una contraseña';
                              }
                              if (v.length < 6) return 'Mínimo 6 caracteres';
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
                            onFieldSubmitted: (_) => _register(),
                            suffixIcon: _eye(
                              _obscureConfirm,
                              () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'Las contraseñas no coinciden';
                              }
                              return null;
                            },
                          ),

                          // Inline error (same treatment as login)
                          if (_error != null) ...[
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
                                    _error!,
                                    style: RedesignType.label.copyWith(
                                      color: RedesignColors.peligro300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 36),

                          SizedBox(
                            height: RedesignSpacing.inputHeight,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _register,
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
                                      'Crear cuenta',
                                      style: RedesignType.buttonLg.copyWith(
                                        color: RedesignColors.onActionPrimary,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Back to login
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '¿Ya tienes cuenta?',
                                style: RedesignType.bodySm.copyWith(
                                  color: RedesignColors.primario300,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.go(AppRoutes.login),
                                style: TextButton.styleFrom(
                                  foregroundColor:
                                      RedesignColors.actionPrimary,
                                  textStyle: RedesignType.buttonSm,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                ),
                                child: const Text('Iniciar sesión'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
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
}
