import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/theme_redesign.dart';
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

  // Text controllers so height/weight can be typed exactly (sliders are
  // liked but imprecise). Kept in sync with the sliders below.
  late final TextEditingController _heightCtrl =
      TextEditingController(text: _height.toStringAsFixed(0));
  late final TextEditingController _weightCtrl =
      TextEditingController(text: _weight.toStringAsFixed(1));

  @override
  void dispose() {
    _pageController.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  /// Big centered number that doubles as a text input, with a unit suffix.
  Widget _valueField({
    required TextEditingController controller,
    required String unit,
    required double min,
    required double max,
    required ValueChanged<double> onValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        IntrinsicWidth(
          child: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: RedesignColors.actionPrimaryDark,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (t) {
              final v = double.tryParse(t.replaceAll(',', '.'));
              if (v != null && v >= min && v <= max) onValue(v);
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          unit,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: RedesignColors.actionPrimaryDark.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
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
          SnackBar(content: Text('Error: $e'), backgroundColor: RedesignColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
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
                              ? RedesignColors.actionPrimary
                              : RedesignColors.primario700,
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
                        child: const Text('Atrás', style: TextStyle(color: RedesignColors.primario300)),
                      )
                    else
                      const SizedBox(width: 80),

                    if (_currentPage < 3)
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RedesignColors.actionPrimary,
                          foregroundColor: RedesignColors.onActionPrimary,
                          minimumSize: const Size(0, 52), // override theme's full-width min (we're in a Row)
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: const Text('Siguiente'),
                      )
                    else
                      ElevatedButton(
                        onPressed: _isLoading ? null : _finishOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: RedesignColors.actionPrimary,
                          foregroundColor: RedesignColors.onActionPrimary,
                          minimumSize: const Size(0, 52), // override theme's full-width min (we're in a Row)
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: RedesignColors.onActionPrimary, strokeWidth: 2))
                            : const Text('¡Comenzar!'),
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

  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: RedesignColors.actionPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.fitness_center_rounded, size: 80, color: RedesignColors.actionPrimary),
          ),
          const SizedBox(height: 32),
          const Text(
            '¡Bienvenido a tu Transformación!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: RedesignColors.primario50),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Vamos a configurar tu perfil para personalizar tu experiencia. Solo tomará un minuto.',
            style: TextStyle(color: RedesignColors.primario300, fontSize: 16),
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
          _valueField(
            controller: _heightCtrl,
            unit: 'cm',
            min: 100,
            max: 250,
            onValue: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 300,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotatedBox(
                  quarterTurns: -1,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: RedesignColors.actionPrimary,
                      thumbColor: RedesignColors.actionPrimary,
                      overlayColor: RedesignColors.actionPrimary.withValues(alpha: 0.2),
                      trackHeight: 12,
                    ),
                    child: Slider(
                      value: _height,
                      min: 100,
                      max: 250,
                      onChanged: (val) => setState(() {
                        _height = val;
                        _heightCtrl.text = val.toStringAsFixed(0);
                      }),
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
          _valueField(
            controller: _weightCtrl,
            unit: 'kg',
            min: 30,
            max: 200,
            onValue: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: RedesignColors.actionPrimary,
                thumbColor: RedesignColors.actionPrimary,
                trackHeight: 12,
              ),
              child: Slider(
                value: _weight,
                min: 30,
                max: 200,
                onChanged: (val) => setState(() {
                  _weight = val;
                  _weightCtrl.text = val.toStringAsFixed(1);
                }),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Icon(Icons.monitor_weight_outlined, size: 100, color: RedesignColors.primario400.withValues(alpha: 0.2)),
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
                  color: isSelected ? RedesignColors.actionPrimary : RedesignColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? RedesignColors.actionPrimary : RedesignColors.primario700,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.circle_outlined,
                      color: isSelected ? RedesignColors.onActionPrimary : RedesignColors.primario400,
                    ),
                    const SizedBox(width: 16),
                    Text(
                      goal,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? RedesignColors.onActionPrimary : RedesignColors.primario50,
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
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: RedesignColors.primario50),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(color: RedesignColors.primario300, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Expanded(child: child),
        ],
      ),
    );
  }
}
