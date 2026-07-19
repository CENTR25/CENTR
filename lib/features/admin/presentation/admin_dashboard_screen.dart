import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/admin_service.dart';
import '../../../services/news_service.dart';
import '../../../models/news_model.dart';
import '../widgets/trainer_sheets.dart';
import 'trainers_list_screen.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _currentIndex = 0;

  final List<_NavItem> _navItems = [
    _NavItem(icon: Icons.dashboard_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.people_rounded, label: 'Entrenadores'),
    _NavItem(icon: Icons.card_membership_rounded, label: 'Planes'),
    _NavItem(icon: Icons.newspaper_rounded, label: 'Noticias'),
    _NavItem(icon: Icons.settings_rounded, label: 'Config'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.star_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('CENTR'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _DashboardView();
      case 1:
        return const TrainersListScreen();
      case 2:
        return _SubscriptionsView();
      case 3:
        return _NewsView();
      case 4:
        return _SettingsView();
      default:
        return _DashboardView();
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: _navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        )).toList(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).signOut();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}

// ==================== DASHBOARD VIEW ====================
class _DashboardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¡Bienvenido, Admin!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Panel de administración',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Resumen',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Stats grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                title: 'Entrenadores',
                value: '0',
                icon: Icons.people_rounded,
                color: AppColors.primary,
              ),
              _StatCard(
                title: 'Suscripciones',
                value: '0',
                icon: Icons.card_membership_rounded,
                color: AppColors.success,
              ),
              _StatCard(
                title: 'Alumnos',
                value: '0',
                icon: Icons.school_rounded,
                color: AppColors.accent,
              ),
              _StatCard(
                title: 'Ingresos',
                value: '\$0',
                icon: Icons.attach_money_rounded,
                color: AppColors.warning,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          const Text(
            'Acciones rápidas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 12),
          
          _ActionCard(
            icon: Icons.person_add_rounded,
            title: 'Invitar Entrenador',
            subtitle: 'Enviar link de acceso',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _ActionCard(
            icon: Icons.mail_rounded,
            title: 'Enviar Notificación',
            subtitle: 'A todos los usuarios',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== TRAINERS VIEW ====================
class _TrainersView extends ConsumerWidget {
  const _TrainersView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainersAsync = ref.watch(allTrainersProvider);

    return Scaffold(
      body: trainersAsync.when(
        data: (trainers) {
          if (trainers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No hay entrenadores', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Invita a tu primer entrenador', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trainers.length,
            itemBuilder: (context, index) {
              final trainer = trainers[index];
              final profile = trainer['profiles'] as Map<String, dynamic>;
              final name = profile['name'] ?? 'Sin nombre';
              final email = profile['email'] ?? '';
              final specialty = trainer['specialty'] ?? 'Sin especialidad';
              final isActive = trainer['is_active'] == true;
              final hasLoggedIn = trainer['has_logged_in'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: isActive ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade300,
                        child: Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            color: isActive ? AppColors.primary : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!hasLoggedIn)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.notification_important, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      if (!isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Inactivo', style: TextStyle(fontSize: 10, color: AppColors.error)),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(specialty, style: const TextStyle(fontSize: 12)),
                      if (!hasLoggedIn)
                        const Text(
                          'Pendiente primer login',
                          style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleAction(context, ref, value, trainer),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(
                        value: isActive ? 'deactivate' : 'activate',
                        child: Text(isActive ? 'Desactivar' : 'Activar'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTrainer(context),
        icon: const Icon(Icons.add),
        label: const Text('Invitar Trainer'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showCreateTrainer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateTrainerSheet(),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Map<String, dynamic> trainer,
  ) async {
    final service = ref.read(adminServiceProvider);
    final trainerId = trainer['id'] as String;

    try {
      switch (action) {
        case 'edit':
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => EditTrainerSheet(trainer: trainer),
          );
          break;

        case 'activate':
        case 'deactivate':
          final isActive = action == 'activate';
          await service.updateTrainer(trainerId, isActive: isActive);
          ref.invalidate(allTrainersProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isActive ? 'Trainer activado' : 'Trainer desactivado')),
            );
          }
          break;

        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eliminar Trainer'),
              content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await service.deleteTrainer(trainerId);
            ref.invalidate(allTrainersProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trainer eliminado'), backgroundColor: AppColors.success),
              );
            }
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

// ==================== SUBSCRIPTIONS VIEW ====================
class _SubscriptionsView extends ConsumerStatefulWidget {
  const _SubscriptionsView();

  @override
  ConsumerState<_SubscriptionsView> createState() => _SubscriptionsViewState();
}

class _SubscriptionsViewState extends ConsumerState<_SubscriptionsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Planes'),
            Tab(text: 'Asignaciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _PlansTab(),
          _AssignmentsTab(),
        ],
      ),
    );
  }
}

// Plans Tab
class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Scaffold(
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.card_membership, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No hay planes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final name = plan['name'] ?? 'Plan';
              final price = plan['price'] ?? 0.0;
              final durationDays = plan['duration_days'] ?? 30;
              final maxStudents = plan['max_students'];
              final features = plan['features'] as Map<String, dynamic>?;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.workspace_premium, color: AppColors.primary),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('\$$price/mes'),
                      Text('$durationDays días', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if (maxStudents != null)
                        Text('Hasta $maxStudents alumnos', style: const TextStyle(fontSize: 12)),
                      if (features != null && features.isNotEmpty)
                        Text(
                          features.keys.take(2).join(', '),
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  isThreeLine: true,
                  onTap: () {
                    // TODO: Show plan details
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Create plan
        },
        icon: const Icon(Icons.add),
        label: const Text('Crear Plan'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

// Assignments Tab
class _AssignmentsTab extends ConsumerWidget {
  const _AssignmentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trainersAsync = ref.watch(allTrainersProvider);

    return trainersAsync.when(
      data: (trainers) {
        if (trainers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text('No hay trainers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: trainers.length,
          itemBuilder: (context, index) {
            final trainer = trainers[index];
            final profile = trainer['profiles'] as Map<String, dynamic>;
            final name = profile['name'] ?? 'Sin nombre';
            final trainerId = trainer['id'] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Sin suscripción activa'),
                trailing: ElevatedButton.icon(
                  onPressed: () => _showAssignSubscription(context, ref, trainer),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Asignar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  void _showAssignSubscription(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> trainer,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignSubscriptionSheet(trainer: trainer),
    );
  }
}

// Assign Subscription Sheet
class _AssignSubscriptionSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> trainer;

  const _AssignSubscriptionSheet({required this.trainer});

  @override
  ConsumerState<_AssignSubscriptionSheet> createState() => _AssignSubscriptionSheetState();
}

class _AssignSubscriptionSheetState extends ConsumerState<_AssignSubscriptionSheet> {
  String? _selectedPlanId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.trainer['profiles'] as Map<String, dynamic>;
    final name = profile['name'] ?? 'Trainer';
    final plansAsync = ref.watch(subscriptionPlansProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
                Expanded(
                  child: Text(
                    'Asignar suscripción a $name',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                TextButton(
                  onPressed: _selectedPlanId == null || _isLoading ? null : _assignSubscription,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Asignar'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Plans List
          Expanded(
            child: plansAsync.when(
              data: (plans) {
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: plans.length,
                  itemBuilder: (context, index) {
                    final plan = plans[index];
                    final planId = plan['id'] as String;
                    final name = plan['name'] ?? 'Plan';
                    final price = plan['price'] ?? 0.0;
                    final durationDays = plan['duration_days'] ?? 30;
                    final maxStudents = plan['max_students'];

                    return RadioListTile<String>(
                      value: planId,
                      groupValue: _selectedPlanId,
                      onChanged: (value) => setState(() => _selectedPlanId = value),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('\$$price/mes'),
                          Text('Duración: $durationDays días'),
                          if (maxStudents != null) Text('Hasta $maxStudents alumnos'),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignSubscription() async {
    if (_selectedPlanId == null) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(adminServiceProvider);
      final trainerId = widget.trainer['id'] as String;

      await service.assignSubscription(
        trainerId: trainerId,
        planId: _selectedPlanId!,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suscripción asignada'), backgroundColor: AppColors.success),
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

// ==================== NEWS VIEW ====================
class _NewsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsAsync = ref.watch(allNewsProvider);

    return Scaffold(
      body: newsAsync.when(
        data: (newsList) {
          if (newsList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.newspaper_rounded, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text('No hay noticias publicadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                   const SizedBox(height: 8),
                  Text('Crea la primera noticia para tu comunidad', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: newsList.length,
            itemBuilder: (context, index) {
              final news = newsList[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    if (news.imageUrl != null)
                      Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(news.imageUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Color(int.parse(news.accentColor.replaceAll('#', '0xFF'))),
                        child: Icon(_getIconData(news.iconName), color: Colors.white),
                      ),
                      title: Text(
                        news.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            news.content,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: news.isPublished ? AppColors.success.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  news.isPublished ? 'Publicado' : 'Borrador',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: news.isPublished ? AppColors.success : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatDate(news.createdAt),
                                style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) => _handleAction(context, ref, value, news),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'toggle_publish',
                            child: Text(news.isPublished ? 'Despublicar' : 'Publicar'),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Eliminar', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateNews(context),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Noticia'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'newspaper': return Icons.newspaper_rounded;
      case 'checkroom': return Icons.checkroom_rounded;
      case 'restaurant': return Icons.restaurant_menu_rounded;
      case 'timer': return Icons.timer_outlined;
      case 'shopping_bag': return Icons.shopping_bag_rounded;
      case 'star': return Icons.star_rounded;
      case 'fitness_center': return Icons.fitness_center_rounded;
      default: return Icons.newspaper_rounded;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showCreateNews(BuildContext context, {NewsArticle? article}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateNewsSheet(article: article),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    NewsArticle article,
  ) async {
    final service = ref.read(newsServiceProvider);

    try {
      switch (action) {
        case 'edit':
           _showCreateNews(context, article: article);
          break;

        case 'toggle_publish':
          await service.updateNews(article.id, isPublished: !article.isPublished);
          ref.invalidate(allNewsProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(article.isPublished ? 'Noticia despublicada' : 'Noticia publicada')),
            );
          }
          break;

        case 'delete':
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Eliminar Noticia'),
              content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Eliminar'),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await service.deleteNews(article.id);
            ref.invalidate(allNewsProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Noticia eliminada'), backgroundColor: AppColors.success),
              );
            }
          }
          break;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _CreateNewsSheet extends ConsumerStatefulWidget {
  final NewsArticle? article;

  const _CreateNewsSheet({this.article});

  @override
  ConsumerState<_CreateNewsSheet> createState() => _CreateNewsSheetState();
}

class _CreateNewsSheetState extends ConsumerState<_CreateNewsSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _imageUrlController;
  String _selectedColor = '#9C27B0'; // Default purple
  String _selectedIcon = 'newspaper';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _colors = [
    {'name': 'Morado', 'code': '#9C27B0', 'color': Colors.purple},
    {'name': 'Naranja', 'code': '#FF5722', 'color': Colors.deepOrange},
    {'name': 'Verde', 'code': '#4CAF50', 'color': Colors.green},
    {'name': 'Azul', 'code': '#2196F3', 'color': Colors.blue},
    {'name': 'Rojo', 'code': '#F44336', 'color': Colors.red},
    {'name': 'Dorado', 'code': '#FFC107', 'color': Colors.amber},
    {'name': 'Teal', 'code': '#009688', 'color': Colors.teal},
  ];

  final List<Map<String, dynamic>> _icons = [
    {'name': 'newspaper', 'icon': Icons.newspaper_rounded, 'label': 'Noticia'},
    {'name': 'checkroom', 'icon': Icons.checkroom_rounded, 'label': 'Ropa'},
    {'name': 'restaurant', 'icon': Icons.restaurant_menu_rounded, 'label': 'Comida'},
    {'name': 'timer', 'icon': Icons.timer_outlined, 'label': 'Reto'},
    {'name': 'shopping_bag', 'icon': Icons.shopping_bag_rounded, 'label': 'Tienda'},
    {'name': 'star', 'icon': Icons.star_rounded, 'label': 'Estrella'},
    {'name': 'fitness_center', 'icon': Icons.fitness_center_rounded, 'label': 'Gym'},
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.article?.title ?? '');
    _contentController = TextEditingController(text: widget.article?.content ?? '');
    _imageUrlController = TextEditingController(text: widget.article?.imageUrl ?? '');
    
    if (widget.article != null) {
      _selectedColor = widget.article!.accentColor;
      _selectedIcon = widget.article!.iconName;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final service = ref.read(newsServiceProvider);
      
      if (widget.article != null) {
        // Edit
        await service.updateNews(
          widget.article!.id,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          accentColor: _selectedColor,
          iconName: _selectedIcon,
        );
      } else {
        // Create
        await service.createNews(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
          accentColor: _selectedColor,
          iconName: _selectedIcon,
        );
      }

      ref.invalidate(allNewsProvider);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.article != null ? 'Noticia actualizada' : 'Noticia creada'), 
            backgroundColor: AppColors.success
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.article != null ? 'Editar Noticia' : 'Nueva Noticia',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                labelText: 'Contenido',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.article),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL de Imagen (Opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.image),
                helperText: 'Deja vacío para usar solo color',
              ),
            ),
            const SizedBox(height: 16),
            
            const Text('Color de acento', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colors.map((color) {
                  final isSelected = _selectedColor == color['code'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color['code']),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: AppColors.primary, width: 2) : null,
                      ),
                      child: CircleAvatar(
                        backgroundColor: color['color'],
                        radius: 16,
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            const Text('Icono', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _icons.map((item) {
                  final isSelected = _selectedIcon == item['name'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = item['name']),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(item['icon'], size: 18, color: isSelected ? AppColors.primary : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            item['label'],
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : Colors.grey.shade700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 32),
            
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.article != null ? 'Guardar Cambios' : 'Crear Noticia'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== SETTINGS VIEW ====================
class _SettingsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (user?.name ?? user?.email ?? 'A')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.name ?? 'Administrador',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          _SettingsTile(
            icon: Icons.person_outline,
            title: 'Editar perfil',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Cambiar contraseña',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Apariencia',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'Acerca de',
            onTap: () {},
          ),
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(authProvider.notifier).signOut(),
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Cerrar sesión', style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
