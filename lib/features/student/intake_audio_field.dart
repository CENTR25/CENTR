import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/theme_redesign.dart';

/// Voice-note recorder for a long-text intake question. Records with `record`,
/// uploads to the public `exercise-media/intake-audio/<uid>/` folder on stop,
/// and reports the resulting public URL via [onChanged] (null when deleted).
class IntakeAudioField extends StatefulWidget {
  const IntakeAudioField({
    super.key,
    required this.userId,
    required this.initialUrl,
    required this.onChanged,
  });

  final String userId;
  final String? initialUrl;
  final ValueChanged<String?> onChanged;

  @override
  State<IntakeAudioField> createState() => _IntakeAudioFieldState();
}

class _IntakeAudioFieldState extends State<IntakeAudioField> {
  final AudioRecorder _rec = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  bool _recording = false;
  bool _uploading = false;
  bool _playing = false;
  int _elapsed = 0;
  Timer? _timer;
  String? _url;

  @override
  void initState() {
    super.initState();
    _url = widget.initialUrl;
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rec.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _rec.hasPermission()) {
      _snack('No pudimos acceder al micrófono.');
      return;
    }
    final encoder = kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc;
    String path = 'intake_audio'; // ignored on web
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/intake_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    await _rec.start(RecordConfig(encoder: encoder), path: path);
    _elapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    setState(() => _recording = true);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    final path = await _rec.stop();
    setState(() => _recording = false);
    if (path == null) return;
    await _upload(path);
  }

  Future<void> _upload(String path) async {
    setState(() => _uploading = true);
    try {
      final bytes = await XFile(path).readAsBytes();
      final ext = kIsWeb ? 'webm' : 'm4a';
      final contentType = kIsWeb ? 'audio/webm' : 'audio/mp4';
      final objectPath =
          'intake-audio/${widget.userId}/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storage = Supabase.instance.client.storage.from('exercise-media');
      await storage.uploadBinary(
        objectPath,
        bytes,
        fileOptions: FileOptions(contentType: contentType, upsert: true),
      );
      final url = storage.getPublicUrl(objectPath);
      if (!mounted) return;
      setState(() {
        _url = url;
        _uploading = false;
      });
      widget.onChanged(url);
    } catch (e) {
      if (mounted) setState(() => _uploading = false);
      _snack('Error al subir el audio: $e');
    }
  }

  Future<void> _togglePlay() async {
    if (_url == null) return;
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
    } else {
      await _player.play(UrlSource(_url!));
      if (mounted) setState(() => _playing = true);
    }
  }

  void _delete() {
    _player.stop();
    setState(() {
      _url = null;
      _playing = false;
    });
    widget.onChanged(null);
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(m)));
    }
  }

  String _fmt(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    if (_uploading) {
      return _pill(
        child: Row(children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: RedesignColors.actionPrimary),
          ),
          SizedBox(width: 12),
          Text('Subiendo audio...',
              style: TextStyle(color: RedesignColors.primario300)),
        ]),
      );
    }

    if (_url != null) {
      return _pill(
        child: Row(children: [
          _circleBtn(
            icon: _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onTap: _togglePlay,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('Nota de voz grabada',
                style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
          IconButton(
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: RedesignColors.peligro300, size: 22),
            tooltip: 'Eliminar',
          ),
        ]),
      );
    }

    if (_recording) {
      return _pill(
        borderColor: RedesignColors.danger,
        child: Row(children: [
          _circleBtn(
            icon: Icons.stop_rounded,
            color: RedesignColors.danger,
            onTap: _stop,
          ),
          const SizedBox(width: 12),
          const Icon(Icons.fiber_manual_record,
              color: RedesignColors.danger, size: 12),
          const SizedBox(width: 6),
          Text('Grabando  ${_fmt(_elapsed)}',
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ]),
      );
    }

    // Idle
    return InkWell(
      onTap: _start,
      borderRadius: BorderRadius.circular(14),
      child: _pill(
        child: Row(children: const [
          Icon(Icons.mic_none_rounded,
              color: RedesignColors.actionPrimary, size: 22),
          SizedBox(width: 12),
          Text('Grabar una nota de voz',
              style: TextStyle(
                  color: RedesignColors.actionPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _pill({required Widget child, Color? borderColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RedesignColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
          width: borderColor != null ? 1.5 : 1,
        ),
      ),
      child: child,
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = RedesignColors.actionPrimary,
  }) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: RedesignColors.onActionPrimary, size: 22),
      ),
    );
  }
}
