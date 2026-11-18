import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/messaging_service.dart';

// ---------------------------------------------------------------------------
// Chat attachments: photo thumbnail + full-screen viewer, voice-note player.
// Files are in the private chat-media bucket; URLs come from
// chatMediaUrlProvider (signed). The storage path is the image cache key, so
// a re-signed URL doesn't re-download the same photo.
// ---------------------------------------------------------------------------

String fmtClock(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

class ChatImage extends ConsumerWidget {
  final String path;
  const ChatImage({super.key, required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(chatMediaUrlProvider(path));
    const size = 220.0;
    Widget box(Widget child) => SizedBox(
          width: size,
          height: size,
          child: ColoredBox(color: RedesignColors.primario800, child: child),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url.when(
        loading: () => box(const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: RedesignColors.actionPrimary),
        )),
        error: (_, _) => box(const Icon(Icons.broken_image_outlined,
            color: RedesignColors.primario300)),
        data: (u) => GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _ChatImageViewer(url: u, cacheKey: path),
          )),
          child: CachedNetworkImage(
            imageUrl: u,
            cacheKey: path,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: 600,
            placeholder: (_, _) => box(const SizedBox.shrink()),
            errorWidget: (_, _, _) => box(const Icon(
                Icons.broken_image_outlined,
                color: RedesignColors.primario300)),
          ),
        ),
      ),
    );
  }
}

class _ChatImageViewer extends StatelessWidget {
  final String url;
  final String cacheKey;
  const _ChatImageViewer({required this.url, required this.cacheKey});

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Cap decode at 1.5x the screen (uncapped decodes blew the ImageCache on
    // the check-in viewer and blacked out other thumbnails).
    final cap = (mq.size.longestSide * mq.devicePixelRatio * 1.5).round();
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 4,
          child: CachedNetworkImage(
            imageUrl: url,
            cacheKey: cacheKey,
            fit: BoxFit.contain,
            memCacheWidth: cap,
            placeholder: (_, _) => const CircularProgressIndicator(
                color: RedesignColors.actionPrimary),
          ),
        ),
      ),
    );
  }
}

class ChatAudio extends ConsumerStatefulWidget {
  final String path;
  final int? durationMs;
  final Color color;
  const ChatAudio({
    super.key,
    required this.path,
    required this.durationMs,
    required this.color,
  });

  @override
  ConsumerState<ChatAudio> createState() => _ChatAudioState();
}

class _ChatAudioState extends ConsumerState<ChatAudio> {
  final _player = AudioPlayer();
  final _subs = <StreamSubscription>[];
  bool _playing = false;
  bool _loading = false;
  Duration _pos = Duration.zero;
  Duration? _dur;
  Future<void>? _prepared;

  @override
  void initState() {
    super.initState();
    if (widget.durationMs != null) {
      _dur = Duration(milliseconds: widget.durationMs!);
    }
    _subs.addAll([
      _player.onPositionChanged.listen((p) {
        if (mounted) setState(() => _pos = p);
      }),
      _player.onDurationChanged.listen((d) {
        if (mounted && d > Duration.zero) setState(() => _dur = d);
      }),
      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() {
            _playing = false;
            _pos = Duration.zero;
          });
        }
      }),
    ]);
    // Load the source up front: iOS Safari only allows play() close to the
    // tap, so the tap must not wait on a signed-URL fetch + load first.
    _prepared = _prepare()..ignore(); // errors resurface on tap
  }

  Future<void> _prepare() async {
    final url = await ref.read(chatMediaUrlProvider(widget.path).future);
    await _player.setSource(UrlSource(url));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      try {
        await _prepared;
      } catch (_) {
        _prepared = _prepare(); // e.g. expired/failed fetch: retry once
        await _prepared;
      }
      await _player.resume();
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo reproducir el audio')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _dur ?? Duration.zero;
    final progress = total.inMilliseconds > 0
        ? (_pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final shown = (_playing || _pos > Duration.zero) ? _pos : total;
    return SizedBox(
      width: 210,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: _loading
                ? Padding(
                    padding: const EdgeInsets.all(9),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: widget.color),
                  )
                : IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _toggle,
                    icon: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: widget.color,
                      size: 30,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 3,
                color: widget.color,
                backgroundColor: widget.color.withValues(alpha: 0.25),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            fmtClock(shown),
            style: RedesignType.label.copyWith(color: widget.color),
          ),
        ],
      ),
    );
  }
}
