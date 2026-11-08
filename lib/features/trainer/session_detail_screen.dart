import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';

/// Trainer view/edit of a single workout session's per-exercise weights & reps.
///
/// Two modes:
///  - Edit an existing [session] (workout_sessions row with set_logs/reps_logs).
///  - Log a new in-person session: pass [athleteId] + [routineId] + [dayNumber]
///    and leave [session] null.
///
/// set_logs / reps_logs are keyed by exercise INDEX (position in the ordered
/// routine_exercises for the day) then by 1-based set number — matching the
/// student app's write format.
class SessionDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? session;
  final String athleteId;
  final String routineId;
  final int dayNumber;
  final String routineTitle;

  const SessionDetailScreen({
    super.key,
    this.session,
    required this.athleteId,
    required this.routineId,
    required this.dayNumber,
    required this.routineTitle,
  });

  @override
  ConsumerState<SessionDetailScreen> createState() =>
      _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool get _isNew => widget.session == null;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _exercises = [];
  Map<String, dynamic>? _prevSetLogs;
  Map<String, dynamic>? _prevRepsLogs;
  // Day of the previous session; used to safely fall back to legacy
  // position-keyed set_logs (pre-exercise_id migration) only when it's the
  // same routine day, where the exercise order — and thus the index — matches.
  int? _prevDayNumber;

  // controllers[exerciseIndex][setNumber] -> (weight, reps)
  final Map<int, Map<int, TextEditingController>> _weightCtrls = {};
  final Map<int, Map<int, TextEditingController>> _repsCtrls = {};

  /// Identifies an in-progress new session so it survives navigating away.
  String get _draftKey =>
      '${widget.athleteId}|${widget.routineId}|${widget.dayNumber}';

  /// True once saved (or the draft was intentionally cleared) so dispose() does
  /// not re-persist a stale draft.
  bool _draftCleared = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // Persist whatever the trainer typed for a not-yet-saved new session so it
    // can be restored when they come back. Read controllers BEFORE disposing.
    if (_isNew && !_draftCleared) {
      _persistDraft();
    }
    for (final m in _weightCtrls.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    for (final m in _repsCtrls.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  /// Snapshot the current field values into the in-memory draft store (or clear
  /// it if nothing was typed).
  void _persistDraft() {
    final weights = <String, Map<String, String>>{};
    final reps = <String, Map<String, String>>{};
    for (var i = 0; i < _exercises.length; i++) {
      final exerciseId = _exercises[i]['exercise_id'] as String? ?? '$i';
      final w = <String, String>{};
      final r = <String, String>{};
      _weightCtrls[i]?.forEach((s, c) {
        if (c.text.trim().isNotEmpty) w['$s'] = c.text;
      });
      _repsCtrls[i]?.forEach((s, c) {
        if (c.text.trim().isNotEmpty) r['$s'] = c.text;
      });
      if (w.isNotEmpty) weights[exerciseId] = w;
      if (r.isNotEmpty) reps[exerciseId] = r;
    }
    final store = ref.read(manualSessionDraftStoreProvider);
    final draft = ManualSessionDraft(weights: weights, reps: reps);
    if (draft.isEmpty) {
      store.clear(_draftKey);
    } else {
      store.save(_draftKey, draft);
    }
  }

  Future<void> _load() async {
    final service = ref.read(trainerServiceProvider);
    try {
      final exercises = await service.getSessionExercises(
        widget.routineId,
        widget.dayNumber,
      );

      final setLogs =
          widget.session?['set_logs'] as Map<String, dynamic>? ?? {};
      final repsLogs =
          widget.session?['reps_logs'] as Map<String, dynamic>? ?? {};

      // Previous session for the vs-last-time comparison.
      final startedAt =
          (widget.session?['started_at'] ??
                  widget.session?['created_at'] ??
                  DateTime.now().toUtc().toIso8601String())
              as String;
      final prev = await service.getPreviousSession(
        athleteId: widget.athleteId,
        routineId: widget.routineId,
        dayNumber: widget.dayNumber,
        beforeStartedAt: startedAt,
        excludeSessionId: widget.session?['id'] as String?,
      );

      // Restore an in-progress draft for a brand-new session (if any).
      final draft = _isNew
          ? ref.read(manualSessionDraftStoreProvider).get(_draftKey)
          : null;

      for (var i = 0; i < exercises.length; i++) {
        final sets = (exercises[i]['sets'] as int?) ?? 3;
        _weightCtrls[i] = {};
        _repsCtrls[i] = {};
        // Look up by exercise_id (stable UUID) so reads are correct regardless
        // of which day the exercise appears on (positional index would differ).
        final exerciseId = exercises[i]['exercise_id'] as String? ?? '$i';
        final exWeights = setLogs[exerciseId] as Map<String, dynamic>?;
        final exReps = repsLogs[exerciseId] as Map<String, dynamic>?;
        final draftWeights = draft?.weights[exerciseId];
        final draftReps = draft?.reps[exerciseId];
        for (var s = 1; s <= sets; s++) {
          _weightCtrls[i]![s] = TextEditingController(
            text: draftWeights?['$s'] ?? _fmt(exWeights?['$s']),
          );
          _repsCtrls[i]![s] = TextEditingController(
            text: draftReps?['$s'] ?? _fmt(exReps?['$s']),
          );
        }
      }

      if (draft != null && !draft.isEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Borrador restaurado')),
          );
        });
      }

      setState(() {
        _exercises = exercises;
        _prevSetLogs = prev?['set_logs'] as Map<String, dynamic>?;
        _prevRepsLogs = prev?['reps_logs'] as Map<String, dynamic>?;
        _prevDayNumber = prev?['day_number'] as int?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    if (v is num) {
      // drop trailing .0 for whole numbers
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toString();
    }
    return v.toString();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final service = ref.read(trainerServiceProvider);

    final setLogs = <String, Map<String, num>>{};
    final repsLogs = <String, Map<String, num>>{};
    var setsCompleted = 0;

    for (var i = 0; i < _exercises.length; i++) {
      final w = <String, num>{};
      final r = <String, num>{};
      final wc = _weightCtrls[i] ?? {};
      final rc = _repsCtrls[i] ?? {};
      for (final s in wc.keys) {
        final weight = num.tryParse(wc[s]!.text.trim().replaceAll(',', '.'));
        final reps = num.tryParse(rc[s]!.text.trim());
        if (weight != null) w['$s'] = weight;
        if (reps != null) r['$s'] = reps;
        if (weight != null || reps != null) setsCompleted++;
      }
      // Key by exercise_id (stable UUID) instead of positional index so that
      // lookups work correctly when the same exercise appears on different days.
      final exerciseId = _exercises[i]['exercise_id'] as String? ?? '$i';
      if (w.isNotEmpty) setLogs[exerciseId] = w;
      if (r.isNotEmpty) repsLogs[exerciseId] = r;
    }

    try {
      if (_isNew) {
        await service.createInPersonSession(
          athleteId: widget.athleteId,
          routineId: widget.routineId,
          dayNumber: widget.dayNumber,
          setLogs: setLogs,
          repsLogs: repsLogs,
          setsCompleted: setsCompleted,
        );
      } else {
        await service.updateSessionLogs(
          sessionId: widget.session!['id'] as String,
          setLogs: setLogs,
          repsLogs: repsLogs,
          setsCompleted: setsCompleted,
        );
      }
      // Session persisted — drop any in-progress draft for this athlete/day.
      ref.read(manualSessionDraftStoreProvider).clear(_draftKey);
      _draftCleared = true;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesos guardados')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    }
  }

  String _prevLabel(String exerciseId, int exIndex, int setNumber) {
    // Primary: look up by stable exercise_id (post-migration sessions).
    var setMap = _prevSetLogs?[exerciseId] as Map<String, dynamic>?;
    var repMap = _prevRepsLogs?[exerciseId] as Map<String, dynamic>?;
    // Fallback: legacy sessions keyed by positional index. Only trust the
    // position when the previous session is the SAME routine day, where the
    // exercise order (order_index) — and thus the index — still lines up.
    // A numeric key can never collide with a UUID key, so this is safe for
    // new sessions; the same-day guard prevents cross-day false matches.
    if (setMap == null && repMap == null && _prevDayNumber == widget.dayNumber) {
      setMap = _prevSetLogs?['$exIndex'] as Map<String, dynamic>?;
      repMap = _prevRepsLogs?['$exIndex'] as Map<String, dynamic>?;
    }
    final w = setMap?['$setNumber'];
    final r = repMap?['$setNumber'];
    if (w == null && r == null) return '';
    return 'anterior: ${_fmt(w).isEmpty ? '–' : _fmt(w)} kg × ${_fmt(r).isEmpty ? '–' : _fmt(r)}';
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: RedesignColors.primario50),
          centerTitle: true,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isNew ? 'Registrar sesión' : '${widget.routineTitle} — Día ${widget.dayNumber}',
                style: RedesignType.bodySm.copyWith(
                  fontWeight: FontWeight.w700,
                  color: RedesignColors.primario50,
                ),
              ),
              if (!_isNew)
                Text(
                  widget.routineTitle,
                  style: RedesignType.label.copyWith(
                    color: RedesignColors.primario300,
                  ),
                ),
            ],
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    RedesignColors.actionPrimary,
                  ),
                ),
              )
            : _error != null
            ? Center(
                child: Text(
                  'Error: $_error',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario300,
                  ),
                ),
              )
            : _exercises.isEmpty
            ? Center(
                child: Text(
                  'Este día no tiene ejercicios',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario400,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _exercises.length,
                itemBuilder: (context, i) => _exerciseCard(i),
              ),
        bottomNavigationBar: _loading || _exercises.isEmpty
            ? null
            : SafeArea(
                minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SizedBox(
                  height: RedesignSpacing.inputHeight,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RedesignColors.actionPrimary,
                      foregroundColor: RedesignColors.onActionPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: RedesignRadius.buttonLgBr,
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                RedesignColors.onActionPrimary,
                              ),
                            ),
                          )
                        : Text(
                            _isNew ? 'Registrar sesión' : 'Guardar',
                            style: RedesignType.buttonLg.copyWith(
                              color: RedesignColors.onActionPrimary,
                            ),
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _exerciseCard(int i) {
    final name = _exercises[i]['exercises']?['name'] ?? 'Ejercicio';
    final exerciseId = _exercises[i]['exercise_id'] as String? ?? '$i';
    final setNumbers = (_weightCtrls[i]?.keys.toList() ?? [])..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(RedesignSpacing.lg),
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        border: Border.all(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: RedesignType.bodySm.copyWith(
              color: RedesignColors.primario50,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (final s in setNumbers) _setRow(i, s, exerciseId),
        ],
      ),
    );
  }

  Widget _setRow(int exIndex, int setNumber, String exerciseId) {
    final prev = _prevLabel(exerciseId, exIndex, setNumber);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  'S$setNumber',
                  style: RedesignType.label.copyWith(
                    color: RedesignColors.primario400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: _numField(_weightCtrls[exIndex]![setNumber]!, 'kg'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '×',
                  style: RedesignType.bodySm.copyWith(
                    color: RedesignColors.primario50,
                  ),
                ),
              ),
              Expanded(
                child: _numField(
                  _repsCtrls[exIndex]![setNumber]!,
                  'reps',
                  intOnly: true,
                ),
              ),
            ],
          ),
          if (prev.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 64, top: 4),
              child: Text(
                prev,
                style: RedesignType.label.copyWith(
                  color: RedesignColors.primario400,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _numField(
    TextEditingController controller,
    String suffix, {
    bool intOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !intOnly),
      inputFormatters: intOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
      decoration: InputDecoration(
        isDense: true,
        suffixText: suffix,
        suffixStyle: RedesignType.label.copyWith(
          color: RedesignColors.primario400,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        filled: true,
        fillColor: RedesignColors.inputFill,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          borderSide: BorderSide(
            color: RedesignColors.secundario300.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.buttonSm),
          borderSide: const BorderSide(
            color: RedesignColors.inputBorderFocused,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// In-progress manual-session drafts
//
// Lets a trainer leave a new manual session (e.g. to check something on the
// student detail) and come back without losing the weights/reps they typed.
// Kept in-memory for the app session, keyed by athlete|routine|day. Cleared
// once the session is saved.
// ---------------------------------------------------------------------------

/// Typed weights/reps for an in-progress manual session.
/// Maps exerciseId -> setNumber(String) -> raw text field value.
class ManualSessionDraft {
  final Map<String, Map<String, String>> weights;
  final Map<String, Map<String, String>> reps;

  const ManualSessionDraft({required this.weights, required this.reps});

  bool get isEmpty =>
      weights.values.every((m) => m.values.every((v) => v.trim().isEmpty)) &&
      reps.values.every((m) => m.values.every((v) => v.trim().isEmpty));
}

class ManualSessionDraftStore {
  final Map<String, ManualSessionDraft> _drafts = {};

  ManualSessionDraft? get(String key) => _drafts[key];
  void save(String key, ManualSessionDraft draft) => _drafts[key] = draft;
  void clear(String key) => _drafts.remove(key);
}

final manualSessionDraftStoreProvider =
    Provider<ManualSessionDraftStore>((ref) => ManualSessionDraftStore());
