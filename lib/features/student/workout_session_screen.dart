import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_theme.dart';

/// Workout Session Screen - Guided workout experience
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> routine;
  final List<Map<String, dynamic>> exercises;
  final int dayNumber;

  const WorkoutSessionScreen({
    super.key,
    required this.routine,
    required this.exercises,
    required this.dayNumber,
  });

  @override
  ConsumerState<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> 
    with TickerProviderStateMixin {
  
  // Workout state
  late List<Map<String, dynamic>> _orderedExercises;
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  bool _isResting = false;
  bool _isPaused = false;
  bool _isCountingDown = true;
  bool _isCompleted = false;
  int _countdownValue = 3;
  
  // Timers
  Timer? _restTimer;
  Timer? _countdownTimer;
  Timer? _elapsedTimer; // For updating elapsed time display
  int _restSecondsRemaining = 0;
  
  // Time tracking
  final Stopwatch _totalStopwatch = Stopwatch();
  final Stopwatch _restStopwatch = Stopwatch();
  Duration _totalRestTime = Duration.zero;
  
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Animation
  late AnimationController _countdownController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _orderedExercises = List.from(widget.exercises);
    _orderedExercises.sort((a, b) => 
      (a['order_index'] as int).compareTo(b['order_index'] as int));
    
    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeOut),
    );
    
    _startInitialCountdown();
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _totalStopwatch.stop();
    _restStopwatch.stop();
    _audioPlayer.dispose();
    _countdownController.dispose();
    super.dispose();
  }

  void _startInitialCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownController.reset();
      _countdownController.forward();
      _playBeep();
      
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _totalStopwatch.start();
        });
        // Start elapsed time display timer - always update UI
        _startElapsedTimer();
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {}); // Force UI refresh to update elapsed time
      }
    });
  }

  void _playBeep() async {
    try {
      // Using a simple system sound URL for web compatibility
      await _audioPlayer.play(UrlSource(
        'https://actions.google.com/sounds/v1/cartoon/cartoon_boing.ogg'
      ));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  void _playAlertSound() async {
    try {
      await _audioPlayer.play(UrlSource(
        'https://actions.google.com/sounds/v1/alarms/beep_short.ogg'
      ));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  void _startRest() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final restSeconds = (currentExercise['rest_seconds'] as int?) ?? 60;
    
    setState(() {
      _isResting = true;
      _restSecondsRemaining = restSeconds;
    });
    
    _restStopwatch.start();
    
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;
      
      setState(() {
        _restSecondsRemaining--;
      });
      
      // Play alert at 10 seconds
      if (_restSecondsRemaining == 10) {
        _playAlertSound();
      }
      
      // Beep for last 3 seconds
      if (_restSecondsRemaining <= 3 && _restSecondsRemaining > 0) {
        _playBeep();
      }
      
      if (_restSecondsRemaining <= 0) {
        timer.cancel();
        _endRest();
      }
    });
  }

  void _endRest() {
    _restStopwatch.stop();
    _totalRestTime += _restStopwatch.elapsed;
    _restStopwatch.reset();
    
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final totalSets = (currentExercise['sets'] as int?) ?? 3;
    
    setState(() {
      _isResting = false;
      
      if (_currentSet < totalSets) {
        _currentSet++;
      } else {
        _currentSet = 1;
        if (_currentExerciseIndex < _orderedExercises.length - 1) {
          _currentExerciseIndex++;
        } else {
          _completeWorkout();
        }
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _endRest();
  }

  void _completeSet() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final totalSets = (currentExercise['sets'] as int?) ?? 3;
    
    if (_currentSet < totalSets) {
      _startRest();
    } else {
      // Last set of this exercise
      if (_currentExerciseIndex < _orderedExercises.length - 1) {
        _startRest();
      } else {
        _completeWorkout();
      }
    }
  }

  void _completeWorkout() {
    _totalStopwatch.stop();
    setState(() {
      _isCompleted = true;
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _totalStopwatch.stop();
        _restStopwatch.stop();
      } else {
        _totalStopwatch.start();
        if (_isResting) _restStopwatch.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCountingDown) {
      return _buildCountdownView();
    }
    
    if (_isCompleted) {
      return _buildSummaryView();
    }
    
    if (_isResting) {
      return _buildRestView();
    }
    
    return _buildExerciseView();
  }

  Widget _buildCountdownView() {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                _countdownValue == 0 ? '¡GO!' : '$_countdownValue',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildExerciseView() {
    final exercise = _orderedExercises[_currentExerciseIndex];
    final exerciseData = exercise['exercises'] as Map<String, dynamic>;
    final name = exerciseData['name'] ?? 'Ejercicio';
    final videoUrl = exerciseData['video_url'] as String?;
    final totalSets = (exercise['sets'] as int?) ?? 3;
    final reps = exercise['reps_target'] ?? '10';
    final notes = exercise['comment'];
    final restSeconds = (exercise['rest_seconds'] as int?) ?? 60;
    
    // Calculate progress
    final totalExercises = _orderedExercises.length;
    final exerciseProgress = (_currentExerciseIndex + (_currentSet - 1) / totalSets) / totalExercises;

    return Scaffold(
      body: Column(
        children: [
          // Gradient header with video/placeholder
          Container(
            height: MediaQuery.of(context).size.height * 0.4,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark,
                  AppColors.primary,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => _showExitDialog(),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ejercicio ${_currentExerciseIndex + 1} de $totalExercises',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Elapsed time display
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                _formatDuration(_totalStopwatch.elapsed),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: exerciseProgress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  
                  // Video or icon
                  Expanded(
                    child: Center(
                      child: videoUrl != null 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.85,
                              child: _VideoPlayerWidget(url: videoUrl),
                            ),
                          )
                        : Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: const Icon(
                              Icons.fitness_center,
                              size: 56,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              transform: Matrix4.translationValues(0, -24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Exercise name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Sets/Reps info cards
                  Row(
                    children: [
                      Expanded(
                        child: _ExerciseInfoCard(
                          icon: Icons.refresh,
                          title: 'Serie',
                          value: '$_currentSet / $totalSets',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExerciseInfoCard(
                          icon: Icons.repeat,
                          title: 'Repeticiones',
                          value: '$reps',
                          color: AppColors.accent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ExerciseInfoCard(
                          icon: Icons.timer_outlined,
                          title: 'Descanso',
                          value: '${restSeconds}s',
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.tips_and_updates, color: AppColors.info, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              notes,
                              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  const Spacer(),
                  
                  // Paused indicator
                  if (_isPaused)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pause_circle, color: AppColors.warning),
                          SizedBox(width: 8),
                          Text(
                            'PAUSADO',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Pause/Resume button row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _togglePause,
                          icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(_isPaused ? 'Reanudar' : 'Pausar'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Complete button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _isPaused ? null : _completeSet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 24),
                          SizedBox(width: 12),
                          Text(
                            'Serie Completada',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
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

  void _showExitDialog() {
    _togglePause(); // Pause while showing dialog
    final elapsed = _totalStopwatch.elapsed;
    final completedSets = (_currentExerciseIndex * 4) + _currentSet - 1; // Approximate
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('¿Abandonar entrenamiento?')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu progreso actual:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _ExitStatRow(icon: Icons.timer, label: 'Tiempo', value: _formatDuration(elapsed)),
            _ExitStatRow(icon: Icons.fitness_center, label: 'Series', value: '$completedSets completadas'),
            _ExitStatRow(icon: Icons.directions_run, label: 'Ejercicio', value: '${_currentExerciseIndex + 1} de ${_orderedExercises.length}'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.error, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este progreso se guardará como incompleto.',
                      style: TextStyle(fontSize: 13, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _togglePause(); // Resume
            },
            child: const Text('Continuar'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveIncompleteWorkout();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Abandonar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveIncompleteWorkout() async {
    // TODO: Save to Supabase workout_sessions table
    // Fields: athlete_id, routine_id, started_at, duration, sets_completed, is_completed
    debugPrint('📊 Saving incomplete workout:');
    debugPrint('   Duration: ${_totalStopwatch.elapsed}');
    debugPrint('   Exercise: ${_currentExerciseIndex + 1}/${_orderedExercises.length}');
    debugPrint('   Set: $_currentSet');
    debugPrint('   Rest time: $_totalRestTime');
  }

  Widget _buildRestView() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final totalRest = (currentExercise['rest_seconds'] as int?) ?? 60;
    final progress = _restSecondsRemaining / totalRest;
    final totalSets = (currentExercise['sets'] as int?) ?? 3;
    
    // Get next exercise info
    final exerciseData = currentExercise['exercises'] as Map<String, dynamic>;
    final currentName = exerciseData['name'] ?? 'Ejercicio';
    String nextInfo;
    if (_currentSet < totalSets) {
      nextInfo = 'Serie ${_currentSet + 1} de $totalSets';
    } else if (_currentExerciseIndex < _orderedExercises.length - 1) {
      final nextExercise = _orderedExercises[_currentExerciseIndex + 1];
      final nextData = nextExercise['exercises'] as Map<String, dynamic>;
      nextInfo = nextData['name'] ?? 'Siguiente ejercicio';
    } else {
      nextInfo = '¡Último esfuerzo!';
    }

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _restSecondsRemaining <= 10 
                ? AppColors.warning.withValues(alpha: 0.9)
                : AppColors.primary.withValues(alpha: 0.9),
              _restSecondsRemaining <= 10 
                ? AppColors.warning 
                : AppColors.primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    const Text(
                      'DESCANSO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                      ),
                      onPressed: _togglePause,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Circular timer - centered and large
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow effect
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.2),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  // Progress ring
                  SizedBox(
                    width: 250,
                    height: 250,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 14,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  // Timer text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_restSecondsRemaining',
                        style: const TextStyle(
                          fontSize: 80,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'segundos',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Next up info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'A continuación',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _currentSet < totalSets ? currentName : nextInfo,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_currentSet < totalSets)
                            Text(
                              nextInfo,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Paused indicator
              if (_isPaused)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pause_circle_outline, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'PAUSADO',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Skip button
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: _skipRest,
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    label: const Text(
                      'Saltar descanso',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryView() {
    final totalTime = _totalStopwatch.elapsed;
    final workoutTime = totalTime - _totalRestTime;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.emoji_events,
                size: 80,
                color: AppColors.warning,
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                '¡Entrenamiento Completado!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                widget.routine['title'] ?? 'Rutina',
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatCard(
                    icon: Icons.timer,
                    value: _formatDuration(totalTime),
                    label: 'Tiempo Total',
                  ),
                  _StatCard(
                    icon: Icons.fitness_center,
                    value: _formatDuration(workoutTime),
                    label: 'Ejercicio',
                  ),
                  _StatCard(
                    icon: Icons.pause_circle,
                    value: _formatDuration(_totalRestTime),
                    label: 'Descansos',
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Finalizar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
}

// Helper widgets

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ExitStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ExitStatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ExerciseInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ExerciseInfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 32, color: AppColors.primary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _VideoPlayerWidget extends StatefulWidget {
  final String url;

  const _VideoPlayerWidget({required this.url});

  @override
  State<_VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<_VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        setState(() => _initialized = true);
        _controller.setLooping(true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}
