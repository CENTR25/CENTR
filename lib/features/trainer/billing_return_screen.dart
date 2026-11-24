import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/theme_redesign.dart';
import '../../models/billing_subscription.dart';
import '../../services/billing_service.dart';
import '../../services/trainer_service.dart';

enum _ReturnState { waiting, confirmed, timedOut, failed }

// ---------------------------------------------------------------------------
// BillingReturnScreen  (route: /billing/return, also pushed after checkout)
//
// Landing page after Mercado Pago checkout. Arriving here proves NOTHING: it
// only polls the subscription row until the server-side webhook flips it to
// 'authorized' (every 3 s, up to ~60 s). Access is never granted by the app.
// ---------------------------------------------------------------------------

class BillingReturnScreen extends ConsumerStatefulWidget {
  /// Subscription created by mp-subscribe. Null when we land from the
  /// Mercado Pago redirect (full page reload): then the newest row is used.
  final String? subscriptionId;

  const BillingReturnScreen({super.key, this.subscriptionId});

  @override
  ConsumerState<BillingReturnScreen> createState() =>
      _BillingReturnScreenState();
}

class _BillingReturnScreenState extends ConsumerState<BillingReturnScreen> {
  static const _interval = Duration(seconds: 3);
  static const _maxTicks = 20; // ~60 s

  Timer? _timer;
  int _ticks = 0;
  bool _checking = false;
  _ReturnState _state = _ReturnState.waiting;
  String? _upgradeNote;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _ticks = 0;
    setState(() => _state = _ReturnState.waiting);
    _check();
    _timer = Timer.periodic(_interval, (_) => _check());
  }

  Future<void> _check() async {
    if (_checking || !mounted) return;
    _checking = true;
    try {
      final rows = await ref.read(billingServiceProvider).getSubscriptions();
      if (!mounted) return;
      final target = _target(rows);
      if (target != null && target.status == 'authorized' && target.isActive) {
        _timer?.cancel();
        await _supersedeOldSubscriptions(rows, target);
        _refreshProviders();
        if (mounted) setState(() => _state = _ReturnState.confirmed);
        return;
      }
      if (target != null &&
          (target.status == 'cancelled' || target.status == 'expired')) {
        _timer?.cancel();
        if (mounted) setState(() => _state = _ReturnState.failed);
        return;
      }
    } catch (_) {
      // Transient network/RLS error: keep polling until the budget runs out.
    } finally {
      _checking = false;
    }
    _ticks++;
    if (_ticks >= _maxTicks && _state == _ReturnState.waiting) {
      _timer?.cancel();
      if (mounted) setState(() => _state = _ReturnState.timedOut);
    }
  }

  BillingSubscription? _target(List<BillingSubscription> rows) {
    final id = widget.subscriptionId;
    if (id != null) {
      for (final r in rows) {
        if (r.id == id) return r;
      }
      return null;
    }
    // Reload from the MP redirect: newest Mercado Pago row.
    for (final r in rows) {
      if (!r.isManual) return r;
    }
    return null;
  }

  /// Upgrade/downgrade: once the NEW subscription is confirmed 'authorized'
  /// by the webhook, cancel older live Mercado Pago subscriptions so the
  /// trainer is not charged twice (mp-subscribe never cancels them). Cancel
  /// keeps access until the old ends_at and the server cap is the max across
  /// rows, so no access is lost. Only runs after server-confirmed authorization
  /// and only for the payer's own older MP rows; failures are non-fatal.
  Future<void> _supersedeOldSubscriptions(
    List<BillingSubscription> rows,
    BillingSubscription target,
  ) async {
    final created = target.createdAt;
    if (created == null) return;
    final now = DateTime.now();
    final old = rows.where((r) =>
        r.id != target.id &&
        !r.isManual &&
        r.createdAt != null &&
        r.createdAt!.isBefore(created) &&
        r.canCancel(now));
    for (final r in old) {
      try {
        await ref.read(billingServiceProvider).cancel(r.id);
      } on BillingException catch (e) {
        // Server may already have cancelled it (authoritative cancel): fine.
        if (!e.message.toLowerCase().contains('cancelad')) {
          _upgradeNote =
              'No pudimos cancelar tu suscripción anterior. Cancelala desde "Mi suscripción" para no pagar dos veces.';
        }
      } catch (_) {
        _upgradeNote =
            'No pudimos cancelar tu suscripción anterior. Cancelala desde "Mi suscripción" para no pagar dos veces.';
      }
    }
  }

  void _refreshProviders() {
    ref.invalidate(billingSubscriptionProvider);
    ref.invalidate(billingPaymentsProvider);
    ref.invalidate(myTrainerSubscriptionProvider);
  }

  void _close() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(AppRoutes.trainerDashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, body) = switch (_state) {
      _ReturnState.waiting => (
          null,
          RedesignColors.actionPrimary,
          'Esperando confirmación',
          'Estamos verificando tu pago con Mercado Pago. No cierres esta pantalla.',
        ),
      _ReturnState.confirmed => (
          Icons.check_circle_rounded,
          RedesignColors.success,
          '¡Suscripción activa!',
          'Tu pago fue confirmado y tu plan ya está disponible.',
        ),
      _ReturnState.timedOut => (
          Icons.hourglass_bottom_rounded,
          RedesignColors.advertencia400,
          'Estamos confirmando tu pago',
          'Puede tardar unos minutos. Cuando se confirme, tu plan se activa solo. Podés actualizar para volver a verificar.',
        ),
      _ReturnState.failed => (
          Icons.error_outline_rounded,
          RedesignColors.danger,
          'No se completó la suscripción',
          'No recibimos ningún pago. Si fue un error, volvé a elegir un plan.',
        ),
    };

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon == null)
                      const SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          color: RedesignColors.actionPrimary,
                        ),
                      )
                    else
                      Icon(icon, size: 64, color: color),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: RedesignType.headingMd.copyWith(
                        color: RedesignColors.primario50,
                        fontSize: 24,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: RedesignType.bodySm.copyWith(
                        color: RedesignColors.primario300,
                      ),
                    ),
                    if (_state == _ReturnState.confirmed &&
                        _upgradeNote != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _upgradeNote!,
                        textAlign: TextAlign.center,
                        style: RedesignType.label.copyWith(
                          color: RedesignColors.advertencia400,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    if (_state == _ReturnState.timedOut) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _startPolling,
                          child: Text('Actualizar',
                              style: RedesignType.buttonLg.copyWith(
                                  color: RedesignColors.onActionPrimary)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_state != _ReturnState.waiting)
                      TextButton(
                        onPressed: _close,
                        child: Text(
                          _state == _ReturnState.confirmed ? 'Listo' : 'Volver',
                          style: RedesignType.buttonSm.copyWith(
                            color: RedesignColors.actionPrimaryDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
