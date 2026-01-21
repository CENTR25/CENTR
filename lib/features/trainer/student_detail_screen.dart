import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';
import 'routine_detail_screen.dart';
import 'assignment_sheets.dart';
import 'student_history_screen.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final String studentId;

  const StudentDetailScreen({super.key, required this.studentId});

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends ConsumerState<StudentDetailScreen> {
  // We will need providers for fetching detailed info. 
  // For now, we reuse the service call directly or create a specific provider.
  
  @override
  Widget build(BuildContext context) {
    // We'll create a future provider for this screen specifically or use a future builder for simplicity first
    final studentAsync = ref.watch(studentDetailProvider(widget.studentId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Alumno'),
      ),
      body: studentAsync.when(
        data: (student) {
          if (student == null) {
            return const Center(child: Text('Alumno no encontrado'));
          }
          
          final profile = student['profiles'] as Map<String, dynamic>?;
          final name = profile?['name'] ?? 'Sin nombre';
          final email = profile?['email'] ?? 'Sin correo';
          
          // Extract active routine
          final routines = (student['athlete_routines'] as List?) ?? [];
          final activeRoutine = routines.firstWhere(
            (r) => r['is_active'] == true,
            orElse: () => null,
          );
          
          // Extract active meal plan
          final mealPlans = (student['athlete_meal_plans'] as List?) ?? [];
          final activeMealPlan = mealPlans.firstWhere(
            (m) => m['is_active'] == true, 
            orElse: () => null,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          (name.isNotEmpty ? name[0] : 'A').toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Routine Section
                _SectionHeader(title: 'Rutina Actual', action: 'Asignar', onTap: () => _showAssignRoutineSheet(context)),
                const SizedBox(height: 8),
                if (activeRoutine != null) ...[
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fitness_center, color: AppColors.success),
                      ),
                      title: Text(activeRoutine['routines']?['title'] ?? 'Rutina'),
                      subtitle: Text('Asignada el ${_formatDate(activeRoutine['start_date'])}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoutineDetailScreen(
                              routineId: activeRoutine['routine_id'],
                              routineTitle: activeRoutine['routines']?['title'] ?? 'Rutina',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  _EmptyStateCard(
                    icon: Icons.fitness_center,
                    text: 'Sin rutina asignada',
                    onTap: () => _showAssignRoutineSheet(context),
                  ),
                ],

                const SizedBox(height: 32),

                // Meal Plan Section
                _SectionHeader(title: 'Plan Alimenticio', action: 'Asignar', onTap: () => _showAssignMealPlanSheet(context)),
                const SizedBox(height: 8),
                if (activeMealPlan != null) ...[
                  Card(
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.restaurant, color: AppColors.warning),
                      ),
                      title: Text(activeMealPlan['meal_plans']?['name'] ?? 'Plan Alimenticio'),
                       subtitle: Text('Asignado el ${_formatDate(activeMealPlan['start_date'])}'),
                       trailing: const Icon(Icons.chevron_right),
                       onTap: () {
                         // Open Meal Plan Detail
                       },
                    ),
                  ),
                ] else ...[
                  _EmptyStateCard(
                    icon: Icons.restaurant,
                    text: 'Sin plan asignado',
                    onTap: () => _showAssignMealPlanSheet(context),
                  ),
                ],

                const SizedBox(height: 32),

                // Weight Progress Section
                _SectionHeader(
                  title: 'Progreso de Peso',
                  action: 'Ver todo',
                  onTap: () {
                    // TODO: Navigate to full weight history
                  },
                ),
                const SizedBox(height: 8),
                _buildWeightChart(student),

                const SizedBox(height: 32),

                // Check-ins Section
                _SectionHeader(
                  title: 'Fotos Check-in',
                  action: 'Ver todas',
                  onTap: () {
                    // TODO: Navigate to full gallery
                  },
                ),
                const SizedBox(height: 8),
                _buildCheckInsGallery(student),

                const SizedBox(height: 32),

                // Stats Section
                _SectionHeader(
                  title: 'Estadísticas', 
                  action: 'Ver Historial',
                  onTap: () {
                     Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentHistoryScreen(
                          studentId: widget.studentId,
                          studentName: name,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildStatsRow(student),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showAssignRoutineSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignRoutineSheet(studentId: widget.studentId),
    );
  }

  void _showAssignMealPlanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AssignMealPlanSheet(studentId: widget.studentId),
    );
  }

  Widget _buildWeightChart(Map<String, dynamic> student) {
    final bodyProgress = (student['body_progress'] as List?) ?? [];
    
    if (bodyProgress.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.show_chart, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Sin datos de peso aún',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by date and get last 7 entries
    final sortedProgress = List<Map<String, dynamic>>.from(bodyProgress);
    sortedProgress.sort((a, b) => 
      DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at']))
    );
    final recentProgress = sortedProgress.take(7).toList();

    // Create spots for chart
    final spots = <FlSpot>[];
    for (int i = 0; i < recentProgress.length; i++) {
      final weight = (recentProgress[i]['weight'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), weight));
    }

    // Calculate min/max for Y axis
    final weights = spots.map((s) => s.y).toList();
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity);
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) => Text(
                      '${value.toInt()} kg',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (recentProgress.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.primary,
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckInsGallery(Map<String, dynamic> student) {
    // Check-ins might be in a different field, adapting to possible schema
    final checkIns = (student['check_ins'] as List?) ?? [];
    
    if (checkIns.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.photo_camera, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 8),
              Text(
                'Sin fotos de check-in',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: checkIns.length,
        itemBuilder: (context, index) {
          final checkIn = checkIns[index] as Map<String, dynamic>;
          final photoUrl = checkIn['photo_url'] as String?;
          
          return Container(
            width: 100,
            margin: EdgeInsets.only(right: index < checkIns.length - 1 ? 12 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade100,
            ),
            clipBehavior: Clip.antiAlias,
            child: photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                  )
                : const Icon(Icons.photo, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> student) {
    final streaks = (student['streaks'] as List?) ?? [];
    final workoutLogs = (student['workout_logs'] as List?) ?? [];
    
    // Get current streak
    int currentStreak = 0;
    if (streaks.isNotEmpty) {
      currentStreak = (streaks.first['current_streak'] as int?) ?? 0;
    }

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department,
            value: '$currentStreak',
            label: 'Racha actual',
            color: Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.fitness_center,
            value: '${workoutLogs.length}',
            label: 'Entrenamientos',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onTap;

  const _SectionHeader({required this.title, required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _EmptyStateCard({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          // dash pattern implication
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Provider for fetching specific student details
final studentDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getStudentDetails(studentId);
});
