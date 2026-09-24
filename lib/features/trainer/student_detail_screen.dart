import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';
import 'routine_detail_screen.dart';
import 'meal_plan_detail_screen.dart';
import 'assignment_sheets.dart';
import 'student_history_screen.dart';
import 'intake_view_screen.dart';

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
          final name = student['name'] ?? 'Sin nombre';
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
                        color: AppColors.primary.withValues(alpha: 0.3),
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
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // Athlete intake questionnaire ("Formulario para conocer al Atleta")
                _buildIntakeCard(context, name),

                const SizedBox(height: 32),

                // Stats Section
                _SectionHeader(
                  title: 'Estadísticas',
                  action: 'Ver historial',
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
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
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
                      trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _personalizeRoutine(
                        context,
                        activeRoutine['routine_id'] as String,
                        activeRoutine['routines']?['title'] as String? ??
                            'Rutina',
                        name,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Personalizar para este alumno'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
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
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
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
                                  style: TextStyle(color: AppColors.textLight.withValues(alpha: 0.7), fontSize: 13),
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
                  onTap: () => _showEditSupplementsDialog(context, student),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    children: [
                      _buildSupplementRow(
                        icon: Icons.medication_rounded,
                        label: 'Suplementos Diarios',
                        value: (student['daily_supplements'] as String?)
                                    ?.trim()
                                    .isNotEmpty ==
                                true
                            ? student['daily_supplements'] as String
                            : 'No asignado',
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 12),
                      _buildSupplementRow(
                        icon: Icons.science_rounded,
                        label: 'Suplementación Química',
                        value: (student['chemical_supplements'] as String?)
                                    ?.trim()
                                    .isNotEmpty ==
                                true
                            ? student['chemical_supplements'] as String
                            : 'No asignado',
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Renewal Date Section
                _SectionHeader(
                  title: 'Próximo Vencimiento',
                  action: 'Editar',
                  onTap: () => _showEditRenewalDateDialog(context, student),
                ),
                const SizedBox(height: 12),
                _buildRenewalDateCard(context, student),

                const SizedBox(height: 32),

                // Meal Plan Section
                _SectionHeader(title: 'Plan Alimenticio', action: 'Asignar', onTap: () => _showAssignMealPlanSheet(context)),
                const SizedBox(height: 8),
                if (activeMealPlan != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.restaurant_rounded, color: AppColors.warning, size: 28),
                      ),
                      title: Text(
                        activeMealPlan['meal_plans']?['title'] ?? 'Plan Alimenticio',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                       subtitle: Text(
                         'Asignado el ${_formatDate(activeMealPlan['start_date'])}',
                         style: TextStyle(color: AppColors.textLight),
                       ),
                       trailing: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withValues(alpha: 0.2), size: 16),
                       onTap: () {
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (context) => MealPlanDetailScreen(
                               planId: activeMealPlan['meal_plan_id'],
                               planName: activeMealPlan['meal_plans']?['title'] ??
                                   'Plan Alimenticio',
                             ),
                           ),
                         );
                       },
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _personalizeMealPlan(
                        context,
                        activeMealPlan['meal_plan_id'] as String,
                        activeMealPlan['meal_plans']?['title'] as String? ??
                            'Plan Alimenticio',
                        name,
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Personalizar para este alumno'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryLight,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
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
                  action: 'Agregar',
                  onTap: () => _showAddWeightDialog(context),
                ),
                const SizedBox(height: 8),
                _buildWeightChart(student),

                const SizedBox(height: 32),

                // Check-ins Section
                const _SectionHeaderNoAction(title: 'Fotos Check-in'),
                const SizedBox(height: 8),
                _buildCheckInsGallery(student),
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

  Future<void> _personalizeRoutine(
    BuildContext context,
    String routineId,
    String routineTitle,
    String studentName,
  ) async {
    final confirmed = await _confirmPersonalize(
      context,
      'Se creará una copia de "$routineTitle" solo para $studentName. '
      'Los cambios que hagas en la copia no afectan la rutina original.',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final service = ref.read(trainerServiceProvider);
      final newId = await service.personalizeRoutineForStudent(
        athleteId: widget.studentId,
        routineId: routineId,
        newTitle: '$routineTitle — $studentName',
      );
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RoutineDetailScreen(
            routineId: newId,
            routineTitle: '$routineTitle — $studentName',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _personalizeMealPlan(
    BuildContext context,
    String mealPlanId,
    String planTitle,
    String studentName,
  ) async {
    final confirmed = await _confirmPersonalize(
      context,
      'Se creará una copia de "$planTitle" solo para $studentName. '
      'Los cambios que hagas en la copia no afectan el plan original.',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final service = ref.read(trainerServiceProvider);
      final newId = await service.personalizeMealPlanForStudent(
        athleteId: widget.studentId,
        mealPlanId: mealPlanId,
        newTitle: '$planTitle — $studentName',
      );
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealPlanDetailScreen(
            planId: newId,
            planName: '$planTitle — $studentName',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<bool?> _confirmPersonalize(BuildContext context, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Personalizar', style: TextStyle(color: Colors.white)),
        content: Text(
          message,
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Crear copia'),
          ),
        ],
      ),
    );
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

  void _showAddWeightDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Registrar Peso',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 24),
          decoration: const InputDecoration(
            hintText: '0.0',
            hintStyle: TextStyle(color: Colors.white30),
            suffixText: 'kg',
            suffixStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final weight = double.tryParse(
                controller.text.trim().replaceAll(',', '.'),
              );
              if (weight == null || weight <= 0) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(trainerServiceProvider)
                    .logStudentWeight(widget.studentId, weight);
                ref.invalidate(studentDetailProvider(widget.studentId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Peso registrado: ${weight}kg'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: AppColors.error,
                    ),
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

  Widget _buildWeightChart(Map<String, dynamic> student) {
    final bodyProgress = (student['body_progress'] as List?) ?? [];
    
    if (bodyProgress.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.show_chart_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
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
    final recentProgress = sortedProgress.length > 7
        ? sortedProgress.sublist(sortedProgress.length - 7)
        : sortedProgress;

    // Keep only entries that actually have a weight, so spot x-index and the
    // date labels below stay aligned (a null-weight entry would otherwise
    // shift every label).
    final plotted = recentProgress
        .where((e) => (e['body_weight'] as num?) != null)
        .toList();
    if (plotted.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = [
      for (int i = 0; i < plotted.length; i++)
        FlSpot(i.toDouble(), (plotted[i]['body_weight'] as num).toDouble()),
    ];

    // Calculate min/max for Y axis
    final weights = spots.map((s) => s.y).toList();
    final minY = (weights.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity);
    final maxY = weights.reduce((a, b) => a > b ? a : b) + 5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                    color: Colors.white.withValues(alpha: 0.05),
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
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= plotted.length) {
                          return const SizedBox.shrink();
                        }
                        final raw = (plotted[i]['date'] ??
                            plotted[i]['created_at']) as String?;
                        final d = raw != null ? DateTime.tryParse(raw) : null;
                        if (d == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${d.day}/${d.month}',
                            style: TextStyle(fontSize: 9, color: AppColors.textLight),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface,
                    tooltipBorder: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (plotted.length - 1).toDouble(),
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
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.primary.withValues(alpha: 0),
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

  Widget _buildIntakeCard(BuildContext context, String name) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IntakeViewScreen(
            athleteId: widget.studentId,
            athleteName: name,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.18),
              AppColors.primary.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.assignment_ind_outlined,
                  color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ficha del Atleta',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Respuestas del formulario inicial',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
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
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Icon(Icons.photo_camera_rounded, size: 48, color: Colors.white.withValues(alpha: 0.1)),
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
          
          return GestureDetector(
            onTap: photoUrl != null
                ? () => _showPhotoViewer(context, photoUrl)
                : null,
            child: Container(
              width: 100,
              margin: EdgeInsets.only(right: index < checkIns.length - 1 ? 12 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.surface,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image_rounded, color: Colors.grey),
                    )
                  : const Icon(Icons.photo_rounded, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }

  void _showPhotoViewer(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary),
                        ),
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_rounded,
                      color: Colors.grey,
                      size: 64),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityHistory(Map<String, dynamic> student) {
    // The app records workouts in workout_sessions (workout_logs is legacy
    // and never written)
    final workoutSessions = (student['workout_sessions'] as List?) ?? [];

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
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = today.subtract(Duration(days: 6 - index));

              final hasWorkout = workoutSessions.any((session) {
                if (session['is_completed'] != true) return false;
                final startedStr =
                    (session['started_at'] ?? session['created_at']) as String?;
                if (startedStr == null) return false;
                final started = DateTime.parse(startedStr).toLocal();
                return started.year == date.year &&
                    started.month == date.month &&
                    started.day == date.day;
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
                        ? AppColors.primary.withValues(alpha: 0.2) 
                        : Colors.white.withValues(alpha: 0.03),
                      shape: BoxShape.circle,
                      border: hasWorkout 
                        ? Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5)
                        : null,
                    ),
                    child: Icon(
                      hasWorkout ? Icons.local_fire_department_rounded : Icons.remove_rounded,
                      size: 18,
                      color: hasWorkout ? Colors.orange : Colors.white.withValues(alpha: 0.1),
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
    final completedWorkouts = ((student['workout_sessions'] as List?) ?? [])
        .where((s) => s['is_completed'] == true)
        .length;

    // Get current streak
    int currentStreak = 0;
    if (streaks.isNotEmpty) {
      final streakData = streaks.first as Map<String, dynamic>;
      currentStreak = (streakData['current_count'] as int?) ?? 0;

      // Live calculation for trainer view accuracy
      final lastWorkoutStr = streakData['last_activity_date'] as String?;
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
            value: '$completedWorkouts',
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
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.2),
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
                    color: AppColors.textLight.withValues(alpha: 0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: TextStyle(
                    color: hasValue ? Colors.white : Colors.white.withValues(alpha: 0.3),
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

  // -------- Renewal date helpers --------

  Widget _buildRenewalDateCard(
    BuildContext context,
    Map<String, dynamic> student,
  ) {
    final raw = student['next_renewal_date'] as String?;
    final renewalDate = raw != null ? DateTime.tryParse(raw) : null;

    String label;
    Color statusColor;
    IconData statusIcon;

    if (renewalDate == null) {
      label = 'Sin fecha asignada';
      statusColor = Colors.white.withValues(alpha: 0.3);
      statusIcon = Icons.event_busy_rounded;
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final renewalDay = DateTime(renewalDate.year, renewalDate.month, renewalDate.day);
      final daysLeft = renewalDay.difference(today).inDays;
      final dateLabel =
          '${renewalDate.day.toString().padLeft(2, '0')}/${renewalDate.month.toString().padLeft(2, '0')}/${renewalDate.year}';

      if (daysLeft <= 0) {
        label = 'Venció el $dateLabel';
        statusColor = AppColors.error;
        statusIcon = Icons.warning_rounded;
      } else if (daysLeft <= 5) {
        label = 'Vence en $daysLeft día${daysLeft == 1 ? '' : 's'} ($dateLabel)';
        statusColor = AppColors.error;
        statusIcon = Icons.warning_amber_rounded;
      } else if (daysLeft <= 14) {
        label = 'Vence el $dateLabel ($daysLeft días)';
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule_rounded;
      } else {
        label = 'Vence el $dateLabel ($daysLeft días)';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: renewalDate != null ? Colors.white : Colors.white.withValues(alpha: 0.3),
                fontWeight: renewalDate != null ? FontWeight.w600 : FontWeight.normal,
                fontStyle: renewalDate != null ? FontStyle.normal : FontStyle.italic,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditRenewalDateDialog(
    BuildContext context,
    Map<String, dynamic> student,
  ) async {
    final raw = student['next_renewal_date'] as String?;
    final initial =
        raw != null ? (DateTime.tryParse(raw) ?? DateTime.now()) : DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Seleccionar fecha de vencimiento',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked == null || !context.mounted) return;

    try {
      await ref.read(trainerServiceProvider).updateStudentRenewalDate(
        widget.studentId,
        picked,
      );
      // Refresh the student detail
      ref.invalidate(studentDetailProvider(widget.studentId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Fecha de vencimiento actualizada'),
            backgroundColor: AppColors.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showEditSupplementsDialog(
    BuildContext context,
    Map<String, dynamic> student,
  ) {
    final dailyController = TextEditingController(
      text: (student['daily_supplements'] as String?) ?? '',
    );
    final chemicalController = TextEditingController(
      text: (student['chemical_supplements'] as String?) ?? '',
    );

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
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white.withValues(alpha: 0.2), size: 32),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
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
