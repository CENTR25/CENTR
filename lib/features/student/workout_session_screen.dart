import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/student_service.dart';
import '../../services/active_workout_service.dart';
import '../../services/workout_draft_service.dart';
import '../../services/notification_service.dart';
import 'exercise_detail_screen.dart';
import 'student_workout_history_screen.dart';
import 'widgets/student_bottom_nav.dart';

const _monthAbbr = [
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Workout Session Screen — PRGS navy/teal redesign (Figma). Guided workout:
/// per-set logging, rest timer, "Series de hoy" + edit modal. All timer/audio/
/// lifecycle/persistence logic is preserved from the original implementation.
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
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Workout state
  late List<Map<String, dynamic>> _orderedExercises;
  // Visit order as indices into _orderedExercises. Skipping an exercise moves
  // its index to the end here, so _orderedExercises (and the position-keyed
  // recorded/history maps) stay stable. _currentExerciseIndex is always
  // _visitOrder[_visitPos].
  late List<int> _visitOrder;
  int _visitPos = 0;
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
  Timer? _elapsedTimer;

  // Rest timer — wall-clock deadline is the source of truth so background /
  // lock-screen suspension never drifts. _restSecondsRemaining is a derived
  // display value recomputed each tick from the deadline, not a counter.
  DateTime? _restDeadline; // absolute moment the rest ends
  DateTime? _restPausedAt; // non-null while the timer is paused
  int _restSecondsRemaining = 0; // recomputed; kept for display / progress bar

  // Background tracking (fix timer drift)
  DateTime? _backgroundEnterTime;
  Duration _stopwatchAtBackground = Duration.zero;

  // Time tracking
  final Stopwatch _totalStopwatch = Stopwatch();
  final Stopwatch _restStopwatch = Stopwatch();
  Duration _totalRestTime = Duration.zero;
  // Stopwatch freezes while iOS/Android suspend the app (locked screen between
  // sets), so background time is accumulated separately on resume.
  Duration _backgroundTime = Duration.zero;
  // Frozen snapshot captured at completion — null while the workout is live.
  Duration? _completedElapsed;
  Duration? _completedRestTime;

  Duration get _totalElapsed => _totalStopwatch.elapsed + _backgroundTime;

  // Audio — duck (lower) the athlete's music for the beep instead of pausing
  // it. iOS -> playback + duckOthers; Android -> gainTransientMayDuck. Web
  // ignores this and mixes by default. respectSilence:false so the timer alert
  // still fires on silent/vibrate in a loud gym.
  final AudioPlayer _audioPlayer = AudioPlayer()
    ..setAudioContext(
      AudioContextConfig(
        focus: AudioContextConfigFocus.duckOthers,
        respectSilence: false,
      ).build(),
    );

  // Animation
  late AnimationController _countdownController;
  late Animation<double> _scaleAnimation;

  // Weights and Reps tracking
  final TextEditingController _weightController = TextEditingController();
  final FocusNode _weightFocusNode = FocusNode();
  final TextEditingController _repsController = TextEditingController();
  final FocusNode _repsFocusNode = FocusNode();
  final Map<int, Map<int, double>> _recordedWeights = {}; // ex -> {set -> kg}
  final Map<int, Map<int, int>> _recordedReps = {}; // ex -> {set -> reps}

  // Local draft persistence — survives the OS killing the app mid-workout.
  final WorkoutDraftService _draftService = WorkoutDraftService();
  String get _routineId => widget.routine['id'].toString();

  // History
  List<Map<String, dynamic>> _recentSessions = [];
  bool _isLoadingHistory = true;

  // Just-completed set tracking (for rest view)
  double? _justCompletedWeight;
  int? _justCompletedReps;

  @override
  void initState() {
    super.initState();
    _orderedExercises = List.from(widget.exercises);
    _orderedExercises.sort(
        (a, b) => (a['order_index'] as int).compareTo(b['order_index'] as int));
    _visitOrder = List<int>.generate(_orderedExercises.length, (i) => i);

    _countdownController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.5).animate(
      CurvedAnimation(parent: _countdownController, curve: Curves.easeOut),
    );

    // Live-refresh the reps mismatch warning as the athlete types.
    _repsController.addListener(() {
      if (mounted) setState(() {});
    });

    _startInitialCountdown();

    // Mark this workout as in progress so the home screen can offer to resume
    // it until it's completed.
    ref.read(activeWorkoutProvider.notifier).start(
          ActiveWorkout(
            routineId: widget.routine['id'].toString(),
            dayNumber: widget.dayNumber,
            routineName: (widget.routine['name'] as String?) ?? '',
          ),
        );

    WidgetsBinding.instance.addObserver(this);
    NotificationService().init();
    _fetchLastSession();
    _restoreDraft();
  }

  /// Restore an in-progress draft left behind when the OS killed the app
  /// mid-workout. Discards drafts that no longer match the routine (trainer
  /// edited it) or that are stale (> 24 h old).
  Future<void> _restoreDraft() async {
    final draft = await _draftService.load(_routineId, widget.dayNumber);
    if (draft == null || !mounted) return;

    final stale =
        DateTime.now().difference(draft.savedAt) > const Duration(hours: 24);
    if (draft.exerciseCount != _orderedExercises.length || stale) {
      await _draftService.clear(_routineId, widget.dayNumber);
      return;
    }
    if (!mounted) return;

    setState(() {
      _recordedWeights
        ..clear()
        ..addAll(draft.recordedWeights);
      _recordedReps
        ..clear()
        ..addAll(draft.recordedReps);
      if (draft.visitOrder.length == _orderedExercises.length) {
        _visitOrder = List<int>.from(draft.visitOrder);
      }
      _visitPos = draft.visitPos.clamp(0, _visitOrder.length - 1);
      _currentExerciseIndex = _visitOrder[_visitPos];
      _currentSet = draft.currentSet < 1 ? 1 : draft.currentSet;
      if (draft.startedAt != null) {
        _startTime = DateTime.tryParse(draft.startedAt!) ?? _startTime;
      }
    });

    // Pre-fill the inputs: target/recorded value first, then whatever was
    // typed but not yet submitted when the app died.
    _updateWeightController();
    if (draft.pendingWeight.isNotEmpty) {
      _weightController.text = draft.pendingWeight;
    }
    if (draft.pendingReps.isNotEmpty) {
      _repsController.text = draft.pendingReps;
    }
  }

  /// Persist the current in-progress state so it survives the app being killed.
  /// Fire-and-forget — SharedPreferences writes are fast and must not block the
  /// UI or the timer loop.
  void _saveDraft() {
    if (_isCompleted) return;

    // During rest the set that was just logged is in the recorded maps, but
    // _currentSet only advances when the timer ends (_endRest). A draft saved
    // now must point at the NEXT set — otherwise a kill during the countdown
    // restores the athlete onto the set they already completed. Mirror the
    // advancement _endRest will do, and drop the pending text (it belongs to
    // the finished set, not the one being restored into).
    var visitPos = _visitPos;
    var currentSet = _currentSet;
    var pendingWeight = _weightController.text;
    var pendingReps = _repsController.text;
    if (_isResting) {
      final totalSets =
          (_orderedExercises[_currentExerciseIndex]['sets'] as int?) ?? 3;
      if (_currentSet < totalSets) {
        currentSet = _currentSet + 1;
      } else if (_visitPos < _visitOrder.length - 1) {
        visitPos = _visitPos + 1;
        currentSet = 1;
      }
      pendingWeight = '';
      pendingReps = '';
    }

    unawaited(_draftService.save(WorkoutDraft(
      routineId: _routineId,
      dayNumber: widget.dayNumber,
      startedAt: _startTime?.toIso8601String(),
      exerciseCount: _orderedExercises.length,
      visitOrder: _visitOrder,
      visitPos: visitPos,
      currentSet: currentSet,
      recordedWeights: _recordedWeights,
      recordedReps: _recordedReps,
      pendingWeight: pendingWeight,
      pendingReps: pendingReps,
      savedAt: DateTime.now(),
    )));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isCompleted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundEnterTime = DateTime.now();
      _stopwatchAtBackground = _totalStopwatch.elapsed;
      // Flush a draft now — the OS may kill us while backgrounded. Captures
      // even a half-typed set via the current text-field values.
      _saveDraft();
    } else if (state == AppLifecycleState.resumed &&
        _backgroundEnterTime != null) {
      final bgDuration = DateTime.now().difference(_backgroundEnterTime!);
      _backgroundEnterTime = null;

      // Accumulate background time in the total-elapsed counter (Stopwatch
      // freezes while the OS suspends Dart execution).
      final ticked = _totalStopwatch.elapsed - _stopwatchAtBackground;
      final frozen = bgDuration - ticked;
      if (_totalStopwatch.isRunning && frozen > Duration.zero) {
        _backgroundTime += frozen;
        if (_isResting && !_isPaused) {
          _totalRestTime += Duration(
            seconds: frozen.inSeconds.clamp(0, _restSecondsRemaining),
          );
        }
      }

      // Rest-timer correction: the deadline is an absolute DateTime, so no
      // arithmetic on _restSecondsRemaining is needed here. We simply
      // recompute the remaining seconds from the deadline and act on it —
      // the periodic timer will do the same when it next fires, but we do it
      // immediately on resume so the display is accurate right away.
      if (_isResting && !_isPaused && mounted && _restDeadline != null) {
        final remaining = _restDeadline!.difference(DateTime.now()).inSeconds;
        if (remaining <= 0) {
          _restTimer?.cancel();
          setState(() => _restSecondsRemaining = 0);
          _endRest();
        } else {
          setState(() => _restSecondsRemaining = remaining);
        }
      } else if (mounted) {
        // Not resting: refresh the elapsed-time display right away.
        setState(() {});
      }
    }
  }

  Future<void> _fetchLastSession() async {
    try {
      final service = ref.read(studentServiceProvider);
      // Fetch sessions across ALL days — history is per exercise_id, not per day.
      final recent = await service.getRecentWorkoutSessions(
          widget.routine['id'],
          limit: 4);
      if (mounted) {
        setState(() {
          _recentSessions = recent;
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startInitialCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownController.reset();
      _countdownController.forward();

      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
      } else {
        timer.cancel();
        setState(() {
          _isCountingDown = false;
          _totalStopwatch.start();
          // Keep the original start time if a draft was restored.
          _startTime ??= DateTime.now();
        });
        _startElapsedTimer();
      }
    });
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _updateWeightController();
  }

  String _getCurrentTargetReps() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final targetRepsPattern =
        currentExercise['reps_target']?.toString() ?? '10';

    if (targetRepsPattern.contains('|')) {
      final repsList =
          targetRepsPattern.split('|').map((e) => e.trim()).toList();
      return _currentSet <= repsList.length
          ? repsList[_currentSet - 1]
          : repsList.last;
    }
    if (targetRepsPattern.contains(',')) {
      final repsList =
          targetRepsPattern.split(',').map((e) => e.trim()).toList();
      return _currentSet <= repsList.length
          ? repsList[_currentSet - 1]
          : repsList.last;
    }
    return targetRepsPattern;
  }

  void _updateWeightController() {
    final recordedWeight =
        _recordedWeights[_currentExerciseIndex]?[_currentSet]?.toString();
    _weightController.text = recordedWeight ?? '';

    final recordedReps =
        _recordedReps[_currentExerciseIndex]?[_currentSet]?.toString();
    _repsController.text = recordedReps ?? '';
  }

  void _playBeep() async {
    try {
      await _audioPlayer.play(UrlSource(
          'https://actions.google.com/sounds/v1/cartoon/cartoon_boing.ogg'));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  void _playAlertSound() async {
    try {
      await _audioPlayer.play(UrlSource(
          'https://actions.google.com/sounds/v1/alarms/beep_short.ogg'));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }
  }

  void _startRest() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final restSeconds = (currentExercise['rest_seconds'] as int?) ?? 60;

    _restDeadline = DateTime.now().add(Duration(seconds: restSeconds));
    _restPausedAt = null;

    setState(() {
      _isResting = true;
      _restSecondsRemaining = restSeconds;
    });

    // The set that just finished is now in the recorded maps — persist it so a
    // kill during rest doesn't lose it. (Only reached on non-final sets, so it
    // never races the draft clear in _completeWorkout.)
    _saveDraft();

    NotificationService().scheduleRestNotification(restSeconds,
        '¡Descanso terminado!', 'Es hora de la siguiente serie. ¡Tú puedes!');

    _restStopwatch.start();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      // Recompute from the wall-clock deadline on every tick — this is immune
      // to the periodic timer being throttled or delayed by the OS when the
      // screen is locked, because we never decrement a counter; we measure.
      final remaining = _restDeadline!.difference(DateTime.now()).inSeconds;

      if (!mounted) {
        timer.cancel();
        return;
      }

      // Fire audio cues based on the just-computed remaining time.
      if (remaining == 10) _playAlertSound();
      if (remaining <= 3 && remaining > 0) _playBeep();

      if (remaining <= 0) {
        timer.cancel();
        setState(() => _restSecondsRemaining = 0);
        _endRest();
      } else {
        setState(() => _restSecondsRemaining = remaining);
      }
    });
  }

  void _endRest() {
    _restStopwatch.stop();
    _totalRestTime += _restStopwatch.elapsed;
    _restStopwatch.reset();
    _restDeadline = null;
    _restPausedAt = null;

    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final totalSets = (currentExercise['sets'] as int?) ?? 3;
    setState(() {
      _isResting = false;

      if (_currentSet < totalSets) {
        _currentSet++;
      } else {
        _currentSet = 1;
        if (_visitPos < _visitOrder.length - 1) {
          _visitPos++;
          _currentExerciseIndex = _visitOrder[_visitPos];
        } else {
          _completeWorkout();
        }
      }
    });

    _updateWeightController();
    _saveDraft();
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

    _justCompletedWeight = weight;
    _justCompletedReps = reps;

    _recordedWeights.putIfAbsent(_currentExerciseIndex, () => {});
    _recordedWeights[_currentExerciseIndex]![_currentSet] = weight;
    _recordedReps.putIfAbsent(_currentExerciseIndex, () => {});
    _recordedReps[_currentExerciseIndex]![_currentSet] = reps;

    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final totalSets = (currentExercise['sets'] as int?) ?? 3;

    if (_currentSet < totalSets) {
      _startRest();
    } else {
      if (_visitPos < _visitOrder.length - 1) {
        _startRest();
      } else {
        _completeWorkout();
      }
    }
  }

  /// Move the current exercise to the end of the visit order (machine busy).
  Future<void> _confirmSkipExercise() async {
    final confirmed = await _redesignConfirm(
      title: '¿Saltar ejercicio?',
      message:
          'Este ejercicio pasará al final y perderás el progreso registrado en él. Podrás retomarlo más tarde.',
      confirmLabel: 'Saltar',
      destructive: false,
    );
    if (confirmed == true) _skipExercise();
  }

  void _skipExercise() {
    if (_visitPos >= _visitOrder.length - 1) return;
    setState(() {
      final skipped = _visitOrder.removeAt(_visitPos);
      _visitOrder.add(skipped);
      _recordedWeights.remove(skipped);
      _recordedReps.remove(skipped);
      _currentExerciseIndex = _visitOrder[_visitPos];
      _currentSet = 1;
    });
    _updateWeightController();
    _saveDraft();
  }

  void _completeWorkout() {
    final frozenTotal = _totalElapsed;
    final frozenRest = _totalRestTime;

    _restTimer?.cancel();
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
    _restStopwatch.stop();
    _totalStopwatch.stop();
    setState(() {
      _completedElapsed = frozenTotal;
      _completedRestTime = frozenRest;
      _isCompleted = true;
      _isResting = false;
    });

    // Workout finished — clear the in-progress marker so the home card hides,
    // and drop the local draft now that the data is being saved to Supabase.
    ref.read(activeWorkoutProvider.notifier).finish();
    unawaited(_draftService.clear(_routineId, widget.dayNumber));

    _saveWorkoutData(isCompleted: true);
  }

  void _saveWorkoutData({required bool isCompleted}) {
    final service = ref.read(studentServiceProvider);

    int setsCompleted = 0;
    _recordedWeights.forEach((_, sets) {
      setsCompleted += sets.length;
    });

    // Key set_logs / reps_logs by exercise_id (stable UUID) instead of the
    // positional index in _orderedExercises. This lets history lookups work
    // correctly when the same exercise appears on different routine days (where
    // its positional index would differ).
    final setLogsByExerciseId = <String, Map<String, dynamic>>{};
    final repsLogsByExerciseId = <String, Map<String, dynamic>>{};
    for (final entry in _recordedWeights.entries) {
      final exIdx = entry.key;
      final exerciseId = (_orderedExercises[exIdx]['exercises']
          as Map<String, dynamic>?)?['id'] as String?;
      if (exerciseId == null) continue;
      setLogsByExerciseId[exerciseId] =
          entry.value.map((k2, v2) => MapEntry(k2.toString(), v2));
    }
    for (final entry in _recordedReps.entries) {
      final exIdx = entry.key;
      final exerciseId = (_orderedExercises[exIdx]['exercises']
          as Map<String, dynamic>?)?['id'] as String?;
      if (exerciseId == null) continue;
      repsLogsByExerciseId[exerciseId] =
          entry.value.map((k2, v2) => MapEntry(k2.toString(), v2));
    }

    service.saveWorkoutSession({
      'routine_id': widget.routine['id'],
      'day_number': widget.dayNumber,
      'started_at':
          _startTime?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'duration_seconds': _totalElapsed.inSeconds,
      'sets_completed': setsCompleted,
      'is_completed': isCompleted,
      'set_logs': setLogsByExerciseId,
      'reps_logs': repsLogsByExerciseId,
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _totalStopwatch.stop();
        _restStopwatch.stop();
        // Snapshot the moment we paused so the deadline can be shifted on resume.
        if (_isResting && _restDeadline != null) {
          _restPausedAt = DateTime.now();
        }
      } else {
        _totalStopwatch.start();
        if (_isResting) {
          _restStopwatch.start();
          // Shift the deadline forward by however long we were paused so the
          // remaining time stays exactly where the athlete left it.
          if (_restDeadline != null && _restPausedAt != null) {
            final pausedDuration = DateTime.now().difference(_restPausedAt!);
            _restDeadline = _restDeadline!.add(pausedDuration);
            _restPausedAt = null;
          }
        }
      }
    });
  }

  Future<void> _saveIncompleteWorkout() async {
    _saveWorkoutData(isCompleted: false);
    // Athlete explicitly abandoned — clear both the in-progress marker and the
    // draft so the home card hides and the session can't be resumed.
    ref.read(activeWorkoutProvider.notifier).finish();
    unawaited(_draftService.clear(_routineId, widget.dayNumber));
  }

  // ───────────────────────────── BUILD ──────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      // While a workout is live, disable the iOS swipe-back / system-back so it
      // can't silently cut the session. Exiting goes through the X button, which
      // asks for confirmation. Once completed, the summary pops normally.
      child: PopScope(
        canPop: _isCompleted,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _showExitDialog();
        },
        child: Builder(builder: (context) {
          if (_isCountingDown) return _buildCountdownView();
          if (_isCompleted) return _buildSummaryView();
          if (_isResting) return _buildRestView();
          return _buildExerciseView();
        }),
      ),
    );
  }

  StudentBottomNav _sessionNav() => StudentBottomNav(
        active: StudentNavTab.entrenar,
        onInicioTap: _showExitDialog,
        onEntrenarTap: () {},
        onNutricionTap: _showExitDialog,
      );

  // ── Countdown (3·2·1) ──────────────────────────────────────────────────────

  Widget _buildCountdownView() {
    return Scaffold(
      backgroundColor: RedesignColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Text(
                _countdownValue == 0 ? '¡GO!' : '$_countdownValue',
                style: const TextStyle(
                  color: RedesignColors.actionPrimary,
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Metropolis',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Exercise logging view ──────────────────────────────────────────────────

  Widget _buildExerciseView() {
    final exercise = _orderedExercises[_currentExerciseIndex];
    final exerciseData = exercise['exercises'] as Map<String, dynamic>;
    final name = exerciseData['name'] ?? 'Ejercicio';
    final totalSets = (exercise['sets'] as int?) ?? 3;
    final notes = exercise['comment'] as String?;
    // Use the stable exercise UUID as the lookup key in set_logs/reps_logs so
    // that history works when the same exercise appears on different routine days
    // (where the positional index would differ).
    final exerciseId = exerciseData['id'] as String? ?? _currentExerciseIndex.toString();

    final todayW = _recordedWeights[_currentExerciseIndex] ?? const {};
    final todayR = _recordedReps[_currentExerciseIndex] ?? const {};
    final todayKeys = todayW.keys.toList()..sort();

    return Scaffold(
      backgroundColor: RedesignColors.background,
      extendBody: true,
      bottomNavigationBar: _sessionNav(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 22, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CircleIconButton(
                    icon: Icons.close_rounded,
                    onTap: _showExitDialog,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ejercicio ${_visitPos + 1} de ${_visitOrder.length}',
                          style: const TextStyle(
                            fontFamily: 'Metropolis',
                            color: RedesignColors.primario400,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Metropolis',
                            color: RedesignColors.primario50,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$_currentSet/$totalSets',
                        style: const TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario50,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.0,
                        ),
                      ),
                      const Text(
                        'serie',
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario400,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 130),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ver cómo se hace
                    _VerComoSeHace(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseDetailScreen(
                            exerciseData: exercise,
                            coachComment: notes,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Historial de peso
                    _HistorialDePeso(
                      sessions: _recentSessions,
                      exIndexStr: exerciseId,
                      isLoading: _isLoadingHistory,
                      onGoToHistory: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentWorkoutHistoryScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Registra tu serie',
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.primario50,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _ValueBox(
                            label: 'Peso (KG)',
                            controller: _weightController,
                            focusNode: _weightFocusNode,
                            isInteger: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _ValueBox(
                            label: 'Reps',
                            controller: _repsController,
                            focusNode: _repsFocusNode,
                            isInteger: true,
                            hint: _getCurrentTargetReps(),
                          ),
                        ),
                      ],
                    ),

                    if (_repsMismatch()) ...[
                      const SizedBox(height: 14),
                      _WarningBanner(
                        text:
                            'Ojo, estás colocando otras repeticiones de las indicadas.',
                      ),
                    ],

                    if (notes != null && notes.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _CoachNote(text: notes),
                    ],

                    const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isPaused ? null : _completeSet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RedesignColors.actionPrimary,
                        foregroundColor: RedesignColors.onActionPrimary,
                        minimumSize: const Size(double.infinity, 54),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        'Comenzar descanso',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                    ),

                    if (_visitPos < _visitOrder.length - 1) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: _isPaused ? null : _confirmSkipExercise,
                          child: const Text(
                            'Saltar ejercicio (máquina ocupada)',
                            style: TextStyle(
                              color: RedesignColors.primario400,
                              fontFamily: 'Metropolis',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Series de hoy
                    Row(
                      children: [
                        const Text(
                          'Series de hoy',
                          style: TextStyle(
                            fontFamily: 'Metropolis',
                            color: RedesignColors.primario50,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        if (todayKeys.isNotEmpty)
                          GestureDetector(
                            onTap: () => _showEditSeriesModal(name),
                            child: const Text(
                              'Editar',
                              style: TextStyle(
                                fontFamily: 'Metropolis',
                                color: RedesignColors.secundario300,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (todayKeys.isEmpty)
                      const Text(
                        'Todavía no registraste series hoy.',
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario400,
                          fontSize: 14,
                        ),
                      )
                    else
                      for (final k in todayKeys)
                        _SerieHoyRow(
                          setNumber: k,
                          weight: todayW[k],
                          reps: todayR[k],
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _repsMismatch() {
    final entered = int.tryParse(_repsController.text.trim());
    if (entered == null) return false;
    final t = _getCurrentTargetReps().trim();
    if (t.contains('-')) {
      final parts = t.split('-');
      final lo = int.tryParse(parts.first.trim());
      final hi = int.tryParse(parts.last.trim());
      if (lo != null && hi != null) return entered < lo || entered > hi;
    }
    final tv = int.tryParse(t);
    if (tv == null) return false;
    return entered != tv;
  }

  // ── Rest view ──────────────────────────────────────────────────────────────

  Widget _buildRestView() {
    final currentExercise = _orderedExercises[_currentExerciseIndex];
    final totalRest = (currentExercise['rest_seconds'] as int?) ?? 60;
    final progress = totalRest > 0 ? _restSecondsRemaining / totalRest : 0.0;
    final totalSets = (currentExercise['sets'] as int?) ?? 3;

    final exerciseData = currentExercise['exercises'] as Map<String, dynamic>;
    final currentName = exerciseData['name'] ?? 'Ejercicio';

    String nextTitle;
    String? nextSub;
    if (_currentSet < totalSets) {
      nextTitle = currentName;
      nextSub = 'Serie ${_currentSet + 1} de $totalSets';
    } else if (_visitPos < _visitOrder.length - 1) {
      final nextExercise = _orderedExercises[_visitOrder[_visitPos + 1]];
      final nextData = nextExercise['exercises'] as Map<String, dynamic>;
      final nextSets = (nextExercise['sets'] as int?) ?? 3;
      nextTitle = nextData['name'] ?? 'Siguiente ejercicio';
      nextSub = 'Serie 1 de $nextSets';
    } else {
      nextTitle = '¡Último esfuerzo!';
      nextSub = null;
    }

    return Scaffold(
      backgroundColor: RedesignColors.background,
      extendBody: true,
      bottomNavigationBar: _sessionNav(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 0),
              child: Row(
                children: [
                  _CircleIconButton(
                      icon: Icons.close_rounded, onTap: _showExitDialog),
                  const SizedBox(width: 12),
                  const Text(
                    'Descanso',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline,
                    size: 15, color: RedesignColors.primario400),
                const SizedBox(width: 6),
                Text(
                  'Apretá en el centro del reloj para pausar',
                  style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario400,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            // Scrollable middle (prevents overflow on small screens)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
                child: Column(
                  children: [
                    // Circular timer (tap center → pause); smooth 1s sweep.
                    GestureDetector(
                      onTap: _togglePause,
                      child: SizedBox(
                        width: 206,
                        height: 206,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 206,
                              height: 206,
                              child: TweenAnimationBuilder<double>(
                                duration: Duration(
                                    milliseconds: _isPaused ? 0 : 1000),
                                curve: Curves.linear,
                                tween: Tween<double>(
                                    end: progress.clamp(0.0, 1.0)),
                                builder: (_, value, __) =>
                                    CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 9,
                                  backgroundColor: RedesignColors.primario50
                                      .withValues(alpha: 0.12),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                          RedesignColors.primario50),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$_restSecondsRemaining',
                                  style: const TextStyle(
                                    fontFamily: 'Metropolis',
                                    fontSize: 58,
                                    fontWeight: FontWeight.w700,
                                    color: RedesignColors.primario50,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isPaused ? 'en pausa' : 'segundos',
                                  style: const TextStyle(
                                    fontFamily: 'Metropolis',
                                    fontSize: 15,
                                    color: RedesignColors.primario400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Serie terminada con
                    if (_justCompletedWeight != null &&
                        _justCompletedReps != null) ...[
                      const Text(
                        'Serie terminada con:',
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: RedesignColors.primario300,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: RedesignColors.secundario900,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_justCompletedWeight!.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontFamily: 'Metropolis',
                                color: RedesignColors.primario50,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              width: 1,
                              height: 20,
                              color: RedesignColors.secundario500
                                  .withValues(alpha: 0.6),
                            ),
                            Text(
                              '$_justCompletedReps reps',
                              style: const TextStyle(
                                fontFamily: 'Metropolis',
                                color: RedesignColors.primario50,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // A continuación
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: RedesignColors.primario700,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'A continuación',
                            style: TextStyle(
                              fontFamily: 'Metropolis',
                              color: RedesignColors.primario400,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            nextTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Metropolis',
                              color: RedesignColors.primario50,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (nextSub != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              nextSub,
                              style: const TextStyle(
                                fontFamily: 'Metropolis',
                                color: RedesignColors.primario300,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Pinned skip button
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 130),
              child: ElevatedButton.icon(
                onPressed: _skipRest,
                icon: const Icon(Icons.skip_next_rounded, size: 20),
                label: const Text(
                  'Saltar descanso',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Metropolis',
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RedesignColors.actionPrimary,
                  foregroundColor: RedesignColors.onActionPrimary,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Summary ────────────────────────────────────────────────────────────────

  Widget _buildSummaryView() {
    final totalTime = _completedElapsed ?? _totalElapsed;
    final restTime = _completedRestTime ?? _totalRestTime;
    final workoutTime = totalTime - restTime;

    return Scaffold(
      backgroundColor: RedesignColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: RedesignColors.secundario900,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded,
                    size: 48, color: RedesignColors.actionPrimary),
              ),
              const SizedBox(height: 24),
              const Text(
                '¡Entrenamiento completado!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario50,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.routine['title'] ?? 'Rutina',
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario300,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _SummaryStat(
                      icon: Icons.timer_outlined,
                      value: _formatDuration(totalTime),
                      label: 'Tiempo total'),
                  _SummaryStat(
                      icon: Icons.fitness_center_rounded,
                      value: _formatDuration(workoutTime),
                      label: 'Ejercicio'),
                  _SummaryStat(
                      icon: Icons.pause_circle_outline_rounded,
                      value: _formatDuration(restTime),
                      label: 'Descansos'),
                ],
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: RedesignColors.actionPrimary,
                  foregroundColor: RedesignColors.onActionPrimary,
                  minimumSize: const Size(double.infinity, 54),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  'Finalizar',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Metropolis',
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

  // ── Abandon dialog ─────────────────────────────────────────────────────────

  void _showExitDialog() {
    if (!_isPaused) _togglePause(); // Pause while showing dialog
    final exercise = _orderedExercises[_currentExerciseIndex];
    final totalSets = (exercise['sets'] as int?) ?? 3;
    final todayW = _recordedWeights[_currentExerciseIndex] ?? const {};
    final todayR = _recordedReps[_currentExerciseIndex] ?? const {};
    final doneKeys = todayW.keys.toList()..sort();
    final pending = <int>[
      for (var s = 1; s <= totalSets; s++)
        if (!todayW.containsKey(s)) s
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: Dialog(
          backgroundColor: RedesignColors.primario800,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      if (_isPaused) _togglePause();
                    },
                    child: const Icon(Icons.close_rounded,
                        color: RedesignColors.primario300, size: 22),
                  ),
                ),
                const Text(
                  '¿Querés abandonar el entrenamiento?',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.secundario300,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Te faltan ${pending.length}/$totalSets series',
                  style: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.secundario300,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Si salís ahora, el entrenamiento quedará incompleto.',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario300,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                for (final k in doneKeys) ...[
                  _ExitSerieRow(
                    label: 'Serie $k',
                    value:
                        '${_fmtKg(todayW[k])} kg x ${todayR[k] ?? '-'}',
                    highlight: true,
                  ),
                  const Divider(
                      height: 14, color: RedesignColors.primario700),
                ],
                if (pending.isNotEmpty)
                  _ExitSerieRow(
                    label: pending.length == 1
                        ? 'Serie ${pending.first}'
                        : 'Series ${pending.map((e) => e).join(' y ')}',
                    value: 'Pendientes',
                    highlight: false,
                  ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: () async {
                    // Capture navigators before the async gap so that
                    // post-await use of BuildContext is lint-safe.
                    final dialogNav = Navigator.of(ctx);
                    final screenNav = Navigator.of(context);
                    await _saveIncompleteWorkout();
                    dialogNav.pop();
                    screenNav.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: RedesignColors.peligro600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text(
                    'Abandonar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Metropolis',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (_isPaused) _togglePause();
                    },
                    child: const Text(
                      'Continuar entrenando',
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.primario50,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtKg(dynamic w) {
    if (w is num) return w % 1 == 0 ? w.toInt().toString() : w.toString();
    return '$w';
  }

  Future<bool?> _redesignConfirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario300,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar',
                  style: TextStyle(color: RedesignColors.primario300)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: destructive
                    ? RedesignColors.peligro600
                    : RedesignColors.actionPrimary,
                foregroundColor: destructive
                    ? Colors.white
                    : RedesignColors.onActionPrimary,
                elevation: 0,
              ),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }

  // ── Editar series modal ────────────────────────────────────────────────────

  void _showEditSeriesModal(String exerciseName) {
    final ex = _currentExerciseIndex;
    final w = _recordedWeights[ex] ?? const {};
    final r = _recordedReps[ex] ?? const {};
    final keys = w.keys.toList()..sort();

    // Local editable rows.
    final rows = <({TextEditingController wc, TextEditingController rc})>[
      for (final k in keys)
        (
          wc: TextEditingController(text: _fmtKg(w[k])),
          rc: TextEditingController(text: (r[k] ?? '').toString()),
        ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: RedesignColors.primario800,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded,
                            color: RedesignColors.primario300),
                      ),
                    ),
                    const Text(
                      'Editar series',
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.primario50,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exerciseName,
                      style: const TextStyle(
                        fontFamily: 'Metropolis',
                        color: RedesignColors.secundario300,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: const [
                        SizedBox(width: 24, child: Text('#',
                            style: TextStyle(
                                color: RedesignColors.primario400,
                                fontFamily: 'Metropolis',
                                fontSize: 13))),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('Peso',
                                style: TextStyle(
                                    color: RedesignColors.primario400,
                                    fontFamily: 'Metropolis',
                                    fontSize: 13))),
                        SizedBox(width: 10),
                        Expanded(
                            child: Text('Repeticiones',
                                style: TextStyle(
                                    color: RedesignColors.primario400,
                                    fontFamily: 'Metropolis',
                                    fontSize: 13))),
                        SizedBox(width: 40),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            for (var i = 0; i < rows.length; i++) ...[
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        fontFamily: 'Metropolis',
                                        color: RedesignColors.primario50,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MiniField(
                                      controller: rows[i].wc,
                                      suffix: 'kg',
                                      isInteger: false,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _MiniField(
                                      controller: rows[i].rc,
                                      suffix: 'reps',
                                      isInteger: true,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      onPressed: () =>
                                          setModal(() => rows.removeAt(i)),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: RedesignColors.primario400,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setModal(() => rows.add((
                              wc: TextEditingController(),
                              rc: TextEditingController(),
                            ))),
                        icon: const Icon(Icons.add_rounded,
                            color: RedesignColors.secundario300, size: 18),
                        label: const Text(
                          'Agregar serie',
                          style: TextStyle(
                            fontFamily: 'Metropolis',
                            color: RedesignColors.secundario300,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        final newW = <int, double>{};
                        final newR = <int, int>{};
                        for (var i = 0; i < rows.length; i++) {
                          final wv = double.tryParse(
                              rows[i].wc.text.trim().replaceAll(',', '.'));
                          final rv = int.tryParse(rows[i].rc.text.trim());
                          newW[i + 1] = wv ?? 0;
                          newR[i + 1] = rv ?? 0;
                        }
                        setState(() {
                          if (newW.isEmpty) {
                            _recordedWeights.remove(ex);
                            _recordedReps.remove(ex);
                          } else {
                            _recordedWeights[ex] = newW;
                            _recordedReps[ex] = newR;
                          }
                        });
                        _saveDraft();
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: RedesignColors.actionPrimary,
                        foregroundColor: RedesignColors.onActionPrimary,
                        minimumSize: const Size(double.infinity, 52),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text(
                        'Guardar series',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Metropolis',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: RedesignColors.primario700,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _VerComoSeHace extends StatelessWidget {
  final VoidCallback onTap;
  const _VerComoSeHace({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: RedesignColors.primario700,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: RedesignColors.actionPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded,
                  color: RedesignColors.onActionPrimary, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ver cómo se hace',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario50,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Video y técnica',
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: RedesignColors.primario400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario300),
          ],
        ),
      ),
    );
  }
}

class _HistorialDePeso extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final String exIndexStr;
  final bool isLoading;
  final VoidCallback onGoToHistory;

  const _HistorialDePeso({
    required this.sessions,
    required this.exIndexStr,
    required this.isLoading,
    required this.onGoToHistory,
  });

  String _line(Map<String, dynamic> session) {
    final sl = (session['set_logs'] as Map?)?[exIndexStr] as Map?;
    final rl = (session['reps_logs'] as Map?)?[exIndexStr] as Map?;
    if (sl == null || sl.isEmpty) return '';
    final keys = sl.keys.map((k) => int.tryParse(k.toString()) ?? 0).toList()
      ..sort();
    return keys.map((k) {
      final wv = sl[k.toString()];
      final rv = rl?[k.toString()];
      final wStr = wv is num
          ? (wv % 1 == 0 ? wv.toInt().toString() : wv.toString())
          : '$wv';
      return '$wStr kg x ${rv ?? '-'}';
    }).join(' | ');
  }

  String _date(Map<String, dynamic> session) {
    final raw = session['created_at'] ?? session['started_at'];
    if (raw is! String) return '';
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return '';
    return '${d.day} ${_monthAbbr[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, dynamic>>[
      for (final s in sessions)
        if (_line(s).isNotEmpty) s
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historial de peso',
            style: TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'peso | reps por serie',
            style: TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario400,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Cargando…',
                  style: TextStyle(
                      color: RedesignColors.primario400,
                      fontFamily: 'Metropolis',
                      fontSize: 13)),
            )
          else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin registros previos de este ejercicio.',
                  style: TextStyle(
                      color: RedesignColors.primario400,
                      fontFamily: 'Metropolis',
                      fontSize: 13)),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              const Divider(height: 1, color: RedesignColors.primario600),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        _date(rows[i]),
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: i == 0
                              ? RedesignColors.secundario300
                              : RedesignColors.primario400,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _line(rows[i]),
                        style: TextStyle(
                          fontFamily: 'Metropolis',
                          color: i == 0
                              ? RedesignColors.secundario300
                              : RedesignColors.primario200,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onGoToHistory,
            child: const Text(
              'Ir al historial',
              style: TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.secundario300,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueBox extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isInteger;
  final String? hint;

  const _ValueBox({
    required this.label,
    required this.controller,
    required this.focusNode,
    required this.isInteger,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario300,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType:
                    TextInputType.numberWithOptions(decimal: !isInteger),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]')),
                ],
                textAlign: TextAlign.center,
                cursorColor: RedesignColors.actionPrimary,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario50,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: hint ?? '0',
                  hintStyle: const TextStyle(
                    fontFamily: 'Metropolis',
                    color: RedesignColors.primario500,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningBanner extends StatelessWidget {
  final String text;
  const _WarningBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RedesignColors.peligro600,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: Colors.white,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachNote extends StatelessWidget {
  final String text;
  const _CoachNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              color: RedesignColors.advertencia400, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario200,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SerieHoyRow extends StatelessWidget {
  final int setNumber;
  final double? weight;
  final int? reps;

  const _SerieHoyRow({
    required this.setNumber,
    required this.weight,
    required this.reps,
  });

  @override
  Widget build(BuildContext context) {
    final wStr = weight == null
        ? '-'
        : (weight! % 1 == 0 ? weight!.toInt().toString() : weight!.toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            'Serie $setNumber',
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario300,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '$wStr kg x ${reps ?? '-'} reps',
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExitSerieRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _ExitSerieRow({
    required this.label,
    required this.value,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Metropolis',
            color: RedesignColors.primario400,
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Metropolis',
            color: highlight
                ? RedesignColors.primario50
                : RedesignColors.primario400,
            fontSize: 14,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 30, color: RedesignColors.actionPrimary),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Metropolis',
            color: RedesignColors.primario50,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Metropolis',
            color: RedesignColors.primario400,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MiniField extends StatelessWidget {
  final TextEditingController controller;
  final String suffix;
  final bool isInteger;

  const _MiniField({
    required this.controller,
    required this.suffix,
    required this.isInteger,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: RedesignColors.secundario900,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType:
                  TextInputType.numberWithOptions(decimal: !isInteger),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                    isInteger ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario50,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                suffixText: suffix,
                suffixStyle: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
