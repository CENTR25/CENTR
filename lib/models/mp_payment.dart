import '../core/utils/billing_format.dart';

/// One Mercado Pago charge (mp_payments, read-only for the payer via RLS).
class MpPayment {
  final String id;
  final double amount;
  final String currencyId;
  final String status; // approved | rejected | pending | in_process | refunded ...
  final DateTime? paidAt;
  final DateTime? createdAt;

  const MpPayment({
    required this.id,
    required this.amount,
    required this.currencyId,
    required this.status,
    required this.paidAt,
    required this.createdAt,
  });

  DateTime? get date => paidAt ?? createdAt;

  String get statusLabel => mpPaymentStatusLabel(status);

  bool get isApproved => status == 'approved';

  factory MpPayment.fromMap(Map<String, dynamic> m) => MpPayment(
        id: asStr(m['id']) ?? '',
        amount: asDouble(m['amount']) ?? 0,
        currencyId: asStr(m['currency_id']) ?? 'ARS',
        status: asStr(m['status']) ?? 'pending',
        paidAt: asDate(m['paid_at']),
        createdAt: asDate(m['created_at']),
      );
}

String mpPaymentStatusLabel(String status) {
  switch (status) {
    case 'approved':
      return 'Aprobado';
    case 'authorized':
    case 'pending':
    case 'in_process':
    case 'in_mediation':
      return 'Pendiente';
    case 'rejected':
    case 'cancelled':
      return 'Rechazado';
    case 'refunded':
      return 'Reembolsado';
    case 'charged_back':
      return 'Contracargo';
    default:
      return status;
  }
}
