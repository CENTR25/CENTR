import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/theme/theme_redesign.dart';
import '../../models/message_model.dart';
import '../../services/messaging_service.dart';
import 'chat_media.dart';

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
  final _recorder = AudioRecorder();
  final _recWatch = Stopwatch();
  Timer? _recTimer;
  bool _sending = false;
  bool _recording = false;
  String _recExt = 'm4a';
  String _recMime = 'audio/mp4';

  static const _maxRecording = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _markRead();
  }

  @override
  void dispose() {
    _recTimer?.cancel();
    _recorder.dispose();
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('chat: send failed: $e');
      }
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

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _sendAttachment({
    required String type,
    required Uint8List bytes,
    required String ext,
    required String mime,
    int? durationMs,
  }) async {
    setState(() => _sending = true);
    try {
      await ref.read(messagingServiceProvider).sendAttachment(
            athleteId: widget.athleteId,
            senderRole: widget.viewerRole,
            type: type,
            bytes: bytes,
            extension: ext,
            contentType: mime,
            durationMs: durationMs,
          );
    } catch (e) {
      if (kDebugMode) debugPrint('chat: send $type failed: $e');
      _snack(type == 'image'
          ? 'No se pudo enviar la foto'
          : 'No se pudo enviar el audio');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Photo from the gallery, downscaled + recompressed on pick (≤1600px,
  /// quality 75 → typically 200–400 KB) so chats don't fill the bucket.
  Future<void> _pickImage() async {
    if (_sending) return;
    final XFile? x;
    try {
      x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
    } catch (_) {
      _snack('No se pudo abrir la galería');
      return;
    }
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (bytes.length > MessagingService.maxImageBytes) {
      _snack('La foto es demasiado grande (máx. 5 MB)');
      return;
    }
    var mime = x.mimeType ?? '';
    final name = x.name.toLowerCase();
    if (!mime.startsWith('image/')) {
      mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
    }
    final ext = switch (mime) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/gif' => 'gif',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
    if (ext == 'jpg') mime = 'image/jpeg';
    await _sendAttachment(type: 'image', bytes: bytes, ext: ext, mime: mime);
  }

  Future<void> _startRecording() async {
    if (_sending || _recording) return;
    try {
      if (!await _recorder.hasPermission()) {
        _snack('No pudimos acceder al micrófono.');
        return;
      }
      // AAC/MP4 plays everywhere (incl. iPhone, which can't record or reliably
      // play WebM). Fall back to Opus/WebM only where MP4 recording is missing.
      var encoder = AudioEncoder.aacLc;
      _recExt = 'm4a';
      _recMime = 'audio/mp4';
      if (kIsWeb && !await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
        encoder = AudioEncoder.opus;
        _recExt = 'webm';
        _recMime = 'audio/webm';
      }
      var path = 'chat_audio'; // ignored on web
      if (!kIsWeb) {
        final dir = await getTemporaryDirectory();
        path = '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }
      await _recorder.start(RecordConfig(encoder: encoder), path: path);
      _recWatch
        ..reset()
        ..start();
      _recTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (_recWatch.elapsed >= _maxRecording) {
          _stopRecording(send: true);
        } else {
          setState(() {});
        }
      });
      setState(() => _recording = true);
    } catch (e) {
      if (kDebugMode) debugPrint('chat: start recording failed: $e');
      _snack('No se pudo iniciar la grabación');
    }
  }

  Future<void> _stopRecording({required bool send}) async {
    if (!_recording) return;
    _recTimer?.cancel();
    _recWatch.stop();
    final durationMs = _recWatch.elapsedMilliseconds;
    setState(() => _recording = false);
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}
    if (!send || path == null) return;
    if (durationMs < 700) {
      _snack('Mantené grabando un poco más');
      return;
    }
    final bytes = await XFile(path).readAsBytes();
    if (bytes.length > MessagingService.maxAudioBytes) {
      _snack('El audio es demasiado largo');
      return;
    }
    await _sendAttachment(
      type: 'audio',
      bytes: bytes,
      ext: _recExt,
      mime: _recMime,
      durationMs: durationMs,
    );
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
                error: (e, st) {
                  if (kDebugMode) {
                    debugPrint('chat: load conversation failed: $e\n$st');
                  }
                  return Center(
                    child: Text(
                      kDebugMode
                          ? 'No se pudo cargar la conversación\n$e'
                          : 'No se pudo cargar la conversación',
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: RedesignColors.primario300),
                    ),
                  );
                },
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
            _recording
                ? _RecordingBar(
                    elapsed: _recWatch.elapsed,
                    onCancel: () => _stopRecording(send: false),
                    onSend: () => _stopRecording(send: true),
                  )
                : _Composer(
                    controller: _inputCtrl,
                    sending: _sending,
                    onSend: _send,
                    onPickImage: _pickImage,
                    onRecord: _startRecording,
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
        padding: message.isImage
            ? const EdgeInsets.fromLTRB(4, 4, 10, 6)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            if (message.isImage) ChatImage(path: message.attachmentPath!),
            if (message.isAudio)
              ChatAudio(
                path: message.attachmentPath!,
                durationMs: message.attachmentDurationMs,
                color: fg,
              ),
            if (message.body.trim().isNotEmpty) ...[
              if (message.isImage || message.isAudio)
                const SizedBox(height: 6),
              Text(
                message.body,
                style: RedesignType.bodySm.copyWith(color: fg),
              ),
            ],
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
  final VoidCallback onPickImage;
  final VoidCallback onRecord;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onPickImage,
    required this.onRecord,
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
            SizedBox(
              height: 48,
              child: IconButton(
                tooltip: 'Enviar foto',
                onPressed: sending ? null : onPickImage,
                icon: const Icon(Icons.photo_outlined,
                    color: RedesignColors.primario300),
              ),
            ),
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
            // Empty field → mic (voice note); typed text → send.
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return _RoundButton(
                  onTap: sending ? null : (hasText ? onSend : onRecord),
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.onActionPrimary,
                          ),
                        )
                      : Icon(
                          hasText ? Icons.send_rounded : Icons.mic_rounded,
                          color: RedesignColors.onActionPrimary,
                          size: hasText ? 20 : 22,
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _RoundButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: RedesignColors.actionPrimary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(child: child),
        ),
      ),
    );
  }
}

/// Shown instead of the composer while a voice note is recording.
class _RecordingBar extends StatelessWidget {
  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  const _RecordingBar({
    required this.elapsed,
    required this.onCancel,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Descartar',
              onPressed: onCancel,
              icon: const Icon(Icons.delete_outline_rounded,
                  color: RedesignColors.peligro300),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.fiber_manual_record,
                color: RedesignColors.danger, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Grabando  ${fmtClock(elapsed)}',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
              ),
            ),
            _RoundButton(
              onTap: onSend,
              child: const Icon(Icons.send_rounded,
                  color: RedesignColors.onActionPrimary, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
