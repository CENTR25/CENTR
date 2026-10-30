import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../../services/supabase_service.dart';
import '../../shared/redesign_toast.dart';
import 'admin_redesign_sheet.dart';

/// "Notificar" modal for admins — broadcasts a notification to every trainer.
/// notifications.user_id references profiles(id); a trainer's profile id is
/// trainers.user_id.
class AdminBroadcastSheet extends ConsumerStatefulWidget {
  const AdminBroadcastSheet({super.key});

  @override
  ConsumerState<AdminBroadcastSheet> createState() =>
      _AdminBroadcastSheetState();
}

class _AdminBroadcastSheetState extends ConsumerState<AdminBroadcastSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final admin = ref.read(adminServiceProvider);
      final supabase = ref.read(supabaseServiceProvider);
      final trainers = await admin.getAllTrainers();
      for (final t in trainers) {
        final profileId = t['user_id'] as String?;
        if (profileId == null) continue;
        await supabase.createNotification(
          userId: profileId,
          type: 'broadcast',
          title: _titleCtrl.text.trim(),
          message: _messageCtrl.text.trim(),
        );
      }
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: '¡Notificación enviada!',
        subtitle: 'Se envió a todos los entrenadores.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo enviar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRedesignSheet(
      children: [
        Text(
          'Notificar',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Se enviará a todos los entrenadores.',
          style:
              RedesignType.bodySm.copyWith(color: RedesignColors.primario300),
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleCtrl,
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: const InputDecoration(hintText: 'Título'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresá un título'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 4,
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: const InputDecoration(
                  hintText: 'Mensaje',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresá un mensaje'
                    : null,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _send,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.onActionPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_loading ? 'Enviando...' : 'Enviar a todos'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
