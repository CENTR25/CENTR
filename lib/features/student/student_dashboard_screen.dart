import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import 'student_meal_plan_screen.dart';
import 'student_weight_screen.dart';
import 'student_check_in_screen.dart';
import 'student_routine_screen.dart';
import 'student_recipes_screen.dart';

class StudentDashboardScreen extends ConsumerStatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  ConsumerState<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends ConsumerState<StudentDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const _HomeContent(),
    const StudentMealPlanScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Disable back gesture
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        endDrawer: _buildSideDrawer(context, ref),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: _pages[_currentIndex],
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        ),
        extendBody: true, // Allows the body to flow behind the dock
        bottomNavigationBar: _buildCustomBottomDock(context),
      ),
    );
  }

  Widget _buildCustomBottomDock(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      height: 90, // Increased total height to allow overflow
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // Background Bar
          Container(
            height: 70, // Slightly shorter than the total height
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(color: Colors.white.withValues(alpha: 0.06), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildDockItem(
                    context,
                    icon: Icons.home_rounded,
                    label: 'Inicio',
                    isActive: _currentIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                ),
                const SizedBox(width: 90), // Space for the floating button
                Expanded(
                  child: _buildDockItem(
                    context,
                    icon: Icons.restaurant_rounded,
                    label: 'Alimentación',
                    isActive: _currentIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                ),
              ],
            ),
          ),
          
          // Elevated Center Button
          Positioned(
            top: 0, // Align to top of the stack (above the background bar)
            child: Container(
              width: 85,
              height: 85,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle, // Circular looks more premium and "floating"
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
                border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 2.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const StudentRoutineScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  customBorder: const CircleBorder(),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.fitness_center_rounded, 
                          color: Colors.white, 
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'ENTRENAR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideDrawer(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          // User Header
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?.name?.isNotEmpty == true ? user!.name![0] : 'A').toUpperCase(),
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
            accountName: Text(
              user?.name ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              user?.email ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ),

          // Menu Items
          ListTile(
            leading: const Icon(Icons.person_outline_rounded, color: Colors.white),
            title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); // Close drawer
              // Navigate to profile
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil próximamente')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white),
            title: const Text('Configuración', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Configuración próximamente')),
              );
            },
          ),
          
          const Spacer(),
          const Divider(color: Colors.white10),
          
          // Logout
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              title: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF2A2A2A),
                    title: const Text('¿Cerrar sesión?', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      '¿Estás seguro de que quieres salir?',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Salir', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                   if (context.mounted) Navigator.pop(context); // Close drawer
                   await ref.read(authProvider.notifier).signOut();
                   // Auth wrapper will handle redirection to login
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDockItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? AppColors.primary : Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeContent extends ConsumerWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      // Add padding at the bottom to account for the dock
      child: Padding(
        padding: const EdgeInsets.only(bottom: 100), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            // Premium Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'HOLA,',
                            style: TextStyle(
                              color: AppColors.textLight.withValues(alpha: 0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 12,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.studentColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.name ?? 'Campeón',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '¿Listo para entrenar hoy?',
                        style: TextStyle(
                          color: AppColors.textLight.withValues(alpha: 0.4),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Notifications with Glass Effect
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: IconButton(
                    icon: Stack(
                      children: [
                        const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.studentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {},
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Premium Avatar with Glow
                GestureDetector(
                  onTap: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          AppColors.studentColor,
                          AppColors.studentColor.withValues(alpha: 0.2),
                          AppColors.studentColor,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.studentColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.background,
                      child: Text(
                        (user?.name?.isNotEmpty == true 
                            ? user!.name![0] 
                            : 'A').toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.studentColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Combined Streak & Steps Row
            Consumer(
              builder: (context, ref, _) {
                final streakAsync = ref.watch(streakProvider);
                // Mock step count for now as per original code "0"
                // In a real app we'd watch a stepsProvider
                
                return streakAsync.when(
                  data: (streakData) {
                    final streak = streakData?['current_streak'] ?? 0;
                    
                    return IntrinsicHeight(
                      child: Row(
                        children: [
                          // Streak Card (Expanded)
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [AppColors.primary, AppColors.primaryDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.local_fire_department_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'Racha de $streak ${streak == 1 ? 'día' : 'días'}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    streak > 0 
                                      ? '¡Sigue así!'
                                      : 'Entrena para empezar',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Steps Card (Compact)
                          Expanded(
                            flex: 1,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: CircularProgressIndicator(
                                          value: 0.02, // 200/10000
                                          strokeWidth: 4,
                                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                                          color: AppColors.accent,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.directions_walk_rounded,
                                        color: AppColors.accent,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '200',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'PASOS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.accent,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                );
              },
            ),
            
            const SizedBox(height: 24),

            // Cardio Section
            Consumer(
              builder: (context, ref, _) {
                final cardioAsync = ref.watch(myCardioProvider);
                
                return cardioAsync.when(
                  data: (cardio) {
                    final description = cardio['description'] as String? ?? '';
                    final days = (cardio['days'] as List?)?.cast<int>() ?? [];
                    
                    if (description.isEmpty && days.isEmpty) {
                      return const SizedBox.shrink(); // Hide if no cardio assigned
                    }

                    // Check if today is a cardio day
                    final today = DateTime.now().weekday;
                    final isToday = days.contains(today);
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Cardio',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'HOY',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.warning.withOpacity(0.1),
                                AppColors.warning.withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.warning.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning, // Yellow icon background
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.warning.withOpacity(0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.directions_run_rounded, color: Colors.black, size: 28),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        description.isNotEmpty ? description : 'Sin instrucciones',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatCardioDays(days),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.6),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),

            // Supplements Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Suplementos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                  // Unified Supplements Master Card
                  Consumer(
                    builder: (context, ref, _) {
                      final supplementsAsync = ref.watch(mySupplementsProvider);
                      
                      return supplementsAsync.when(
                        data: (supplements) {
                          final daily = supplements['daily'] ?? '';
                          final chemical = supplements['chemical'] ?? '';
                          
                          // If both are empty, we can show a default or hide it.
                          final displayDaily = daily.isNotEmpty ? daily : 'No asignado';
                          final displayChemical = chemical.isNotEmpty ? chemical : 'No asignado';
                          
                          return _buildUnifiedSupplementCard(
                            context,
                            dailySupplements: displayDaily,
                            chemicalSupplements: displayChemical,
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // News Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.newspaper_rounded, size: 20, color: AppColors.textLight.withValues(alpha: 0.7)),
                          const SizedBox(width: 8),
                          const Text(
                            'Novedades',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          'Ver todo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160, // Slightly taller
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none, // Allow shadows to overflow
                    children: [
                      _buildNewsCard(
                        title: 'Nueva Colección',
                        subtitle: 'Ropa CENTR disponible',
                        color: const Color(0xFF9C27B0), // Purple accent
                        icon: Icons.checkroom_rounded,
                        imageAsset: null, // Could use real images later
                      ),
                      _buildNewsCard(
                        title: 'Reto de 30 Días',
                        subtitle: 'Mejora tu resistencia',
                        color: const Color(0xFFFF5722), // Orange accent
                        icon: Icons.timer_outlined,
                      ),
                       _buildNewsCard(
                        title: 'Nutrición Pro',
                        subtitle: 'Recetas exclusivas',
                        color: const Color(0xFF4CAF50), // Green accent
                        icon: Icons.restaurant_menu_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // Exclusive Benefits Section
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFD700)),
                      SizedBox(width: 8),
                      Text(
                        'Beneficios Exclusivos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: [
                      _buildNewsCard(
                        title: 'Descuento Nike',
                        subtitle: '20% OFF en ropa',
                        color: Colors.blueAccent,
                        icon: Icons.shopping_bag_rounded,
                      ),
                      _buildNewsCard(
                        title: 'Suplementos',
                        subtitle: '15% en Proteína',
                        color: Colors.tealAccent,
                        icon: Icons.local_offer_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            
            // Recipe Book (Recetario) Banner
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const StudentRecipesScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFFC2185B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -10,
                        bottom: -10,
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 80,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'RECETARIO OFICIAL',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '+100 Recetas Saludables',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Monthly Check-in / Renewal Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.1),
                    AppColors.accent.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.calendar_today_rounded, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Próxima Renovación',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Chequeo mensual: 15 de Febrero',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Today's Workout
            const Text(
              'Tu Próximo Entrenamiento',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Consumer(
              builder: (context, ref, _) {
                final routineAsync = ref.watch(activeRoutineProvider);
                
                return routineAsync.when(
                  data: (routine) {
                    if (routine == null) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_busy_rounded,
                              size: 48,
                              color: AppColors.textLight.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No tienes rutina asignada',
                              style: TextStyle(
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StudentRoutineScreen()),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.fitness_center, color: AppColors.primary),
                            ),
                            const SizedBox(width: 16),
                              Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getTodayWorkoutTitle(routine),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    'Empieza tu sesión de hoy',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const SizedBox(),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Quick Actions (Full Width)
            // Quick Actions (Full Width)
            _buildQuickAction(
              icon: Icons.camera_alt_rounded,
              label: 'Check-in',
              color: AppColors.primary,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentCheckInScreen()),
                );
              },
              isHorizontal: true,
            ),
            const SizedBox(height: 12),
            _buildQuickAction(
              icon: Icons.monitor_weight_rounded,
              label: 'Registrar Peso',
              color: AppColors.accent,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentWeightScreen()),
                );
              },
              isHorizontal: true,
            ),
            // No extra padding needed here, handled by Padding widget
          ],
        ),
      ),
    );
  }

  // Helper method to get today's workout title from routine
  String _getTodayWorkoutTitle(Map<String, dynamic> routine) {
    // Get today's day of week (1 = Monday, 7 = Sunday)
    final today = DateTime.now().weekday;
    
    // Try to get the custom day title from routine_exercises
    final exercises = routine['routine_exercises'] as List?;
    if (exercises != null && exercises.isNotEmpty) {
      // Look for exercises that match today's day
      final todayExercises = exercises.where((ex) {
        final dayOfWeek = ex['day_of_week'] as int?;
        return dayOfWeek == today;
      }).toList();
      
      if (todayExercises.isNotEmpty) {
        // Check if there's a custom day_title field
        final dayTitle = todayExercises[0]['day_title'] as String?;
        if (dayTitle != null && dayTitle.isNotEmpty) {
          return dayTitle;
        }
      }
    }
    
    // Fallback to generic day name
    const dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return 'Entrenamiento del ${dayNames[today - 1]}';
  }

  Widget _buildUnifiedSupplementCard(
    BuildContext context, {
    required String dailySupplements,
    required String chemicalSupplements,
  }) {
    // Check if both sections are empty/unassigned
    final hasDaily = dailySupplements.isNotEmpty && dailySupplements != 'No asignado';
    final hasChemical = chemicalSupplements.isNotEmpty && chemicalSupplements != 'No asignado';
    
    if (!hasDaily && !hasChemical) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.medication_outlined, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            const Text(
              'No tienes suplementación asignada',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    
    return InkWell(
      onTap: () {
        // Show the detailed supplementation modal/sheet
        _showSupplementChecklist(context, dailySupplements, chemicalSupplements);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF2A2A2A), // Slightly lighter than background
           boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            // Header for the Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.medical_services_outlined, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'SUPLEMENTOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                ],
              ),
            ),
            
            // Content List
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Section
                  if (hasDaily) ...[
                    _buildSupplementSectionTitle('Diarios (Vitaminas/Salud)', Icons.wb_sunny_rounded),
                    const SizedBox(height: 8),
                    Text(
                      dailySupplements,
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  if (hasDaily && hasChemical)
                    const Divider(color: Colors.white10, height: 24),

                  // Chemical Section
                  if (hasChemical) ...[
                    _buildSupplementSectionTitle('Química / Ciclo', Icons.science_rounded),
                    const SizedBox(height: 8),
                    Text(
                      chemicalSupplements,
                      style: const TextStyle(color: Colors.white70, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Toca para registrar tu toma diaria',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary.withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSupplementSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  void _showSupplementChecklist(BuildContext context, String daily, String chemical) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplementChecklistModal(daily: daily, chemical: chemical),
    );
  }

  Widget _buildNewsCard({
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    String? imageAsset,
  }) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(const Color(0xFF2A2A2A), color, 0.15)!,
            const Color(0xFF2A2A2A),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Decorative Background Icon
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(
                  icon,
                  size: 100,
                  color: color.withValues(alpha: 0.05),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        
                        // "New" Badge or similar could go here
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Text(
                            'NUEVO',
                            style: TextStyle(
                              fontSize: 9, 
                              fontWeight: FontWeight.bold, 
                              color: Colors.white70
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary.withValues(alpha: 0.8),
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
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
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isHorizontal = false,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), // More padding for Horizontal
          child: isHorizontal 
            ? Row(
                children: [
                   Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.2)),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
        ),
      ),
    );
  }
}

// ----- Supplement Checklist Modal Component ----- //
class _SupplementChecklistModal extends ConsumerStatefulWidget {
  final String daily;
  final String chemical;

  const _SupplementChecklistModal({required this.daily, required this.chemical});

  @override
  ConsumerState<_SupplementChecklistModal> createState() => _SupplementChecklistModalState();
}

class _SupplementChecklistModalState extends ConsumerState<_SupplementChecklistModal> {
  // We'll track checked items locally.
  // In a real app, you might parse the strings into lists.
  // For now, we'll treat lines as items.
  
  late List<String> dailyItems;
  late List<String> chemicalItems;
  
  // Set of checked items (composite key: section_index)
  final Set<String> _checkedItems = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _parseItems();
    _loadProgress();
  }

  void _parseItems() {
    dailyItems = widget.daily.split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
        
    chemicalItems = widget.chemical.split('\n')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
  }

  Future<void> _loadProgress() async {
    // Fetch today's log properly using the service
    final log = await ref.read(studentServiceProvider).getTodaySupplementLog();
    
    if (log != null && log['ticked_items'] != null) {
      final ticked = List<String>.from(log['ticked_items']);
      setState(() {
        _checkedItems.addAll(ticked);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleItem(String key) async {
    setState(() {
      if (_checkedItems.contains(key)) {
        _checkedItems.remove(key);
      } else {
        _checkedItems.add(key);
      }
    });

    // Persist immediately
    await ref.read(studentServiceProvider).logSupplements(
      tickedItems: _checkedItems.toList(),
    );
    
    // Refresh the master provider to update streaks if we had any logic there
    // ref.refresh(mySupplementsProvider); // Not strictly needed unless checking completion
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Checklist Diario',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10),
          
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  if (dailyItems.isNotEmpty) ...[
                    const Text('SUPLEMENTOS DIARIOS', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    ...dailyItems.asMap().entries.map((e) {
                      final key = 'daily_${e.key}';
                      return _buildCheckItem(key, e.value);
                    }),
                    const SizedBox(height: 32),
                  ],

                  if (chemicalItems.isNotEmpty) ...[
                     const Text('QUÍMICA / CICLO', style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    const SizedBox(height: 12),
                    ...chemicalItems.asMap().entries.map((e) {
                      final key = 'chem_${e.key}';
                      return _buildCheckItem(key, e.value);
                    }),
                  ],
                  
                  if (dailyItems.isEmpty && chemicalItems.isEmpty)
                    const Center(
                      child: Text(
                        'No hay items para mostrar',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    
                  const SizedBox(height: 40),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String key, String label) {
    final isChecked = _checkedItems.contains(key);
    
    return InkWell(
      onTap: () => _toggleItem(key),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isChecked 
              ? AppColors.primary.withValues(alpha: 0.1) 
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isChecked ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isChecked ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isChecked ? AppColors.primary : Colors.white54,
                  width: 2,
                ),
              ),
              child: isChecked 
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isChecked ? Colors.white : Colors.white70,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatCardioDays(List<int> days) {
  if (days.isEmpty) return 'Sin días asignados';
  final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final sortedDays = List<int>.from(days)..sort();
  return sortedDays.map((d) {
    if (d >= 1 && d <= 7) {
      return dayNames[d - 1];
    }
    return '';
  }).where((element) => element.isNotEmpty).join(', ');
}
