import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/theme_redesign.dart';
import '../../models/message_model.dart';
import '../../services/messaging_service.dart';

// ---------------------------------------------------------------------------
// ChatScreen — shared 1:1 conversation view for both student and trainer.
//
// [viewerRole] is 'student' or 'trainer'; a message is "mine" when its
// sender_role matches the viewer. Live-updates via messagesStreamProvider.
// ---------------------------------------------------------------------------

class ChatScreen extends ConsumerStatefulWidget {
  final String athleteId;
  final String title;
  final String viewerRole; // 'student' | 'trainer'

  const ChatScreen({
    super.key,
    required this.athleteId,
    required this.title,
    required this.viewerRole,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markRead() async {
    await ref
        .read(messagingServiceProvider)
        .markRead(widget.athleteId, widget.viewerRole);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      await ref.read(messagingServiceProvider).sendMessage(
            athleteId: widget.athleteId,
            senderRole: widget.viewerRole,
            body: text,
          );
    } catch (_) {
      if (mounted) {
        _inputCtrl.text = text; // restore on failure
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el mensaje')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.athleteId));

    // Mark incoming messages read as they arrive while the view is open.
    ref.listen(messagesStreamProvider(widget.athleteId), (_, next) {
      next.whenData((_) {
        _markRead();
        _scrollToBottom();
      });
    });

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
            widget.title,
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: RedesignColors.actionPrimary),
                ),
                error: (_, __) => const Center(
                  child: Text('No se pudo cargar la conversación',
                      style: TextStyle(color: RedesignColors.primario300)),
                ),
                data: (messages) {
                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        'Todavía no hay mensajes.\n¡Escribí el primero!',
                        textAlign: TextAlign.center,
                        style: RedesignType.label
                            .copyWith(color: RedesignColors.primario300),
                      ),
                    );
                  }
                  _scrollToBottom();
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      final mine = m.senderRole == widget.viewerRole;
                      return _Bubble(message: m, mine: mine);
                    },
                  );
                },
              ),
            ),
            _Composer(
              controller: _inputCtrl,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final Message message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? RedesignColors.actionPrimary : RedesignColors.primario700;
    final fg = mine ? RedesignColors.onActionPrimary : RedesignColors.primario50;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: RedesignType.bodySm.copyWith(color: fg),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(message.createdAt),
              style: RedesignType.label.copyWith(
                color: fg.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: const InputDecoration(
                  hintText: 'Escribí un mensaje…',
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              height: 48,
              child: Material(
                color: RedesignColors.actionPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: sending ? null : onSend,
                  child: Center(
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: RedesignColors.onActionPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: RedesignColors.onActionPrimary, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
