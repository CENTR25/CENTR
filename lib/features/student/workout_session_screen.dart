import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';
import '../../services/notification_service.dart';


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
  DateTime? _startTime;
  
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
  
  // Weights and Reps tracking
  final TextEditingController _weightController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _repsFocusNode = FocusNode();
  final Map<int, Map<int, double>> _recordedWeights = {}; // exerciseIndex -> {set -> weight}
  final Map<int, Map<int, int>> _recordedReps = {}; // exerciseIndex -> {set -> reps}
  
  // History
  Map<String, dynamic>? _lastSession;
  bool _isLoadingHistory = true;

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
    
    // Initialize Notification Service
    NotificationService().init();
    
    // Fetch history
    _fetchLastSession();
  }

  Future<void> _fetchLastSession() async {
    try {
      final service = ref.read(studentServiceProvider);
      final session = await service.getLastWorkoutSession(widget.routine['id'], widget.dayNumber);
      if (mounted) {
        setState(() {
          _lastSession = session;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
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
    _weightController.dispose();
    _weightFocusNode.dispose();
    _repsController.dispose();
    _repsFocusNode.dispose();
    NotificationService().cancelAll();
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
          _startTime = DateTime.now();
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

    // Initialize weight controller with target or last weight
    _updateWeightController();
  }

  Map<String, dynamic> _getLastLog() {
    if (_lastSession == null) return {};
    
    try {
      final setLogs = _lastSession!['set_logs'] as Map<String, dynamic>?;
      final repsLogs = _lastSession!['reps_logs'] as Map<String, dynamic>?;
      
      if (setLogs == null && repsLogs == null) return {};

      // Keys are strings in JSON: "0": {"1": 50.0}
      final exIndexStr = _currentExerciseIndex.toString();
      final setIndexStr = _currentSet.toString();

      final weightMap = setLogs?[exIndexStr] as Map<String, dynamic>?;
      final repsMap = repsLogs?[exIndexStr] as Map<String, dynamic>?;

      final weight = weightMap?[setIndexStr];
      final reps = repsMap?[setIndexStr];

      return {
        'weight': weight,
        'reps': reps,
      };
    } catch (e) {
      debugPrint('Error parsing last log: $e');
      return {};
    }
  }

  String _getCurrentTargetReps() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final targetRepsPattern = currentExercise['reps_target']?.toString() ?? '10';
    
    if (targetRepsPattern.contains('|')) {
      final repsList = targetRepsPattern.split('|').map((e) => e.trim()).toList();
      if (_currentSet <= repsList.length) {
        return repsList[_currentSet - 1];
      } else {
        return repsList.last;
      }
    }
    // Fallback for commas if mixed usage
    if (targetRepsPattern.contains(',')) {
      final repsList = targetRepsPattern.split(',').map((e) => e.trim()).toList();
      if (_currentSet <= repsList.length) {
        return repsList[_currentSet - 1];
      } else {
        return repsList.last;
      }
    }
    return targetRepsPattern;
  }

  void _updateWeightController() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final targetWeight = currentExercise['weight_target']?.toString() ?? '';
    final recordedWeight = _recordedWeights[_currentExerciseIndex]?[_currentSet]?.toString();
    
    _weightController.text = recordedWeight ?? targetWeight;

    // Use _getCurrentTargetReps() to get the specific target for this set
    final currentTargetReps = _getCurrentTargetReps();
    final recordedReps = _recordedReps[_currentExerciseIndex]?[_currentSet]?.toString();
    _repsController.text = recordedReps ?? currentTargetReps;
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

    // Schedule notification
    NotificationService().scheduleRestNotification(
      restSeconds, 
      '¡Descanso terminado!', 
      'Es hora de la siguiente serie. ¡Tú puedes!'
    );
    
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

    _updateWeightController();
    NotificationService().cancelAll();
  }

  void _skipRest() {
    _restTimer?.cancel();
    NotificationService().cancelAll();
    _endRest();
  }

  void _completeSet() {
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final reps = int.tryParse(_repsController.text) ?? 0;
    
    // Record weight
    if (!_recordedWeights.containsKey(_currentExerciseIndex)) {
      _recordedWeights[_currentExerciseIndex] = {};
    }
    _recordedWeights[_currentExerciseIndex]![_currentSet] = weight;

    // Record reps
    if (!_recordedReps.containsKey(_currentExerciseIndex)) {
      _recordedReps[_currentExerciseIndex] = {};
    }
    _recordedReps[_currentExerciseIndex]![_currentSet] = reps;

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

    // Save completed workout
    _saveWorkoutData(isCompleted: true);
  }

  void _saveWorkoutData({required bool isCompleted}) {
    final service = ref.read(studentServiceProvider);
    
    // Calculate total sets completed
    int setsCompleted = 0;
    _recordedWeights.forEach((_, sets) {
      setsCompleted += sets.length;
    });

    service.saveWorkoutSession({
      'routine_id': widget.routine['id'],
      'day_number': widget.dayNumber,
      'started_at': _startTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'duration_seconds': _totalStopwatch.elapsed.inSeconds,
      'sets_completed': setsCompleted,
      'is_completed': isCompleted,
      'set_logs': _recordedWeights.map((k, v) => MapEntry(k.toString(), v.map((k2, v2) => MapEntry(k2.toString(), v2)))),
      'reps_logs': _recordedReps.map((k, v) => MapEntry(k.toString(), v.map((k2, v2) => MapEntry(k2.toString(), v2)))),
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
    final notes = exercise['comment'];
    final restSeconds = (exercise['rest_seconds'] as int?) ?? 60;
    
    // Calculate progress
    final totalExercises = _orderedExercises.length;
    final exerciseProgress = (_currentExerciseIndex + (_currentSet - 1) / totalSets) / totalExercises;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Bar & Progress
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        onPressed: () => _showExitDialog(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      Column(
                        children: [
                          Text(
                            'EJERCICIO ${_currentExerciseIndex + 1} / $totalExercises',
                            style: TextStyle(
                              color: AppColors.textLight.withOpacity(0.5),
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      // Invisible button for balance
                       const SizedBox(width: 48),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: exerciseProgress,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Stats Row (Modern)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ModernStatItem(
                    label: 'SERIE',
                    value: '$_currentSet / $totalSets',
                    icon: Icons.layers_rounded,
                    color: AppColors.primaryLight,
                  ),
                  const SizedBox(width: 12),
                  _ModernStatItem(
                    label: 'OBJETIVO',
                    value: _getCurrentTargetReps(),
                    icon: Icons.track_changes,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 12),
                  _ModernStatItem(
                    label: 'DESCANSO',
                    value: '${restSeconds}s',
                    icon: Icons.timer_outlined,
                    color: AppColors.warning,
                  ),
                ],
              ),
            ),

            // 3. Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Video/Image Container
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: videoUrl != null
                          ? _VideoPlayerWidget(url: videoUrl)
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.white.withOpacity(0.05),
                                        Colors.white.withOpacity(0.02),
                                      ],
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.fitness_center_rounded,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ],
                            ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // History Info
                    _HistoryInfoRow(
                      lastLog: _getLastLog(),
                      isLoading: _isLoadingHistory,
                    ),
                          
                    // Inputs
                    Row(
                      children: [
                        Expanded(
                          child: _InputStatBox(
                            label: 'PESO (kg)',
                            controller: _weightController,
                            focusNode: _weightFocusNode,
                            color: AppColors.studentColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _InputStatBox(
                            label: 'REPS',
                            controller: _repsController,
                            focusNode: _repsFocusNode,
                            color: AppColors.success,
                            isInteger: true,
                          ),
                        ),
                      ],
                    ),

                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.info.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                notes,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textLight.withOpacity(0.9),
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),

                      /*
                    // Paused indicator
                    if (_isPaused)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pause_circle_rounded, color: AppColors.warning),
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
                    */
                  ],
                ),
              ),
            ),
            
            // 4. Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  /*
                  // Pause Button REMOVED
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: IconButton(
                      onPressed: _togglePause,
                      icon: Icon(
                        _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  */
                  // Finish Set Button
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isPaused ? null : _completeSet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent, 
                        ).copyWith(
                          elevation: WidgetStateProperty.all(8),
                          shadowColor: WidgetStateProperty.all(AppColors.success.withOpacity(0.4)),
                        ),
                        child: const Text(
                          'Terminar Serie',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
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
            const Expanded(
              child: Text(
                '¿Abandonar entrenamiento?',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu progreso actual:',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
    _saveWorkoutData(isCompleted: false);
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
          Text(
            value, 
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Color color;
  final bool isEditable;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const _ExerciseStatRow({
    required this.icon,
    required this.label,
    this.value,
    required this.color,
    this.isEditable = false,
    this.controller,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEditable && focusNode != null ? () => focusNode!.requestFocus() : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isEditable && controller != null)
                Container(
                  width: 120,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.5)),
                  ),
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    cursorColor: color,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      hintStyle: TextStyle(color: color.withOpacity(0.3)),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      suffixText: ' kg',
                      suffixStyle: TextStyle(
                        color: color.withOpacity(0.5),
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                )
              else
                Text(
                  value ?? '',
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return content;
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
  late VideoPlayerController _videoController;
  late YoutubePlayerController _youtubeController;
  
  bool _initialized = false;
  bool _isGif = false;
  bool _isYoutube = false;

  @override
  void initState() {
    super.initState();
    final lowerUrl = widget.url.toLowerCase();
    
    _isGif = lowerUrl.endsWith('.gif');
    _isYoutube = lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be');

    if (_isYoutube) {
      final videoId = YoutubePlayerController.convertUrlToId(widget.url);
      
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: videoId ?? '',
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: false,
          showFullscreenButton: false,
          mute: true,
          loop: true,
        ),
      );
      
      // Iframe controller doesn't need explicit initialization check like video_player
      // but we set initialized to true to show the widget
      setState(() => _initialized = true);
      
    } else if (!_isGif) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _initialized = true);
            _videoController.setLooping(true);
            _videoController.play();
          }
        });
    }
  }

  @override
  void dispose() {
    if (_isYoutube) {
      _youtubeController.close();
    } else if (!_isGif) {
      _videoController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isGif) {
      return Image.network(
        widget.url,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
             child: CircularProgressIndicator(color: Colors.white),
          );
        },
        errorBuilder: (context, error, stackTrace) {
           return const Center(
             child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
           );
        },
      );
    }

    if (_isYoutube) {
       return YoutubePlayer(
          controller: _youtubeController,
          aspectRatio: 16 / 9,
       );
    }

    if (!_initialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    return AspectRatio(
      aspectRatio: _videoController.value.aspectRatio,
      child: VideoPlayer(_videoController),
    );
  }
}








class _ModernStatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ModernStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900, // Thicker font
            ),
          ),
        ],
      ),
    );
  }
}

class _InputStatBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  final bool isInteger;

  const _InputStatBox({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.color,
    this.isInteger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceVariant.withOpacity(0.6),
            AppColors.surfaceVariant.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.numberWithOptions(decimal: !isInteger),
                textAlign: TextAlign.center,
                cursorColor: color,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32, // Larger text
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryInfoRow extends StatelessWidget {
  final Map<String, dynamic> lastLog;
  final bool isLoading;

  const _HistoryInfoRow({
    required this.lastLog,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SizedBox();
    
    final weight = lastLog['weight'];
    final reps = lastLog['reps'];
    
    // If no history found for this specific set
    if (weight == null && reps == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Primera vez en esta serie',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history, color: AppColors.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            'ANTERIOR: ',
            style: TextStyle(
              color: AppColors.accent.withOpacity(0.8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            '${weight ?? '-'} kg  /  ${reps ?? '-'} reps',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
