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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detalle del Alumno'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.white,
                          child: Text(
                            (name.isNotEmpty ? name[0] : 'A').toUpperCase(),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Stats Section
                const _SectionHeaderNoAction(title: 'Estadísticas'),
                const SizedBox(height: 12),
                _buildStatsRow(student),
                
                const SizedBox(height: 32),
                
                // Activity History
                _buildActivityHistory(student),

                const SizedBox(height: 32),
                
                // Routine Section
                _SectionHeader(title: 'Rutina Actual', action: 'Asignar', onTap: () => _showAssignRoutineSheet(context)),
                const SizedBox(height: 8),
                if (activeRoutine != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.fitness_center_rounded, color: AppColors.success, size: 28),
                      ),
                      title: Text(
                        activeRoutine['routines']?['title'] ?? 'Rutina',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        'Asignada el ${_formatDate(activeRoutine['start_date'])}',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 16),
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
                    icon: Icons.fitness_center_rounded,
                    text: 'Sin rutina asignada',
                    onTap: () => _showAssignRoutineSheet(context),
                  ),
                ],

                const SizedBox(height: 32),

                // Cardio Section
                _SectionHeader(
                  title: 'Cardio',
                  action: 'Editar',
                  onTap: () => _showEditCardioDialog(context, student),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.directions_run, color: AppColors.warning, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student['cardio_description'] as String? ?? 'No asignado',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatCardioDays(student['cardio_days'] as List?),
                                  style: TextStyle(color: AppColors.textLight.withOpacity(0.7), fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Supplements Section
                _SectionHeader(
                  title: 'Suplementación',
                  action: 'Editar',
                  onTap: () => _showEditSupplementsDialog(context),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildSupplementRow(
                        icon: Icons.medication_rounded,
                        label: 'Suplementos Diarios',
                        value: 'Creatina 5g, Omega 3',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildSupplementRow(
                        icon: Icons.science_rounded,
                        label: 'Suplementación Química',
                        value: 'No asignado',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Meal Plan Section
                _SectionHeader(title: 'Plan Alimenticio', action: 'Asignar', onTap: () => _showAssignMealPlanSheet(context)),
                const SizedBox(height: 8),
                if (activeMealPlan != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.restaurant_rounded, color: AppColors.warning, size: 28),
                      ),
                      title: Text(
                        activeMealPlan['meal_plans']?['name'] ?? 'Plan Alimenticio',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                       subtitle: Text(
                         'Asignado el ${_formatDate(activeMealPlan['start_date'])}',
                         style: TextStyle(color: AppColors.textLight),
                       ),
                       trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.2), size: 16),
                       onTap: () {
                         // Open Meal Plan Detail
                       },
                    ),
                  ),
                ] else ...[
                  _EmptyStateCard(
                    icon: Icons.restaurant_rounded,
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
                const _SectionHeaderNoAction(title: 'Estadísticas'),
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            Text(
              'Sin datos de peso aún',
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${value.toInt()}kg',
                          style: TextStyle(fontSize: 10, color: AppColors.textLight),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface,
                    tooltipBorder: BorderSide(color: AppColors.primary.withOpacity(0.2)),
                  ),
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
                    barWidth: 4,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.2),
                          AppColors.primary.withOpacity(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInsGallery(Map<String, dynamic> student) {
    // Check-ins might be in a different field, adapting to possible schema
    final checkIns = (student['check_ins'] as List?) ?? [];
    
    if (checkIns.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.photo_camera_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            Text(
              'Sin fotos de check-in',
              style: TextStyle(color: AppColors.textLight),
            ),
          ],
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
              borderRadius: BorderRadius.circular(16),
              color: AppColors.surface,
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            clipBehavior: Clip.antiAlias,
            child: photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                  )
                : const Icon(Icons.photo_rounded, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildActivityHistory(Map<String, dynamic> student) {
    final workoutLogs = (student['workout_logs'] as List?) ?? [];
    
    // Get last 7 days activity
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actividad de la Semana',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = today.subtract(Duration(days: 6 - index));
              final dateStr = date.toIso8601String().split('T')[0];
              
              final hasWorkout = workoutLogs.any((log) {
                final logDateStr = (log['created_at'] as String?)?.split('T')[0];
                return logDateStr == dateStr;
              });

              final dayName = ['L', 'M', 'M', 'J', 'V', 'S', 'D'][date.weekday - 1];
              final isToday = index == 6;

              return Column(
                children: [
                  Text(
                    dayName,
                    style: TextStyle(
                      color: isToday ? AppColors.primaryLight : AppColors.textLight,
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: hasWorkout 
                        ? AppColors.primary.withOpacity(0.2) 
                        : Colors.white.withOpacity(0.03),
                      shape: BoxShape.circle,
                      border: hasWorkout 
                        ? Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)
                        : null,
                    ),
                    child: Icon(
                      hasWorkout ? Icons.local_fire_department_rounded : Icons.remove_rounded,
                      size: 18,
                      color: hasWorkout ? Colors.orange : Colors.white.withOpacity(0.1),
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> student) {
    final streaks = (student['streaks'] as List?) ?? [];
    final workoutLogs = (student['workout_logs'] as List?) ?? [];
    
    // Get current streak
    int currentStreak = 0;
    if (streaks.isNotEmpty) {
      final streakData = streaks.first as Map<String, dynamic>;
      currentStreak = (streakData['current_streak'] as int?) ?? 0;
      
      // Live calculation for trainer view accuracy
      final lastWorkoutStr = streakData['last_workout_date'] as String?;
      if (lastWorkoutStr != null) {
        final lastWorkoutDate = DateTime.parse(lastWorkoutStr);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final workoutDate = DateTime(lastWorkoutDate.year, lastWorkoutDate.month, lastWorkoutDate.day);

        // If last workout was not today and not yesterday, streak counts as 0
        if (workoutDate.isBefore(yesterday) && workoutDate != today) {
          currentStreak = 0;
        }
      }
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

  Widget _buildSupplementRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final hasValue = value.isNotEmpty && value != 'No asignado';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.textLight.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: hasValue ? Colors.white : Colors.white.withOpacity(0.3),
                    fontSize: 16,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.normal,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSupplementsDialog(BuildContext context) {
    // Controllers with initial mock values
    final dailyController = TextEditingController(text: 'Creatina 5g, Omega 3');
    final chemicalController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Editar Suplementación', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailyController,
              decoration: const InputDecoration(
                labelText: 'Suplementos Diarios',
                hintText: 'Ej: Proteína, Creatina...',
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: chemicalController,
              decoration: const InputDecoration(
                labelText: 'Suplementación Química',
                hintText: 'Ej: Texto para atletas...',
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
              onPressed: () async {
                final daily = dailyController.text.trim();
                final chemical = chemicalController.text.trim();
                
                try {
                  await ref.read(trainerServiceProvider).updateAthleteSupplements(
                    widget.studentId,
                    daily,
                    chemical,
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Suplementación actualizada'),
                        backgroundColor: AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    // Refresh the screen data
                    // In a real app with Riverpod, we might invalidate a provider here
                    // For now, setState might trigger a rebuild if we were fetching in build, 
                    // but since this is a detail screen passed with data, we might need a refresh callback 
                    // or rely on the parent provider updating. 
                    // Assuming the parent widget watches a provider for this student ID.
                     ref.invalidate(studentDetailProvider(widget.studentId)); 
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al guardar')),
                    );
                  }
                }
              },
            child: const Text('Guardar'),
          ),
        ],
      ),
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
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        TextButton(
          onPressed: onTap, 
          style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight),
          child: Text(action.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ),
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white.withOpacity(0.2), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              text, 
              style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.w500),
            ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textLight,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Provider for fetching specific student details
final studentDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, studentId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getStudentDetails(studentId);
});

class _SectionHeaderNoAction extends StatelessWidget {
  final String title;
  const _SectionHeaderNoAction({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

extension _CardioHelpers on _StudentDetailScreenState {
  String _formatCardioDays(List? days) {
    if (days == null || days.isEmpty) return 'Sin días asignados';
    final dayNames = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final assigned = days.map((d) => dayNames[(d as int) - 1]).join(', ');
    return assigned;
  }

  void _showEditCardioDialog(BuildContext context, Map<String, dynamic> student) {
    final descriptionController = TextEditingController(
      text: student['cardio_description'] as String? ?? '',
    );
    
    // Convert to Set for easy toggle
    final initialDays = (student['cardio_days'] as List?)?.cast<int>() ?? [];
    Set<int> selectedDays = Set.from(initialDays);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Configurar Cardio', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Instrucciones',
                    hintText: 'Ej: 30 min caminadora inclinación 12 a paso 3.5',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text('Días de la semana:', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(7, (index) {
                    final dayNum = index + 1;
                    final dayName = ['L', 'M', 'M', 'J', 'V', 'S', 'D'][index];
                    final isSelected = selectedDays.contains(dayNum);
                    
                    return FilterChip(
                      label: Text(dayName),
                      selected: isSelected,
                      onSelected: (bool selected) {
                        setState(() {
                          if (selected) {
                            selectedDays.add(dayNum);
                          } else {
                            selectedDays.remove(dayNum);
                          }
                        });
                      },
                      checkmarkColor: Colors.white,
                      selectedColor: AppColors.warning,
                      backgroundColor: AppColors.surfaceVariant, // Changed from Colors.white10
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: isSelected ? Colors.transparent : Colors.white12,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final description = descriptionController.text.trim();
                  final daysList = selectedDays.toList()..sort();
                  
                  try {
                    await ref.read(trainerServiceProvider).updateAthleteCardio(
                      widget.studentId,
                      description,
                      daysList,
                    );
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Cardio actualizado'),
                          backgroundColor: AppColors.accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                      ref.invalidate(studentDetailProvider(widget.studentId)); 
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Error al guardar')),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}
