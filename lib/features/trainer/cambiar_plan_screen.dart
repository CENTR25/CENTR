import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../services/trainer_service.dart';
import '../shared/redesign_toast.dart';
import 'nuevo_plan_screen.dart';
import 'meal_plan_detail_screen.dart';
import 'student_detail_screen.dart' show studentDetailProvider;

// ---------------------------------------------------------------------------
// CambiarPlanScreen
//
// Full-screen list of the trainer's plans. Allows the trainer to search,
// filter (best-effort keyword heuristic on title/description), preview a plan
// and finally assign it to an athlete.
//
// SIMPLIFICATION NOTE: There is no `category` column on meal_plans. The
// category filter (Déficit / Volumen / Manten.) is implemented as a
// case-insensitive keyword search on `title + description`. "Todos" always
// shows the full list. This is flagged so that a proper category column can be
// added if needed.
// ---------------------------------------------------------------------------

class CambiarPlanScreen extends ConsumerStatefulWidget {
  final String athleteId;

  const CambiarPlanScreen({super.key, required this.athleteId});

  @override
  ConsumerState<CambiarPlanScreen> createState() => _CambiarPlanScreenState();
}

class _CambiarPlanScreenState extends ConsumerState<CambiarPlanScreen> {
  String _search = '';
  String _category = 'Todos'; // Todos | Déficit | Volumen | Manten.
  String? _selectedPlanId;
  bool _isAssigning = false;

  static const _categories = ['Todos', 'Déficit', 'Volumen', 'Manten.'];

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> plans) {
    final q = _search.toLowerCase().trim();
    return plans.where((p) {
      final title = (p['title'] as String? ?? '').toLowerCase();
      final desc = (p['description'] as String? ?? '').toLowerCase();

      // Category heuristic (no column in DB — keyword match)
      if (_category != 'Todos') {
        final kw = _category.toLowerCase().replaceAll('.', '');
        if (!title.contains(kw) && !desc.contains(kw)) return false;
      }

      // Search
      if (q.isNotEmpty && !title.contains(q) && !desc.contains(q)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Count distinct day_numbers from meal_plan_items.
  int _daysCount(Map<String, dynamic> plan) {
    final items = (plan['meal_plan_items'] as List?) ?? [];
    final days = <int>{};
    for (final item in items) {
      final d = item['day_number'];
      if (d is int) days.add(d);
    }
    return days.isEmpty ? 1 : days.length;
  }

  Future<void> _assign() async {
    final id = _selectedPlanId;
    if (id == null) return;

    final nav = Navigator.of(context);
    final overlay = Overlay.maybeOf(context);
    setState(() => _isAssigning = true);

    try {
      await ref.read(trainerServiceProvider).assignMealPlanToStudent(
            athleteId: widget.athleteId,
            mealPlanId: id,
          );
      ref.invalidate(studentDetailProvider(widget.athleteId));
      if (!mounted) return;
      nav.pop();
      if (overlay != null) {
        showRedesignToast(
          overlay.context,
          title: '¡Plan asignado!',
          subtitle: 'El plan fue asignado al alumno.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAssigning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: RedesignColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(myMealPlansProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'Cambiar plan',
            style: TextStyle(
              color: RedesignColors.primario50,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
        body: Column(
          children: [
            // ── Search ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: InputDecoration(
                  hintText: 'Buscar plan',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: RedesignColors.primario400),
                  filled: true,
                  fillColor: RedesignColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(RedesignRadius.input),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                ),
              ),
            ),

            // ── Category pills ───────────────────────────────────────────────
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = _category == cat;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? RedesignColors.secundario300
                            : RedesignColors.secundario300
                                .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(RedesignRadius.buttonSm),
                        border: Border.all(
                          color: RedesignColors.secundario300
                              .withValues(alpha: selected ? 1 : 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: RedesignType.buttonSm.copyWith(
                          color: selected
                              ? RedesignColors.secundario900
                              : RedesignColors.secundario300,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── "+ Crear plan nuevo" button ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NuevoPlanScreen()),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Crear plan nuevo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: RedesignColors.actionPrimaryDark,
                  side: const BorderSide(
                      color: RedesignColors.actionPrimaryDark),
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(RedesignRadius.buttonLg),
                  ),
                  textStyle: RedesignType.buttonSm,
                ),
              ),
            ),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: RedesignColors.actionPrimary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: RedesignColors.danger)),
                ),
                data: (plans) {
                  final filtered = _filter(plans);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No hay planes que coincidan.',
                          textAlign: TextAlign.center,
                          style: RedesignType.bodySm
                              .copyWith(color: RedesignColors.primario300),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final plan = filtered[index];
                      final id = plan['id'] as String;
                      final title = (plan['title'] as String?) ?? 'Plan';
                      final kcal = plan['target_calories'] as int?;
                      final days = _daysCount(plan);
                      final selected = _selectedPlanId == id;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedPlanId = id),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: RedesignColors.surface,
                            borderRadius: BorderRadius.circular(
                                RedesignRadius.card),
                            border: Border.all(
                              color: selected
                                  ? RedesignColors.secundario300
                                  : RedesignColors.secundario300
                                      .withValues(alpha: 0.18),
                              width: selected ? 1.2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              if (selected)
                                const Icon(Icons.check_circle_rounded,
                                    color: RedesignColors.actionPrimary,
                                    size: 20)
                              else
                                const Icon(
                                    Icons.radio_button_unchecked_rounded,
                                    color: RedesignColors.primario400,
                                    size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: RedesignType.bodySm.copyWith(
                                        color: RedesignColors.primario50,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${kcal != null ? '$kcal kcal · ' : ''}$days ${days == 1 ? 'día' : 'días'}',
                                      style: RedesignType.label.copyWith(
                                          color:
                                              RedesignColors.primario300),
                                    ),
                                  ],
                                ),
                              ),
                              // Chevron → preview (read-only push)
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MealPlanDetailScreen(
                                      planId: id,
                                      planName: title,
                                    ),
                                  ),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.chevron_right_rounded,
                                      color: RedesignColors.primario400,
                                      size: 20),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),

        // ── Assign button (float over list) ───────────────────────────────
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_selectedPlanId == null || _isAssigning) ? null : _assign,
                child: _isAssigning
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: RedesignColors.onActionPrimary,
                        ),
                      )
                    : const Text('Asignar plan'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
