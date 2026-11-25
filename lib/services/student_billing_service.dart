import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/billing_format.dart';
import 'billing_service.dart' show BillingException, billingErrorMessage;
import 'supabase_service.dart';

/// A student's auto-recurring subscription on the trainer's Mercado Pago.
class StudentSubscription {
  final String id;
  final String status; // pending | authorized | paused | cancelled
  final double amount;
  final String? initPoint;
  final DateTime? nextPaymentDate;
  final DateTime? lastPaymentAt;

  const StudentSubscription({
    required this.id,
    required this.status,
    required this.amount,
    this.initPoint,
    this.nextPaymentDate,
    this.lastPaymentAt,
  });

  factory StudentSubscription.fromMap(Map<String, dynamic> m) =>
      StudentSubscription(
        id: asStr(m['id'])!,
        status: asStr(m['status']) ?? 'pending',
        amount: double.tryParse(asStr(m['amount']) ?? '') ?? 0,
        initPoint: asStr(m['init_point']),
        nextPaymentDate: DateTime.tryParse(asStr(m['next_payment_date']) ?? '')
            ?.toLocal(),
        lastPaymentAt:
            DateTime.tryParse(asStr(m['last_payment_at']) ?? '')?.toLocal(),
      );
}

/// Trainer-side: connect the trainer's own Mercado Pago account and bill
/// students through it. No token ever reaches the app; the Edge Functions
/// hold them (encrypted) and the webhook is the only thing that records
/// payments / moves due dates.
class StudentBillingService {
  final SupabaseClient _client;
  StudentBillingService(this._client);

  Future<bool> isMpConnected() async {
    final rows = await _client.rpc('my_mp_connection') as List;
    return rows.isNotEmpty;
  }

  /// URL the trainer must open to authorize PRGS on their Mercado Pago account.
  Future<String> startConnect() async {
    final data = await _invoke('mp-connect', {'action': 'start'});
    final url = asStr(data['url']);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const BillingException('No se pudo iniciar la conexión.');
    }
    return url!;
  }

  Future<void> disconnect() async {
    await _invoke('mp-connect', {'action': 'disconnect'});
  }

  /// Latest non-cancelled subscription of a student (or the latest at all).
  Future<StudentSubscription?> getSubscription(String athleteId) async {
    final rows = await _client
        .from('student_subscriptions')
        .select(
            'id, status, amount, init_point, next_payment_date, last_payment_at')
        .eq('athlete_id', athleteId)
        .order('created_at', ascending: false)
        .limit(5);
    final list = (rows as List)
        .map((e) =>
            StudentSubscription.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (list.isEmpty) return null;
    return list.firstWhere((s) => s.status != 'cancelled',
        orElse: () => list.first);
  }

  /// Creates the subscription; returns the link the STUDENT must open to pay.
  Future<({String initPoint, String subscriptionId})> subscribe(
    String athleteId, {
    String? payerEmail,
  }) async {
    final data = await _invoke('mp-student-subscribe', {
      'athlete_id': athleteId,
      if (payerEmail != null && payerEmail.trim().isNotEmpty)
        'payer_email': payerEmail.trim(),
    });
    final url = asStr(data['init_point']);
    final id = asStr(data['subscription_id']);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || id == null) {
      throw const BillingException(
          'Mercado Pago no devolvió un link de pago válido.');
    }
    return (initPoint: url!, subscriptionId: id);
  }

  Future<void> manage(String subscriptionId, String action) async {
    await _invoke('mp-student-manage',
        {'action': action, 'subscription_id': subscriptionId});
  }

  Future<Map<String, dynamic>> _invoke(
      String fn, Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke(fn, body: body);
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      throw const BillingException('Respuesta inesperada del servidor.');
    } on FunctionException catch (e) {
      final details = e.details;
      final msg = details is Map ? asStr(details['error']) : null;
      throw BillingException(billingErrorMessage(e.status, msg));
    } on BillingException {
      rethrow;
    } catch (_) {
      throw BillingException(billingErrorMessage(null, null));
    }
  }
}

final studentBillingServiceProvider = Provider<StudentBillingService>((ref) {
  return StudentBillingService(ref.watch(supabaseClientProvider));
});

final mpConnectedProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(studentBillingServiceProvider).isMpConnected();
});

final studentSubscriptionProvider = FutureProvider.autoDispose
    .family<StudentSubscription?, String>((ref, athleteId) {
  return ref.watch(studentBillingServiceProvider).getSubscription(athleteId);
});
