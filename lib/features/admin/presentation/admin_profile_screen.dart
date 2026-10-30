import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_mode_provider.dart';
import '../../../core/theme/theme_redesign.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/supabase_service.dart';
import '../../trainer/change_password_screen.dart';
import '../../shared/redesign_toast.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_redesign_sheet.dart';

/// Admin profile/settings (Figma Four Batch): identity + Editar perfil /
/// Cambiar contraseña / Apariencia / Acerca de + Cerrar sesión.
class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            '¿Seguro que querés cerrar sesión?',
            textAlign: TextAlign.center,
            style: RedesignType.bodyMd.copyWith(
              color: RedesignColors.secundario300,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancelar',
                style: RedesignType.buttonLg
                    .copyWith(color: RedesignColors.primario50),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: RedesignColors.danger,
                foregroundColor: RedesignColors.primario50,
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    // Capture the notifier before any dispose (lesson: ref-after-dispose).
    final notifier = ref.read(authProvider.notifier);
    await notifier.signOut();
  }

  void _editProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _EditAdminProfileSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final name = user?.name ?? 'Admin';
    final email = user?.email ?? '';
    final photo = user?.avatarUrl;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'A';

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
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: RedesignColors.actionPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 42,
                      backgroundColor: RedesignColors.primario700,
                      backgroundImage: (photo != null && photo.isNotEmpty)
                          ? NetworkImage(photo)
                          : null,
                      child: (photo == null || photo.isEmpty)
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: RedesignColors.primario50,
                                fontWeight: FontWeight.w700,
                                fontSize: 34,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name,
                    style: RedesignType.headingMd.copyWith(
                      color: RedesignColors.primario50,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              radius: RedesignRadius.card,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.edit_outlined,
                    label: 'Editar perfil',
                    onTap: () => _editProfile(context),
                  ),
                  const _MenuDivider(),
                  _MenuRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Cambiar contraseña',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),
                  const _MenuDivider(),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    label: 'Apariencia',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _AppearanceScreen(),
                      ),
                    ),
                  ),
                  const _MenuDivider(),
                  _MenuRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Acerca de',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const _AboutScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: () => _confirmLogout(context, ref),
                child: Text(
                  'Cerrar sesión',
                  style: RedesignType.buttonLg.copyWith(
                    color: RedesignColors.danger,
                    fontWeight: FontWeight.w600,
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: RedesignColors.primario900,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: RedesignColors.primario50, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: RedesignColors.primario400, size: 20),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: RedesignColors.primario600);
}

// ── Editar perfil (name + photo via user_metadata) ───────────────────────
class _EditAdminProfileSheet extends ConsumerStatefulWidget {
  const _EditAdminProfileSheet();

  @override
  ConsumerState<_EditAdminProfileSheet> createState() =>
      _EditAdminProfileSheetState();
}

class _EditAdminProfileSheetState
    extends ConsumerState<_EditAdminProfileSheet> {
  late final TextEditingController _nameCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
    );
    if (picked == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.contains('.')
          ? picked.name.split('.').last
          : 'jpg';
      final userId = ref.read(currentUserProvider)!.id;
      final url = await ref
          .read(storageServiceProvider)
          .uploadAvatarBytes(bytes, ext, userId);
      final client = ref.read(supabaseClientProvider);
      await client.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'Foto actualizada',
        subtitle: 'Tu foto de perfil se actualizó.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo subir la foto',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final client = ref.read(supabaseClientProvider);
      await client.auth
          .updateUser(UserAttributes(data: {'name': _nameCtrl.text.trim()}));
      await ref.read(authProvider.notifier).refreshProfile();
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: 'Perfil actualizado',
        subtitle: 'Los cambios se guardaron.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo guardar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final photo = user?.avatarUrl;
    final initial = (user?.name?.trim().isNotEmpty ?? false)
        ? user!.name!.trim()[0].toUpperCase()
        : 'A';

    return AdminRedesignSheet(
      children: [
        Text(
          'Editar perfil',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: _loading ? null : _pickAndUploadPhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: RedesignColors.primario700,
                  backgroundImage: (photo != null && photo.isNotEmpty)
                      ? NetworkImage(photo)
                      : null,
                  child: (photo == null || photo.isEmpty)
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w700,
                            fontSize: 34,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: RedesignColors.actionPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: RedesignColors.onActionPrimary, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
          decoration: const InputDecoration(
            hintText: 'Nombre',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: RedesignColors.onActionPrimary,
                    ),
                  )
                : const Text('Guardar'),
          ),
        ),
      ],
    );
  }
}

// ── Apariencia ─────────────────────────────────────────────────────────────
class _AppearanceScreen extends ConsumerWidget {
  const _AppearanceScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
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
            'Apariencia',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              radius: RedesignRadius.card,
              child: Column(
                children: [
                  _ThemeOption(
                    label: 'Sistema',
                    selected: mode == ThemeMode.system,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(ThemeMode.system),
                  ),
                  const _MenuDivider(),
                  _ThemeOption(
                    label: 'Claro',
                    selected: mode == ThemeMode.light,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(ThemeMode.light),
                  ),
                  const _MenuDivider(),
                  _ThemeOption(
                    label: 'Oscuro',
                    selected: mode == ThemeMode.dark,
                    onTap: () => ref
                        .read(themeModeProvider.notifier)
                        .set(ThemeMode.dark),
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

class _ThemeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected
                  ? RedesignColors.actionPrimary
                  : RedesignColors.primario500,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Acerca de ──────────────────────────────────────────────────────────────
class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
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
            'Acerca de',
            style: RedesignType.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: RedesignColors.primario50,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(
                'PRGS',
                style: RedesignType.headingMd.copyWith(
                  color: RedesignColors.primario50,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Panel de administración',
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario300),
              ),
              const SizedBox(height: 24),
              AdminCard(
                child: Column(
                  children: [
                    _aboutRow('Versión', '1.0.0'),
                    const _MenuDivider(),
                    _aboutRow('Hecho por', 'PRGS'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _aboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: RedesignType.bodySm.copyWith(
                color: RedesignColors.primario50,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style:
                RedesignType.label.copyWith(color: RedesignColors.primario400),
          ),
        ],
      ),
    );
  }
}
