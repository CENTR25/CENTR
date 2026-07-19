import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_service.dart';
import '../models/notification_model.dart';

/// Provider for notifications list for a given userId
final notificationsProvider = FutureProvider.family<List<NotificationModel>, String>((ref, userId) async {
  final service = ref.read(supabaseServiceProvider);
  final rawList = await service.getNotifications(userId);
  return rawList.map((json) => NotificationModel.fromJson(json)).toList();
});

/// Provider for unread notification count for a given userId
final unreadCountProvider = FutureProvider.family<int, String>((ref, userId) async {
  final service = ref.read(supabaseServiceProvider);
  return service.getUnreadNotificationCount(userId);
});
