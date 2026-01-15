import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/supabase_service.dart';

// Provider for trainers list
final trainersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(supabaseServiceProvider);
  return service.getTrainers();
});

class TrainersListScreen extends ConsumerWidget {
  const TrainersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainersAsync = ref.watch(trainersProvider);

    return Scaffold(
      body: trainersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(trainersProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (trainers) {
          if (trainers.isEmpty) {
            return _EmptyState(onInvite: () => _showInviteDialog(context, ref));
          }
          return _TrainersList(trainers: trainers);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Invitar'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const InviteTrainerSheet(),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onInvite;

  const _EmptyState({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No hay entrenadores',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Invita a tu primer entrenador para comenzar a gestionar tu plataforma',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.send),
              label: const Text('Enviar invitación'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainersList extends StatelessWidget {
  final List<Map<String, dynamic>> trainers;

  const _TrainersList({required this.trainers});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        // Will be handled by provider refresh
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: trainers.length,
        itemBuilder: (context, index) {
          final trainer = trainers[index];
          final profile = trainer['profiles'] as Map<String, dynamic>?;
          final subscription = (trainer['subscriptions'] as List?)?.isNotEmpty == true
              ? trainer['subscriptions'][0] as Map<String, dynamic>
              : null;

          return _TrainerCard(
            name: trainer['name'] ?? profile?['email'] ?? 'Sin nombre',
            email: profile?['email'] ?? '',
            phone: trainer['phone'] ?? '',
            studentCount: trainer['current_student_count'] ?? 0,
            maxStudents: subscription?['max_students'] ?? 0,
            subscriptionStatus: subscription?['status'] ?? 'none',
            onTap: () => _showTrainerDetail(context, trainer),
          );
        },
      ),
    );
  }

  void _showTrainerDetail(BuildContext context, Map<String, dynamic> trainer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrainerDetailSheet(trainer: trainer),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final String name;
  final String email;
  final String phone;
  final int studentCount;
  final int maxStudents;
  final String subscriptionStatus;
  final VoidCallback onTap;

  const _TrainerCard({
    required this.name,
    required this.email,
    required this.phone,
    required this.studentCount,
    required this.maxStudents,
    required this.subscriptionStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          email,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SubscriptionBadge(status: subscriptionStatus),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(
                    icon: Icons.people,
                    label: '$studentCount / $maxStudents alumnos',
                  ),
                  const SizedBox(width: 8),
                  if (phone.isNotEmpty)
                    _InfoChip(
                      icon: Icons.phone,
                      label: phone,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionBadge extends StatelessWidget {
  final String status;

  const _SubscriptionBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'active':
        color = AppColors.success;
        label = 'Activo';
        break;
      case 'pending':
        color = AppColors.warning;
        label = 'Pendiente';
        break;
      case 'expired':
        color = AppColors.error;
        label = 'Expirado';
        break;
      default:
        color = AppColors.textSecondary;
        label = 'Sin plan';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== INVITE TRAINER SHEET ====================
class InviteTrainerSheet extends ConsumerStatefulWidget {
  const InviteTrainerSheet({super.key});

  @override
  ConsumerState<InviteTrainerSheet> createState() => _InviteTrainerSheetState();
}

class _InviteTrainerSheetState extends ConsumerState<InviteTrainerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedPlan = 'basic_5';
  bool _isLoading = false;

  final Map<String, String> _plans = {
    'basic_5': 'Básico - 5 alumnos',
    'standard_25': 'Estándar - 25 alumnos',
    'pro_50': 'Pro - 50 alumnos',
    'enterprise_100': 'Enterprise - 100 alumnos',
  };

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _sendInvitation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(supabaseServiceProvider);
      await service.createInvitation(
        email: _emailController.text.trim(),
        role: 'trainer',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitación enviada correctamente'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.refresh(trainersProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Invitar Entrenador',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Envía un link de acceso para que el entrenador pueda registrarse.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre (opcional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingresa el correo';
                  }
                  if (!value.contains('@')) {
                    return 'Ingresa un correo válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPlan,
                decoration: const InputDecoration(
                  labelText: 'Plan inicial',
                  prefixIcon: Icon(Icons.card_membership_outlined),
                ),
                items: _plans.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedPlan = value);
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendInvitation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isLoading ? 'Enviando...' : 'Enviar Invitación'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TRAINER DETAIL SHEET ====================
class TrainerDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> trainer;

  const TrainerDetailSheet({super.key, required this.trainer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = trainer['profiles'] as Map<String, dynamic>?;
    final subscription = (trainer['subscriptions'] as List?)?.isNotEmpty == true
        ? trainer['subscriptions'][0] as Map<String, dynamic>
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                (trainer['name'] ?? 'T')[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              trainer['name'] ?? 'Sin nombre',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              profile?['email'] ?? '',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            _SubscriptionBadge(status: subscription?['status'] ?? 'none'),
            const SizedBox(height: 24),
            _DetailRow(
              icon: Icons.people,
              label: 'Alumnos',
              value: '${trainer['current_student_count'] ?? 0} / ${subscription?['max_students'] ?? 0}',
            ),
            _DetailRow(
              icon: Icons.phone,
              label: 'Teléfono',
              value: trainer['phone'] ?? 'No registrado',
            ),
            _DetailRow(
              icon: Icons.calendar_today,
              label: 'Registrado',
              value: _formatDate(trainer['created_at']),
            ),
            if (trainer['bio'] != null && trainer['bio'].isNotEmpty)
              _DetailRow(
                icon: Icons.info_outline,
                label: 'Bio',
                value: trainer['bio'],
              ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Edit trainer
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Manage subscription
                    },
                    icon: const Icon(Icons.card_membership),
                    label: const Text('Plan'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _showDeleteConfirm(context, ref),
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                label: const Text('Eliminar entrenador', style: TextStyle(color: AppColors.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    try {
      final d = DateTime.parse(date);
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) {
      return date;
    }
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar entrenador?'),
        content: const Text('Esta acción no se puede deshacer. Se eliminará el entrenador y todos sus datos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close sheet
              
              try {
                final service = ref.read(supabaseServiceProvider);
                await service.deleteTrainer(trainer['id']);
                ref.refresh(trainersProvider);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Entrenador eliminado'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
