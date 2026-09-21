import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/routing/app_router.dart';
import '../../../services/supabase_service.dart';

/// Student self-registration screen, opened via the trainer's invite link.
///
/// URL format: /register?trainer={trainer_id}
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

  const StudentRegisterScreen({super.key, this.trainerId});

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '¡Cuenta creada! Revisa tu email para confirmar tu dirección.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
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
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo / icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha:0.4),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 28),

                const Text(
                  'Crear cuenta',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.trainerId != null
                      ? 'Tu entrenador te invitó a Progress'
                      : 'Regístrate en Progress',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // Error banner
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha:0.4),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Form
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildField(
                        controller: _nameController,
                        label: 'Nombre completo',
                        icon: Icons.person_outline,
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
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _emailController,
                        label: 'Correo electrónico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
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
                      const SizedBox(height: 14),
                      _buildPasswordField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        obscure: _obscurePassword,
                        onToggle: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Confirmar contraseña',
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _register(),
                        validator: (v) {
                          if (v != _passwordController.text) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Register button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Crear cuenta',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Back to login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '¿Ya tienes cuenta?',
                            style: TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.login),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryLight,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                            child: const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: textInputAction == TextInputAction.next
          ? (_) => FocusScope.of(context).nextFocus()
          : null,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.textLight, size: 20),
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted ??
          (textInputAction == TextInputAction.next
              ? (_) => FocusScope.of(context).nextFocus()
              : null),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textLight, size: 20),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.textLight,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
