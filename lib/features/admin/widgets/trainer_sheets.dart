import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/admin_service.dart';

// Create Trainer Sheet
class CreateTrainerSheet extends ConsumerStatefulWidget {
  const CreateTrainerSheet({super.key});

  @override
  ConsumerState<CreateTrainerSheet> createState() => _CreateTrainerSheetState();
}

class _CreateTrainerSheetState extends ConsumerState<CreateTrainerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _specialtyController = TextEditingController();
  bool _isLoading = false;
  
  Map<String, dynamic>? _createdTrainer;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Invitar Trainer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _saveTrainer,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Enviar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _createdTrainer == null
                  ? _buildForm()
                  : _buildSuccessView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v?.isEmpty == true) return 'Requerido';
              if (!v!.contains('@')) return 'Email inválido';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Name
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
          ),
          const SizedBox(height: 16),

          // Specialty
          TextFormField(
            controller: _specialtyController,
            decoration: const InputDecoration(
              labelText: 'Especialidad (opcional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.fitness_center),
              hintText: 'Ej: Entrenamiento funcional',
            ),
          ),
          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Se creará una cuenta y se enviará un email de invitación con las credenciales.',
                    style: TextStyle(color: AppColors.primary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    final tempPassword = _createdTrainer!['temp_password'] as String;
    final invitationToken = _createdTrainer!['invitation_token'] as String;
    final email = _emailController.text;
    final inviteLink = 'northstar://first-login?token=$invitationToken';

    return Column(
      children: [
        const Icon(Icons.check_circle, size: 64, color: AppColors.success),
       const SizedBox(height: 16),
        const Text(
          '¡Trainer creado!',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Cuenta creada para $email',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),

        // Invitation Link Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.link, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Link de Invitación',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  inviteLink,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '💡 Envía este link al trainer para que configure su contraseña',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Credentials card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.lock, color: AppColors.warning),
                  SizedBox(width: 8),
                  Text(
                    'Credenciales Temporales',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Email: $email', style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text('Contraseña: ', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SelectableText(
                        tempPassword,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '⚠️ El trainer debe usar el link de arriba o cambiar la contraseña manualmente',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _sendEmail(email, inviteLink, tempPassword),
                icon: const Icon(Icons.email_outlined),
                label: const Text('Enviar Correo'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Refresh list
                  ref.invalidate(allTrainersProvider);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _sendEmail(String email, String link, String password) async {
    final subject = Uri.encodeComponent('Invitación a unirte a North Star');
    final body = Uri.encodeComponent('''
Hola,

Te he creado una cuenta de entrenador en North Star.

Para comenzar, por favor sigue estos pasos:
1. Haz clic en este enlace para configurar tu contraseña:
$link

2. O usa esta contraseña temporal:
$password

¡Saludos!
''');

    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');

    try {
      await launchUrl(uri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el correo: $e')),
        );
      }
    }
  }


  Future<void> _saveTrainer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminServiceProvider);

      final result = await service.createTrainer(
        email: _emailController.text.trim(),
        name: _nameController.text.trim(),
        specialty: _specialtyController.text.trim().isEmpty ? null : _specialtyController.text.trim(),
      );

      setState(() {
        _createdTrainer = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// Edit Trainer Sheet
class EditTrainerSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> trainer;

  const EditTrainerSheet({super.key, required this.trainer});

  @override
  ConsumerState<EditTrainerSheet> createState() => _EditTrainerSheetState();
}

class _EditTrainerSheetState extends ConsumerState<EditTrainerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _specialtyController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.trainer['profiles'] as Map<String, dynamic>;
    _nameController = TextEditingController(text: profile['name'] ?? '');
    _specialtyController = TextEditingController(text: widget.trainer['specialty'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.trainer['profiles'] as Map<String, dynamic>;
    final email = profile['email'] ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                const Expanded(
                  child: Text(
                    'Editar Trainer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Guardar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email (read-only)
                    TextFormField(
                      initialValue: email,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                        enabled: false,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El email no se puede modificar',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // Specialty
                    TextFormField(
                      controller: _specialtyController,
                      decoration: const InputDecoration(
                        labelText: 'Especialidad',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminServiceProvider);
      final trainerId = widget.trainer['id'] as String;

      await service.updateTrainer(
        trainerId,
        name: _nameController.text.trim(),
        specialty: _specialtyController.text.trim().isEmpty ? null : _specialtyController.text.trim(),
      );

      ref.invalidate(allTrainersProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trainer actualizado'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}
