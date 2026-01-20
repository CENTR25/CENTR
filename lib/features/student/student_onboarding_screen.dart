import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/auth_service.dart';

class StudentOnboardingScreen extends ConsumerStatefulWidget {
  const StudentOnboardingScreen({super.key});

  @override
  ConsumerState<StudentOnboardingScreen> createState() => _StudentOnboardingScreenState();
}

class _StudentOnboardingScreenState extends ConsumerState<StudentOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Data
  double _weight = 70.0;
  double _height = 170.0;
  String? _goal;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    setState(() => _isLoading = true);
    try {
      final studentService = ref.read(studentServiceProvider);
      
      // Update profile and log initial metrics
      await studentService.completeOnboarding(
        weight: _weight,
        height: _height,
        goal: _goal,
      );

      // Refresh user profile so router knows onboarding is complete
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) {
        context.go('/student');
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index <= _currentPage 
                            ? AppColors.studentColor 
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildHeightPage(),
                  _buildWeightPage(),
                  _buildGoalPage(),
                ],
              ),
            ),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _prevPage,
                      child: const Text('Atrás', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  else
                    const SizedBox(width: 80),

                  if (_currentPage < 3)
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.studentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Siguiente'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoading ? null : _finishOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('¡Comenzar!'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.studentColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center_rounded, size: 80, color: AppColors.studentColor),
          ),
          const SizedBox(height: 32),
          const Text(
            '¡Bienvenido a tu Transformación!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Vamos a configurar tu perfil para personalizar tu experiencia. Solo tomará un minuto.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHeightPage() {
    return _OnboardingStep(
      title: '¿Cuál es tu altura?',
      description: 'Esto nos ayuda a calcular tus métricas corporales.',
      child: Column(
        children: [
          Text(
            '${_height.toStringAsFixed(0)} cm',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.studentColor),
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Visual Ruler representation could go here
                RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.studentColor,
                      thumbColor: AppColors.studentColor,
                      overlayColor: AppColors.studentColor.withOpacity(0.2),
                      trackHeight: 12,
                    ),
                    child: Slider(
                      value: _height,
                      min: 100,
                      max: 250,
                      onChanged: (val) => setState(() => _height = val),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightPage() {
    return _OnboardingStep(
      title: '¿Cuál es tu peso actual?',
      description: 'El punto de partida para medir tu progreso.',
      child: Column(
        children: [
          Text(
            '${_weight.toStringAsFixed(1)} kg',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: AppColors.studentColor),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.studentColor,
                thumbColor: AppColors.studentColor,
                trackHeight: 12,
              ),
              child: Slider(
                value: _weight,
                min: 30,
                max: 200,
                onChanged: (val) => setState(() => _weight = val),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Icon(Icons.monitor_weight_outlined, size: 100, color: AppColors.textLight.withOpacity(0.2)),
        ],
      ),
    );
  }

  Widget _buildGoalPage() {
    final goals = ['Perder Peso', 'Ganar Músculo', 'Mantenerme', 'Mejorar Rendimiento'];
    
    return _OnboardingStep(
      title: '¿Cuál es tu objetivo principal?',
      description: 'Tu entrenador adaptará el plan a esto.',
      child: Column(
        children: goals.map((goal) {
          final isSelected = _goal == goal;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => _goal = goal),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.studentColor : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.studentColor : AppColors.surfaceVariant,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? Colors.white : AppColors.textLight,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      goal,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Expanded(child: child),
        ],
      ),
    );
  }
}
