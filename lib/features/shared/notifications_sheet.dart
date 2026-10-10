import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/theme_redesign.dart';
import '../../models/notification_model.dart';
import '../../services/notification_providers.dart';
import '../../services/supabase_service.dart';

/// Shows the notifications bottom sheet for a given user.
void showNotificationsSheet(BuildContext context, String userId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => NotificationsSheet(userId: userId),
  );
}

/// Reusable notifications bottom sheet (PRGS redesign) for both student and
/// trainer dashboards — navy→teal gradient, flat list with teal unread dots.
class NotificationsSheet extends ConsumerStatefulWidget {
  final String userId;

  const NotificationsSheet({super.key, required this.userId});

  @override
  ConsumerState<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends ConsumerState<NotificationsSheet> {
  bool _markingAll = false;
  // Optimistic deletions: IDs removed by swipe before the provider refreshes.
  final Set<String> _deleted = {};

  Future<void> _markAllAsRead() async {
    setState(() => _markingAll = true);
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.markAllNotificationsAsRead(widget.userId);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.markNotificationAsRead(notificationId);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    setState(() => _deleted.add(notificationId));
    try {
      final service = ref.read(supabaseServiceProvider);
      await service.deleteNotification(notificationId);
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      if (mounted) setState(() => _deleted.remove(notificationId));
    }
  }

  static const List<String> _weekdays = [
    'lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'
  ];
  static const List<String> _months = [
    '', 'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  String _timeAgo(DateTime dateTime) {
    final local = dateTime.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      final h = diff.inHours;
      return 'hace $h ${h == 1 ? 'hora' : 'horas'}';
    }
    if (diff.inDays < 7) {
      return '${_weekdays[local.weekday - 1]} ${local.day} ${_months[local.month]}';
    }
    return '${local.day} ${_months[local.month]}';
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider(widget.userId));

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      RedesignColors.primario950, // navy
                      Color(0xFF0C443D), // muted teal
                    ],
                  ),
                ),
                child: notificationsAsync.when(
                  loading: () => _scaffold(
                    context,
                    unread: 0,
                    body: const Center(
                      child: CircularProgressIndicator(
                          color: RedesignColors.actionPrimary),
                    ),
                  ),
                  error: (err, _) => _scaffold(
                    context,
                    unread: 0,
                    body: Center(
                      child: Text(
                        'Error al cargar notificaciones',
                        style: TextStyle(
                            color: RedesignColors.primario300, fontSize: 14),
                      ),
                    ),
                  ),
                  data: (notifications) {
                    final visible = notifications
                        .where((n) => !_deleted.contains(n.id))
                        .toList();
                    final unread =
                        visible.where((n) => !n.isRead).length;
                    return _scaffold(
                      context,
                      unread: unread,
                      body: visible.isEmpty
                          ? _empty()
                          : ListView.separated(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(24, 8, 24, 40),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) => Divider(
                                color: Colors.white.withValues(alpha: 0.08),
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final notif = visible[index];
                                return Dismissible(
                                  key: ValueKey(notif.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 8),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: RedesignColors.peligro300,
                                      size: 22,
                                    ),
                                  ),
                                  onDismissed: (_) =>
                                      _deleteNotification(notif.id),
                                  child: _NotificationTile(
                                    notification: notif,
                                    timeAgo: _timeAgo(notif.createdAt),
                                    onTap: () {
                                      if (!notif.isRead) {
                                        _markAsRead(notif.id);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Shared chrome: handle, X, title + "Marcar leídas", unread count, divider.
  Widget _scaffold(
    BuildContext context, {
    required int unread,
    required Widget body,
  }) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Close
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 12, top: 4),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded,
                  color: RedesignColors.primario200, size: 26),
            ),
          ),
        ),
        // Title + Marcar leídas
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'Notificaciones',
                  style: TextStyle(
                    fontFamily: 'Metropolis',
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _markingAll ? null : _markAllAsRead,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _markingAll
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RedesignColors.primario200),
                        )
                      : const Text(
                          'Marcar leídas',
                          style: TextStyle(
                            fontFamily: 'Metropolis',
                            color: RedesignColors.primario200,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
        if (unread > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$unread sin leer',
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario300,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
          child: Divider(color: Colors.white.withValues(alpha: 0.12), height: 1),
        ),
        Expanded(child: body),
      ],
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              color: Colors.white.withValues(alpha: 0.35),
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              'No hay notificaciones',
              style: TextStyle(
                fontFamily: 'Metropolis',
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Aparecerán aquí cuando recibas novedades',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final String timeAgo;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.timeAgo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (unread) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: RedesignColors.actionPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    notification.title,
                    style: const TextStyle(
                      fontFamily: 'Metropolis',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: EdgeInsets.only(left: unread ? 18 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      notification.message,
                      style: TextStyle(
                        fontFamily: 'Metropolis',
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontFamily: 'Metropolis',
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
