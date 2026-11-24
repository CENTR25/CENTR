import '../core/utils/billing_format.dart';
import 'billing_plan.dart';

/// What the UI shows for a subscription (derived from status + dates).
enum BillingStatus {
  pending, // checkout started, payment not confirmed yet
  active,
  pastDue, // charge failed, still inside the grace window
  paused,
  cancelled, // cancelled; may still have access until ends_at
  expired,
  manual, // plan assigned by PRGS (source = 'manual'), still valid
}

/// Renewal buffer: the server (private.billing_student_cap) keeps access this
/// long past ends_at for source='mp' + status 'authorized' rows ONLY, so a
/// renewal charge that lands slightly late never locks the trainer out.
/// Manual rows and every other status use the exact date. Keep in sync.
const Duration kMpRenewalBuffer = Duration(hours: 24);

/// A row of trainer_subscriptions with its plan. Billing writes come only from
/// Edge Functions; the app only reads this and calls mp-manage / mp-subscribe.
class BillingSubscription {
  final String id;
  final String source; // 'mp' | 'manual'
  final String status; // pending | authorized | paused | past_due | cancelled | expired
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt; // paid-through date
  final DateTime? nextPaymentDate;
  final DateTime? graceUntil;
  final DateTime? lastPaymentAt;
  final DateTime? createdAt;
  final bool cancelAtPeriodEnd;
  final String? payerEmail;
  final BillingPlan? plan;

  const BillingSubscription({
    required this.id,
    required this.source,
    required this.status,
    required this.isActive,
    required this.startsAt,
    required this.endsAt,
    required this.nextPaymentDate,
    required this.graceUntil,
    required this.lastPaymentAt,
    required this.createdAt,
    required this.cancelAtPeriodEnd,
    required this.payerEmail,
    required this.plan,
  });

  factory BillingSubscription.fromMap(Map<String, dynamic> m) {
    final p = m['subscription_plans'];
    return BillingSubscription(
      id: asStr(m['id']) ?? '',
      source: asStr(m['source']) ?? 'manual',
      status: asStr(m['status']) ?? 'authorized',
      isActive: asBool(m['is_active']),
      startsAt: asDate(m['starts_at']),
      endsAt: asDate(m['ends_at']),
      nextPaymentDate: asDate(m['next_payment_date']),
      graceUntil: asDate(m['grace_until']),
      lastPaymentAt: asDate(m['last_payment_at']),
      createdAt: asDate(m['created_at']),
      cancelAtPeriodEnd: asBool(m['cancel_at_period_end']),
      payerEmail: asStr(m['payer_email']),
      plan: p is Map ? BillingPlan.fromMap(Map<String, dynamic>.from(p)) : null,
    );
  }

  bool get isManual => source == 'manual';

  /// Latest moment the trainer still has access (mirrors the server's
  /// greatest(ends_at, grace_until)).
  DateTime? get accessUntil {
    if (endsAt == null) return graceUntil;
    if (graceUntil == null) return endsAt;
    return graceUntil!.isAfter(endsAt!) ? graceUntil : endsAt;
  }

  /// Same rule as private.billing_student_cap on the server.
  bool hasAccess(DateTime now) {
    if (!isActive || status == 'pending') return false;
    final until = accessUntil;
    if (until == null) return false;
    final buffered = source == 'mp' && status == 'authorized'
        ? until.add(kMpRenewalBuffer)
        : until;
    return now.isBefore(buffered);
  }

  BillingStatus statusAt(DateTime now) {
    if (isManual) {
      final until = endsAt;
      return until != null && now.isBefore(until)
          ? BillingStatus.manual
          : BillingStatus.expired;
    }
    switch (status) {
      case 'pending':
        return BillingStatus.pending;
      case 'authorized':
        return BillingStatus.active;
      case 'past_due':
        return hasAccess(now) ? BillingStatus.pastDue : BillingStatus.expired;
      case 'paused':
        return BillingStatus.paused;
      case 'cancelled':
        return BillingStatus.cancelled;
      default:
        return BillingStatus.expired;
    }
  }

  /// Whole days of grace left (rounded up), 0 when none.
  int graceDaysLeft(DateTime now) {
    final g = graceUntil;
    if (g == null || !now.isBefore(g)) return 0;
    return (g.difference(now).inHours / 24).ceil();
  }

  /// "Cancelar suscripción" only makes sense for a live Mercado Pago sub.
  bool canCancel(DateTime now) {
    if (isManual) return false;
    final s = statusAt(now);
    return s == BillingStatus.active ||
        s == BillingStatus.pastDue ||
        s == BillingStatus.paused;
  }

  /// The subscription to show as "current" out of the trainer's rows
  /// (newest first): the one granting access, else a recent pending checkout,
  /// else the latest ended one that was actually paid/assigned. Rows that were
  /// never paid and got cancelled (abandoned checkouts) are ignored.
  static BillingSubscription? pickCurrent(
    List<BillingSubscription> rows,
    DateTime now,
  ) {
    for (final r in rows) {
      if (r.hasAccess(now)) return r;
    }
    for (final r in rows) {
      final created = r.createdAt;
      if (r.status == 'pending' &&
          created != null &&
          now.difference(created) < const Duration(hours: 24)) {
        return r;
      }
    }
    for (final r in rows) {
      if (r.status == 'pending') continue;
      final abandoned = !r.isManual && r.lastPaymentAt == null;
      if (!abandoned) return r;
    }
    return null;
  }
}

/// Spanish chip label for a status. [graceDays] only used for pastDue.
String billingStatusLabel(BillingStatus s, {int graceDays = 0}) {
  switch (s) {
    case BillingStatus.pending:
      return 'Pendiente';
    case BillingStatus.active:
      return 'Activa';
    case BillingStatus.pastDue:
      return graceDays > 0
          ? 'Pago atrasado · $graceDays ${graceDays == 1 ? 'día' : 'días'} de gracia'
          : 'Pago atrasado';
    case BillingStatus.paused:
      return 'Pausada';
    case BillingStatus.cancelled:
      return 'Cancelada';
    case BillingStatus.expired:
      return 'Vencida';
    case BillingStatus.manual:
      return 'Plan asignado por PRGS';
  }
}
