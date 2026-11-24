import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:north_star/features/trainer/elegir_plan_screen.dart';
import 'package:north_star/features/trainer/mi_suscripcion_screen.dart';
import 'package:north_star/models/billing_plan.dart';
import 'package:north_star/models/billing_subscription.dart';
import 'package:north_star/models/mp_payment.dart';
import 'package:north_star/services/billing_service.dart';
import 'package:north_star/services/trainer_service.dart';

// Render smoke tests with provider overrides (no network, no Supabase).
const _plans = [
  BillingPlan(id: 'a', name: 'Plan Básico', price: 40000, currencyId: 'ARS', maxStudents: 10, featureLabels: []),
  BillingPlan(id: 'b', name: 'Plan Profesional', price: 75000, currencyId: 'ARS', maxStudents: 50, featureLabels: []),
  BillingPlan(id: 'c', name: 'Plan Empresarial', price: 100000, currencyId: 'ARS', maxStudents: 100, featureLabels: []),
];

BillingSubscription _sub(Map<String, dynamic> over) => BillingSubscription.fromMap({
      'id': 's1',
      'source': 'mp',
      'status': 'authorized',
      'is_active': true,
      'ends_at': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
      'next_payment_date': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
      'subscription_plans': {'id': 'b', 'name': 'Plan Profesional', 'price': 75000, 'max_students': 50},
      ...over,
    });

Future<void> _pump(WidgetTester t, Widget screen, BillingSubscription? sub) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await t.pumpWidget(ProviderScope(
    overrides: [
      billingPlansProvider.overrideWith((ref) async => _plans),
      billingSubscriptionProvider.overrideWith((ref) async => sub),
      billingPaymentsProvider.overrideWith((ref) async => [
            MpPayment.fromMap({'id': 'p1', 'amount': '75000.00', 'status': 'approved', 'paid_at': '2026-11-01T10:00:00Z'}),
          ]),
      myStudentsProvider.overrideWith((ref) async => <Map<String, dynamic>>[{}, {}, {}]),
    ],
    child: MaterialApp(home: screen),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('Elegir plan renders ARS prices and Suscribirme', (t) async {
    await _pump(t, const ElegirPlanScreen(), null);
    expect(find.textContaining('\$ 40.000 / mes', findRichText: true), findsOneWidget);
    expect(find.textContaining('\$ 75.000 / mes', findRichText: true), findsOneWidget);
    expect(find.text('Suscribirme'), findsOneWidget);
    expect(find.text('Hasta 50 alumnos'), findsOneWidget);
  });

  testWidgets('Mi suscripcion: active plan shows chip, history, cancel', (t) async {
    await _pump(t, const MiSuscripcionScreen(), _sub({}));
    expect(find.text('Activa'), findsOneWidget);
    expect(find.text('\$ 75.000 / mes'), findsOneWidget);
    expect(find.text('Aprobado'), findsOneWidget);
    expect(find.text('Cancelar suscripción'), findsOneWidget);
    expect(find.text('3 de 50'), findsOneWidget);
  });

  testWidgets('Mi suscripcion: manual plan has no cancel / pay buttons', (t) async {
    await _pump(t, const MiSuscripcionScreen(), _sub({'source': 'manual'}));
    expect(find.text('Plan asignado por PRGS'), findsOneWidget);
    expect(find.text('Cancelar suscripción'), findsNothing);
    expect(find.text('Elegir plan'), findsNothing);
  });

  testWidgets('Mi suscripcion: no subscription offers Elegir plan', (t) async {
    await _pump(t, const MiSuscripcionScreen(), null);
    expect(find.text('Sin plan activo'), findsOneWidget);
    expect(find.text('Elegir plan'), findsOneWidget);
    expect(find.text('3 de 10'), findsOneWidget);
  });
}
