import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
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

  // controllers[exerciseIndex][setNumber] -> (weight, reps)
  final Map<int, Map<int, TextEditingController>> _weightCtrls = {};
  final Map<int, Map<int, TextEditingController>> _repsCtrls = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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

      for (var i = 0; i < exercises.length; i++) {
        final sets = (exercises[i]['sets'] as int?) ?? 3;
        _weightCtrls[i] = {};
        _repsCtrls[i] = {};
        final exWeights = setLogs['$i'] as Map<String, dynamic>?;
        final exReps = repsLogs['$i'] as Map<String, dynamic>?;
        for (var s = 1; s <= sets; s++) {
          _weightCtrls[i]![s] = TextEditingController(
            text: _fmt(exWeights?['$s']),
          );
          _repsCtrls[i]![s] = TextEditingController(text: _fmt(exReps?['$s']));
        }
      }

      setState(() {
        _exercises = exercises;
        _prevSetLogs = prev?['set_logs'] as Map<String, dynamic>?;
        _prevRepsLogs = prev?['reps_logs'] as Map<String, dynamic>?;
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
      if (w.isNotEmpty) setLogs['$i'] = w;
      if (r.isNotEmpty) repsLogs['$i'] = r;
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

  String _prevLabel(int exIndex, int setNumber) {
    final w = (_prevSetLogs?['$exIndex'] as Map<String, dynamic>?)?['$setNumber'];
    final r = (_prevRepsLogs?['$exIndex'] as Map<String, dynamic>?)?['$setNumber'];
    if (w == null && r == null) return '';
    return 'anterior: ${_fmt(w).isEmpty ? '–' : _fmt(w)} kg × ${_fmt(r).isEmpty ? '–' : _fmt(r)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${widget.routineTitle} — Día ${widget.dayNumber}',
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _exercises.isEmpty
          ? Center(
              child: Text(
                'Este día no tiene ejercicios',
                style: TextStyle(color: AppColors.textLight),
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
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isNew ? 'Registrar sesión' : 'Guardar'),
                ),
              ),
            ),
    );
  }

  Widget _exerciseCard(int i) {
    final name = _exercises[i]['exercises']?['name'] ?? 'Ejercicio';
    final setNumbers = (_weightCtrls[i]?.keys.toList() ?? [])..sort();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          for (final s in setNumbers) _setRow(i, s),
        ],
      ),
    );
  }

  Widget _setRow(int exIndex, int setNumber) {
    final prev = _prevLabel(exIndex, setNumber);
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
                  'Serie $setNumber',
                  style: TextStyle(color: AppColors.textLight, fontSize: 13),
                ),
              ),
              Expanded(
                child: _numField(_weightCtrls[exIndex]![setNumber]!, 'kg'),
              ),
              const SizedBox(width: 10),
              const Text('×', style: TextStyle(color: Colors.white)),
              const SizedBox(width: 10),
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
                style: TextStyle(
                  color: AppColors.textLight.withValues(alpha: 0.7),
                  fontSize: 11,
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        isDense: true,
        suffixText: suffix,
        suffixStyle: TextStyle(color: AppColors.textLight, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: AppColors.background.withValues(alpha: 0.4),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryLight),
        ),
      ),
    );
  }
}
