import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/messaging_service.dart';
import '../../services/trainer_service.dart';
import '../shared/chat_screen.dart';

// ---------------------------------------------------------------------------
// TrainerMessagesScreen — inbox of conversations with students.
// ---------------------------------------------------------------------------

class TrainerMessagesScreen extends ConsumerWidget {
  const TrainerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convosAsync = ref.watch(trainerConversationsProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: RedesignColors.primario50, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Mensajes',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          // The redesign theme forces CircleBorder on FABs, which crops the
          // extended label into a circle ("uevo me").
          shape: const StadiumBorder(),
          extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
          icon: const Icon(Icons.edit_outlined),
          label: Text('Nuevo mensaje', style: RedesignType.buttonSm),
          onPressed: () => _startNewChat(context, ref),
        ),
        body: convosAsync.when(
          loading: () => const Center(
            child:
                CircularProgressIndicator(color: RedesignColors.actionPrimary),
          ),
          error: (e, st) {
            if (kDebugMode) {
              debugPrint('messages: load inbox failed: $e\n$st');
            }
            return Center(
              child: Text(
                kDebugMode
                    ? 'No se pudieron cargar los mensajes\n$e'
                    : 'No se pudieron cargar los mensajes',
                textAlign: TextAlign.center,
                style: const TextStyle(color: RedesignColors.primario300),
              ),
            );
          },
          data: (convos) {
            if (convos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color:
                            RedesignColors.secundario300.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chat_bubble_outline_rounded,
                          size: 48, color: RedesignColors.secundario300),
                    ),
                    const SizedBox(height: 20),
                    Text('Sin mensajes todavía',
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        )),
                    const SizedBox(height: 8),
                    Text(
                      'Tocá "Nuevo mensaje" para\nempezar una conversación.',
                      textAlign: TextAlign.center,
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario300),
                    ),
                  ],
                ),
              );
            }
            return RefreshIndicator(
              color: RedesignColors.actionPrimary,
              onRefresh: () async =>
                  ref.invalidate(trainerConversationsProvider),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                itemCount: convos.length,
                itemBuilder: (context, i) =>
                    _ConversationTile(convo: convos[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Pick one of the trainer's students and open (or start) the conversation.
/// A conversation is keyed by athlete_id, so "creating" one is just opening
/// the chat; the first message sent creates the thread.
Future<void> _startNewChat(BuildContext context, WidgetRef ref) async {
  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: RedesignColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _StudentPickerSheet(),
  );
  if (picked == null || !context.mounted) return;

  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        athleteId: picked['id'] as String,
        title: (picked['name'] ?? 'Alumno').toString(),
        viewerRole: 'trainer',
      ),
    ),
  );
  ref.invalidate(trainerConversationsProvider);
  ref.invalidate(trainerUnreadProvider);
}

class _StudentPickerSheet extends ConsumerWidget {
  const _StudentPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(myStudentsProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Elegí un alumno',
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            Flexible(
              child: studentsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: RedesignColors.actionPrimary),
                  ),
                ),
                error: (e, st) {
                  if (kDebugMode) {
                    debugPrint('messages: load students failed: $e\n$st');
                  }
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      kDebugMode
                          ? 'No se pudieron cargar los alumnos\n$e'
                          : 'No se pudieron cargar los alumnos',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: RedesignColors.primario300),
                    ),
                  );
                },
                data: (students) {
                  if (students.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Todavía no tenés alumnos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: RedesignColors.primario300),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    itemCount: students.length,
                    itemBuilder: (context, i) {
                      final s = students[i];
                      final name = (s['name'] ?? 'Alumno').toString();
                      final avatarUrl = s['avatar_url'] as String?;
                      final hasAvatar =
                          avatarUrl != null && avatarUrl.isNotEmpty;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: RedesignColors.primario700,
                          backgroundImage:
                              hasAvatar ? NetworkImage(avatarUrl) : null,
                          child: hasAvatar
                              ? null
                              : Text(
                                  name.trim().isNotEmpty
                                      ? name.trim()[0].toUpperCase()
                                      : 'A',
                                  style: const TextStyle(
                                    color: RedesignColors.primario50,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        title: Text(
                          name,
                          style: RedesignType.bodySm
                              .copyWith(color: RedesignColors.primario50),
                        ),
                        onTap: () => Navigator.of(context).pop(s),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Map<String, dynamic> convo;

  const _ConversationTile({required this.convo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (convo['name'] ?? 'Alumno').toString();
    final lastBody = (convo['last_body'] ?? '').toString();
    final lastSender = (convo['last_sender'] ?? '').toString();
    final unread = (convo['unread'] as int?) ?? 0;
    final avatarUrl = convo['avatar_url'] as String?;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';

    final preview =
        lastSender == 'trainer' ? 'Vos: $lastBody' : lastBody;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(RedesignRadius.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(RedesignRadius.card),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  athleteId: convo['athlete_id'] as String,
                  title: name,
                  viewerRole: 'trainer',
                ),
              ),
            );
            ref.invalidate(trainerConversationsProvider);
            ref.invalidate(trainerUnreadProvider);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: RedesignColors.primario700,
                  backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: (avatarUrl == null || avatarUrl.isEmpty)
                      ? Text(initial,
                          style: const TextStyle(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w700,
                          ))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.bodySm.copyWith(
                          color: RedesignColors.primario50,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.label.copyWith(
                          color: unread > 0
                              ? RedesignColors.primario50
                              : RedesignColors.primario300,
                          fontWeight:
                              unread > 0 ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _relTime(convo['last_at']?.toString()),
                      style: RedesignType.label
                          .copyWith(color: RedesignColors.primario400),
                    ),
                    const SizedBox(height: 6),
                    if (unread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: const BoxDecoration(
                          color: RedesignColors.actionPrimary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        child: Text(
                          '$unread',
                          textAlign: TextAlign.center,
                          style: RedesignType.label.copyWith(
                            color: RedesignColors.onActionPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays >= 1) return DateFormat('dd/MM').format(dt);
    return DateFormat('HH:mm').format(dt);
  }
}
