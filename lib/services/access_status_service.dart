import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'supabase_service.dart';

/// Result of the server-side "am I blocked?" check for the signed-in student.
class AccessStatus {
  final bool blocked;
  final String? reason;
  final String? trainerName;

  const AccessStatus({
    required this.blocked,
    this.reason,
    this.trainerName,
  });

  static const open = AccessStatus(blocked: false);
}

/// Asks the DB (`my_access_status`) whether the student is blocked — manual
/// block OR automatic cutoff after the renewal date. The rule lives only in
/// the DB. Fails OPEN on errors/offline so a network blip never locks anyone
/// out. Non-students always get [AccessStatus.open].
final accessStatusProvider = FutureProvider<AccessStatus>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null || user.role != UserRole.student) return AccessStatus.open;
  try {
    final rows = await ref
        .read(supabaseClientProvider)
        .rpc('my_access_status') as List;
    if (rows.isEmpty) return AccessStatus.open;
    final r = Map<String, dynamic>.from(rows.first as Map);
    return AccessStatus(
      blocked: r['blocked'] == true,
      reason: r['reason'] as String?,
      trainerName: r['trainer_name'] as String?,
    );
  } catch (e) {
    debugPrint('accessStatus check failed (fail-open): $e');
    return AccessStatus.open;
  }
});
