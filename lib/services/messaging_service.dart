import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';
import 'supabase_service.dart';

/// Service for the 1:1 student↔trainer chat (messages table).
class MessagingService {
  final SupabaseClient _client;
  final SupabaseService _supabaseService;

  MessagingService(this._client, this._supabaseService);

  /// Live-updating message list for one conversation (Realtime stream).
  Stream<List<Message>> watchMessages(String athleteId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('athlete_id', athleteId)
        .order('created_at')
        .map((rows) => rows.map((r) => Message.fromJson(r)).toList());
  }

  /// Send a message as [senderRole] ('student' | 'trainer') and drop an in-app
  /// notification to the other participant.
  Future<void> sendMessage({
    required String athleteId,
    required String senderRole,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    await _client.from('messages').insert({
      'athlete_id': athleteId,
      'sender_role': senderRole,
      'body': trimmed,
    });

    await _notifyRecipient(athleteId, senderRole, trimmed);
  }

  Future<void> _notifyRecipient(
    String athleteId,
    String senderRole,
    String body,
  ) async {
    try {
      final row = await _client
          .from('athletes')
          .select('user_id, name, trainer_id, trainers(user_id, name)')
          .eq('id', athleteId)
          .maybeSingle();
      if (row == null) return;

      final trainer = row['trainers'] as Map<String, dynamic>?;
      final athleteName = (row['name'] as String?)?.trim();
      final trainerName = (trainer?['name'] as String?)?.trim();

      String? recipientUserId;
      String title;
      String message;

      if (senderRole == 'student') {
        recipientUserId = trainer?['user_id'] as String?;
        title = 'Nuevo mensaje';
        message = (athleteName != null && athleteName.isNotEmpty)
            ? '$athleteName: $body'
            : body;
      } else {
        recipientUserId = row['user_id'] as String?;
        title = (trainerName != null && trainerName.isNotEmpty)
            ? 'Mensaje de $trainerName'
            : 'Mensaje de tu entrenador';
        message = body;
      }

      if (recipientUserId == null) return;

      await _supabaseService.createNotification(
        userId: recipientUserId,
        type: 'message',
        title: title,
        message: message,
        data: {'athlete_id': athleteId},
      );
    } catch (e) {
      // A failed notification must not fail the send.
      debugPrint('messaging: notify recipient failed: $e');
    }
  }

  /// Mark the other party's unread messages in this conversation as read.
  Future<void> markRead(String athleteId, String viewerRole) async {
    final otherRole = viewerRole == 'trainer' ? 'student' : 'trainer';
    try {
      await _client
          .from('messages')
          .update({'is_read': true})
          .eq('athlete_id', athleteId)
          .eq('sender_role', otherRole)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('messaging: markRead failed: $e');
    }
  }

  /// Conversations for the trainer inbox: one row per athlete that has at least
  /// one message, with the last message and unread (from-student) count.
  Future<List<Map<String, dynamic>>> getTrainerConversations() async {
    // RLS limits these rows to the trainer's own athletes.
    final rows = await _client
        .from('messages')
        .select('athlete_id, sender_role, body, is_read, created_at')
        .order('created_at', ascending: false);

    final byAthlete = <String, Map<String, dynamic>>{};
    for (final r in List<Map<String, dynamic>>.from(rows)) {
      final aid = r['athlete_id'] as String?;
      if (aid == null) continue;
      final entry = byAthlete.putIfAbsent(
        aid,
        () => {
          'athlete_id': aid,
          'last_body': r['body'],
          'last_at': r['created_at'],
          'last_sender': r['sender_role'],
          'unread': 0,
        },
      );
      if (r['sender_role'] == 'student' && (r['is_read'] as bool?) != true) {
        entry['unread'] = (entry['unread'] as int) + 1;
      }
    }

    if (byAthlete.isEmpty) return [];

    // Attach athlete name + avatar.
    final athleteRows = await _client
        .from('athletes')
        .select('id, name, avatar_url, profiles(avatar_url)')
        .inFilter('id', byAthlete.keys.toList());
    for (final a in List<Map<String, dynamic>>.from(athleteRows)) {
      final aid = a['id'] as String?;
      final conv = aid != null ? byAthlete[aid] : null;
      if (conv == null) continue;
      final profile = a['profiles'] as Map<String, dynamic>?;
      conv['name'] = (a['name'] ?? 'Alumno').toString();
      conv['avatar_url'] =
          (a['avatar_url'] as String?) ?? (profile?['avatar_url'] as String?);
    }

    final list = byAthlete.values.toList()
      ..sort((a, b) => (b['last_at']?.toString() ?? '')
          .compareTo(a['last_at']?.toString() ?? ''));
    return list;
  }

  /// Total unread (from-student) messages across all the trainer's students.
  Future<int> trainerUnreadTotal() async {
    final rows = await _client
        .from('messages')
        .select('id')
        .eq('sender_role', 'student')
        .eq('is_read', false);
    return (rows as List).length;
  }

  /// Unread (from-trainer) messages for one athlete — the student badge.
  Future<int> studentUnread(String athleteId) async {
    final rows = await _client
        .from('messages')
        .select('id')
        .eq('athlete_id', athleteId)
        .eq('sender_role', 'trainer')
        .eq('is_read', false);
    return (rows as List).length;
  }
}

final messagingServiceProvider = Provider<MessagingService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  return MessagingService(client, supabaseService);
});

/// Live message list for a conversation.
final messagesStreamProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, athleteId) {
  return ref.watch(messagingServiceProvider).watchMessages(athleteId);
});

/// Trainer inbox conversations.
final trainerConversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(messagingServiceProvider).getTrainerConversations();
});

/// Trainer home unread badge.
final trainerUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.watch(messagingServiceProvider).trainerUnreadTotal();
});

/// Student home unread badge.
final studentUnreadProvider =
    FutureProvider.autoDispose.family<int, String>((ref, athleteId) async {
  return ref.watch(messagingServiceProvider).studentUnread(athleteId);
});
