import 'package:flutter_test/flutter_test.dart';
import 'package:north_star/core/utils/billing_format.dart';
import 'package:north_star/models/billing_subscription.dart';
import 'package:north_star/services/billing_service.dart';

BillingSubscription sub({
  String source = 'mp',
  String status = 'authorized',
  bool isActive = true,
  String? endsAt,
  String? graceUntil,
  String? lastPaymentAt,
  String? createdAt,
  int? max = 10,
}) =>
    BillingSubscription.fromMap({
      'id': 'x',
      'source': source,
      'status': status,
      'is_active': isActive,
      'ends_at': endsAt,
      'grace_until': graceUntil,
      'last_payment_at': lastPaymentAt,
      'created_at': createdAt,
      'subscription_plans': {'id': 'p', 'name': 'Plan Básico', 'price': '40000.00', 'max_students': max},
    });

void main() {
  final now = DateTime.utc(2026, 11, 23, 12);

  test('formatArs uses dot thousands, no decimals unless needed', () {
    expect(formatArs(40000), '40.000');
    expect(formatArs(100000), '100.000');
    expect(formatArs(75000.0), '75.000');
    expect(formatArs(999), '999');
    expect(formatArs(1234567), '1.234.567');
    expect(formatArs(1500.5), '1.500,50');
    expect(formatArsPerMonth(40000), '\$ 40.000 / mes');
  });

  test('coercing readers tolerate numeric strings (numeric columns)', () {
    expect(asDouble('40000.00'), 40000);
    expect(asInt(10), 10);
    expect(asInt('10'), 10);
    expect(asStr(5), '5');
    expect(isValidEmail('test_user_123@testuser.com'), isTrue);
    expect(isValidEmail('nope'), isFalse);
  });

  test('status mapping', () {
    expect(sub(status: 'pending', isActive: false).statusAt(now), BillingStatus.pending);
    expect(sub(endsAt: '2026-12-01T00:00:00Z').statusAt(now), BillingStatus.active);
    expect(sub(status: 'paused', endsAt: '2026-12-01T00:00:00Z').statusAt(now), BillingStatus.paused);
    expect(sub(status: 'cancelled', endsAt: '2026-12-01T00:00:00Z').statusAt(now), BillingStatus.cancelled);
    expect(sub(status: 'expired', isActive: false).statusAt(now), BillingStatus.expired);
    expect(sub(source: 'manual', endsAt: '2026-12-01T00:00:00Z').statusAt(now), BillingStatus.manual);
    expect(sub(source: 'manual', endsAt: '2026-11-01T00:00:00Z').statusAt(now), BillingStatus.expired);
  });

  test('past_due: grace days, then expired', () {
    final inGrace = sub(
      status: 'past_due',
      endsAt: '2026-11-20T00:00:00Z',
      graceUntil: '2026-11-26T00:00:00Z',
    );
    expect(inGrace.statusAt(now), BillingStatus.pastDue);
    expect(inGrace.graceDaysLeft(now), 3);
    expect(billingStatusLabel(BillingStatus.pastDue, graceDays: 3), 'Pago atrasado · 3 días de gracia');
    final lapsed = sub(
      status: 'past_due',
      endsAt: '2026-11-10T00:00:00Z',
      graceUntil: '2026-11-15T00:00:00Z',
    );
    expect(lapsed.statusAt(now), BillingStatus.expired);
  });

  test('cancel only offered for live Mercado Pago subscriptions', () {
    expect(sub(endsAt: '2026-12-01T00:00:00Z').canCancel(now), isTrue);
    expect(sub(status: 'cancelled', endsAt: '2026-12-01T00:00:00Z').canCancel(now), isFalse);
    expect(sub(source: 'manual', endsAt: '2026-12-01T00:00:00Z').canCancel(now), isFalse);
    expect(sub(status: 'pending', isActive: false).canCancel(now), isFalse);
  });

  test('pickCurrent prefers access, then recent pending, ignores abandoned', () {
    final abandoned = sub(status: 'cancelled', isActive: false, createdAt: '2026-11-23T10:00:00Z');
    final pending = sub(status: 'pending', isActive: false, createdAt: '2026-11-23T11:00:00Z');
    final live = sub(endsAt: '2026-12-01T00:00:00Z', lastPaymentAt: '2026-11-01T00:00:00Z');
    final ended = sub(status: 'expired', isActive: false, lastPaymentAt: '2026-09-01T00:00:00Z');

    expect(BillingSubscription.pickCurrent([pending, live], now), same(live));
    expect(BillingSubscription.pickCurrent([pending, abandoned], now), same(pending));
    expect(BillingSubscription.pickCurrent([abandoned], now), isNull);
    expect(BillingSubscription.pickCurrent([abandoned, ended], now), same(ended));
    final stalePending = sub(status: 'pending', isActive: false, createdAt: '2026-11-01T00:00:00Z');
    expect(BillingSubscription.pickCurrent([stalePending], now), isNull);
  });

  test('student cap: plan max while it grants access, else free cap', () {
    final live = sub(endsAt: '2026-12-01T00:00:00Z', max: 50);
    expect(studentCapFor(live, now), 50);
    expect(studentCapFor(null, now), kFreeStudentCap);
    expect(studentCapFor(sub(status: 'expired', isActive: false, max: 50), now), kFreeStudentCap);
    expect(studentCapFor(sub(endsAt: '2026-12-01T00:00:00Z', max: null), now), isNull);
  });

  test('billingErrorMessage: actionable codes keep server text, others generic', () {
    expect(billingErrorMessage(409, 'Ya tenes una suscripcion activa a este plan'),
        'Ya tenes una suscripcion activa a este plan');
    expect(billingErrorMessage(422, 'Mercado Pago rechazo la solicitud'), 'Mercado Pago rechazo la solicitud');
    expect(billingErrorMessage(401, 'No autorizado'), contains('sesión'));
    expect(billingErrorMessage(502, 'x'), contains('Mercado Pago'));
    expect(billingErrorMessage(null, null), contains('Probá de nuevo'));
  });

  group('renewal buffer (24h, mp + authorized only)', () {
    final ends = now.subtract(const Duration(hours: 12)).toIso8601String();
    final endsOld = now.subtract(const Duration(hours: 30)).toIso8601String();

    test('inside buffer keeps access and cap', () {
      final s = sub(endsAt: ends);
      expect(s.hasAccess(now), isTrue);
      expect(studentCapFor(s, now), 10);
    });
    test('outside buffer loses access', () {
      final s = sub(endsAt: endsOld);
      expect(s.hasAccess(now), isFalse);
      expect(studentCapFor(s, now), kFreeStudentCap);
    });
    test('manual rows are exact', () {
      expect(sub(source: 'manual', endsAt: ends).hasAccess(now), isFalse);
    });
    test('past_due is exact', () {
      expect(sub(status: 'past_due', endsAt: ends).hasAccess(now), isFalse);
    });
  });

  test('plan feature labels are not surfaced (gating pending)', () {
    expect(sub().plan!.featureLabels, isEmpty);
  });
}
