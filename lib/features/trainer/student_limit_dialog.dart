import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/billing_service.dart';
import '../../services/trainer_service.dart';
import 'elegir_plan_screen.dart';

/// True when [e] is the student-cap trigger error from the database
/// (Postgres detail 'student_limit_reached', see add_mp_billing.sql).
bool isStudentLimitError(Object e) =>
    e is PostgrestException && (e.details?.toString() ?? '') == 'student_limit_reached';

/// Friendly dialog shown when a trainer is at their plan's student cap, with
/// a shortcut to Elegir Plan.
Future<void> showStudentLimitDialog(BuildContext context, {int? cap}) {
  final limit = cap == null ? 'de alumnos' : 'de $cap alumnos';
  return showDialog<void>(
    context: context,
    builder: (ctx) => Theme(
      data: RedesignTheme.theme,
      child: AlertDialog(
        backgroundColor: RedesignColors.primario700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RedesignRadius.card),
        ),
        title: Text(
          'Llegaste al límite de tu plan',
          style: RedesignType.bodySm.copyWith(
            color: RedesignColors.primario50,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Alcanzaste el límite $limit de tu plan. Mejorá tu plan para que más alumnos puedan sumarse.',
          style: RedesignType.label.copyWith(color: RedesignColors.primario300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Ahora no',
              style: RedesignType.buttonSm
                  .copyWith(color: RedesignColors.primario300),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ElegirPlanScreen()),
              );
            },
            child: Text(
              'Elegir plan',
              style: RedesignType.buttonSm
                  .copyWith(color: RedesignColors.actionPrimaryDark),
            ),
          ),
        ],
      ),
    ),
  );
}

/// If the trainer already has as many students as their plan allows, shows
/// the dialog and returns true (the caller should stop). Network errors fall
/// through as false: the server trigger is the real enforcement.
Future<bool> blockIfAtStudentLimit(BuildContext context, WidgetRef ref) async {
  try {
    final students = await ref.read(myStudentsProvider.future);
    final sub = await ref.read(billingSubscriptionProvider.future);
    final cap = studentCapFor(sub, DateTime.now());
    if (cap != null && students.length >= cap) {
      if (context.mounted) await showStudentLimitDialog(context, cap: cap);
      return true;
    }
  } catch (_) {}
  return false;
}
