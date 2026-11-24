import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/billing_format.dart';
import '../models/billing_plan.dart';
import '../models/billing_subscription.dart';
import '../models/mp_payment.dart';
import 'supabase_service.dart';

/// Students a trainer may have without any paid plan (server default cap,
/// see private.billing_student_cap in add_mp_billing.sql).
const int kFreeStudentCap = 10;

/// Error with a user-facing Spanish message.
class BillingException implements Exception {
  final String message;
  const BillingException(this.message);
  @override
  String toString() => message;
}

/// Maps an Edge Function failure to a friendly message. 400/404/409/422/429
/// carry actionable Spanish text from the function itself; anything else
/// (auth, 5xx, network) gets a generic message.
String billingErrorMessage(int? status, String? serverMessage) {
  final msg = serverMessage?.trim();
  const actionable = {400, 404, 409, 422, 429};
  if (status != null && actionable.contains(status) && msg != null && msg.isNotEmpty) {
    return msg;
  }
  if (status == 401 || status == 403) {
    return 'Tu sesión expiró. Volvé a iniciar sesión e intentá de nuevo.';
  }
  return 'No pudimos conectar con Mercado Pago. Probá de nuevo en unos minutos.';
}

/// Max students for the trainer's current subscription (null = unlimited).
int? studentCapFor(BillingSubscription? current, DateTime now) {
  if (current != null && current.hasAccess(now)) return current.plan?.maxStudents;
  return kFreeStudentCap;
}

/// Trainer billing: reads plans / subscription / payments (RLS-scoped) and
/// calls the mp-subscribe / mp-manage Edge Functions. No Mercado Pago token
/// ever lives here; access is granted only by the server-side webhook.
class BillingService {
  final SupabaseClient _client;
  BillingService(this._client);

  /// Active trainer plans, cheapest first.
  Future<List<BillingPlan>> getPlans() async {
    final res = await _client
        .from('subscription_plans')
        .select()
        .eq('audience', 'trainer')
        .eq('is_active', true)
        .order('price', ascending: true);
    return (res as List)
        .map((e) => BillingPlan.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Recent subscription rows of the signed-in payer, newest first.
  Future<List<BillingSubscription>> getSubscriptions() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await _client
        .from('trainer_subscriptions')
        .select('*, subscription_plans(*)')
        .eq('payer_user_id', uid)
        .order('created_at', ascending: false)
        .limit(10);
    return (res as List)
        .map((e) =>
            BillingSubscription.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<BillingSubscription?> getCurrentSubscription() async =>
      BillingSubscription.pickCurrent(
          await getSubscriptions(), DateTime.now());

  Future<List<MpPayment>> getPayments() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final res = await _client
        .from('mp_payments')
        .select('id, amount, currency_id, status, paid_at, created_at')
        .eq('payer_user_id', uid)
        .order('created_at', ascending: false)
        .limit(20);
    return (res as List)
        .map((e) => MpPayment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Creates a pending subscription and returns the Mercado Pago checkout URL.
  Future<({String initPoint, String subscriptionId})> subscribe({
    required String planId,
    required String payerEmail,
  }) async {
    final data = await _invoke('mp-subscribe', {
      'plan_id': planId,
      'payer_email': payerEmail.trim(),
    });
    final url = asStr(data['init_point']);
    final id = asStr(data['subscription_id']);
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || id == null) {
      throw const BillingException(
          'Mercado Pago no devolvió un link de pago válido. Probá de nuevo.');
    }
    return (initPoint: url!, subscriptionId: id);
  }

  /// Cancels a Mercado Pago subscription (access continues until ends_at).
  Future<void> cancel(String subscriptionId) async {
    await _invoke('mp-manage', {
      'action': 'cancel',
      'subscription_id': subscriptionId,
    });
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

final billingServiceProvider = Provider<BillingService>((ref) {
  return BillingService(ref.watch(supabaseClientProvider));
});

// autoDispose: billing state must be fresh every time a screen opens. The
// root ProviderScope is keyed by user id, so nothing leaks across users.
final billingPlansProvider =
    FutureProvider.autoDispose<List<BillingPlan>>((ref) {
  return ref.watch(billingServiceProvider).getPlans();
});

final billingSubscriptionProvider =
    FutureProvider.autoDispose<BillingSubscription?>((ref) {
  return ref.watch(billingServiceProvider).getCurrentSubscription();
});

final billingPaymentsProvider =
    FutureProvider.autoDispose<List<MpPayment>>((ref) {
  return ref.watch(billingServiceProvider).getPayments();
});
