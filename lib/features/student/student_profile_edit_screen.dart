import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/auth_service.dart';
import '../../services/storage_service.dart';
import '../../services/student_service.dart';
import 'profile_constants.dart';

/// Student "Editar perfil" — edits the athlete's own profile fields (and photo).
class StudentProfileEditScreen extends ConsumerStatefulWidget {
  const StudentProfileEditScreen({super.key});

  @override
  ConsumerState<StudentProfileEditScreen> createState() =>
      _StudentProfileEditScreenState();
}

class _StudentProfileEditScreenState
    extends ConsumerState<StudentProfileEditScreen> {
  final _name = TextEditingController();
  final _weight = TextEditingController();
  final _height = TextEditingController();
  final _age = TextEditingController();
  final _injuries = TextEditingController();
  final _phone = TextEditingController();

  String? _objetivo;
  String? _nivel;
  String? _avatarUrl;
  Uint8List? _pickedBytes;
  String _pickedExt = 'jpg';

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ref.read(myAthleteProfileProvider.future);
    if (!mounted) return;
    _name.text = (p?['name'] as String?) ?? '';
    _weight.text = fmtNum(p?['weight']);
    _height.text = fmtNum(p?['height_cm']);
    _age.text = p?['age'] != null ? '${p!['age']}' : '';
    _injuries.text = (p?['injuries'] as String?) ?? '';
    _phone.text = (p?['phone'] as String?) ?? '';
    final goal = (p?['goal'] as String?)?.trim();
    _objetivo = (goal != null && kObjetivoOptions.contains(goal)) ? goal : null;
    final lvl = (p?['training_level'] as String?)?.trim();
    _nivel = (lvl != null && kNivelOptions.contains(lvl)) ? lvl : null;
    _avatarUrl = p?['avatar_url'] as String?;
    setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    _weight.dispose();
    _height.dispose();
    _age.dispose();
    _injuries.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        imageQuality: 80,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final ext = x.name.contains('.') ? x.name.split('.').last : 'jpg';
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _pickedExt = ext.toLowerCase();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo seleccionar la imagen')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? newAvatarUrl;
      if (_pickedBytes != null) {
        final storage = ref.read(storageServiceProvider);
        final userId = ref.read(studentServiceProvider).currentUserId;
        if (userId != null) {
          newAvatarUrl = await storage.uploadAvatarBytes(
              _pickedBytes!, _pickedExt, userId);
        }
      }

      await ref.read(studentServiceProvider).updateMyProfile(
            name: _name.text.trim().isEmpty ? null : _name.text.trim(),
            heightCm: double.tryParse(_height.text.trim().replaceAll(',', '.')),
            age: int.tryParse(_age.text.trim()),
            goal: _objetivo,
            trainingLevel: _nivel,
            injuries: _injuries.text.trim(),
            phone: _phone.text.trim(),
            avatarUrl: newAvatarUrl,
            weight: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
          );

      if (!mounted) return;
      ref.invalidate(myAthleteProfileProvider);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron guardar los cambios')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final name = _name.text.trim().isNotEmpty
        ? _name.text.trim()
        : (user?.displayName ?? 'A');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close_rounded, color: Colors.white),
          ),
          titleSpacing: 0,
          title: const Text(
            'Editar perfil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Metropolis',
            ),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                      RedesignColors.actionPrimary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                children: [
                  // Avatar with camera badge
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: RedesignColors.secundario500,
                                  width: 2.5),
                            ),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: RedesignColors.primario800,
                              backgroundImage: _pickedBytes != null
                                  ? MemoryImage(_pickedBytes!)
                                  : (_avatarUrl != null &&
                                          _avatarUrl!.isNotEmpty)
                                      ? NetworkImage(_avatarUrl!)
                                      : null,
                              child: (_pickedBytes == null &&
                                      (_avatarUrl == null ||
                                          _avatarUrl!.isEmpty))
                                  ? Text(
                                      initial,
                                      style: const TextStyle(
                                        fontFamily: 'Metropolis',
                                        color: RedesignColors.primario50,
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: RedesignColors.actionPrimary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: RedesignColors.background, width: 2),
                              ),
                              child: const Icon(
                                Icons.photo_camera_rounded,
                                color: RedesignColors.onActionPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const _FieldLabel('Nombre y apellido'),
                  _TextField(controller: _name, hint: 'Nombre y apellido'),
                  const SizedBox(height: 20),

                  // Peso / Altura / Edad
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Peso (kg)'),
                            _TextField(
                              controller: _weight,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Altura (cm)'),
                            _TextField(
                              controller: _height,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Edad'),
                            _TextField(
                              controller: _age,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  const _FieldLabel('Objetivo'),
                  _ChipGroup(
                    options: kObjetivoOptions,
                    selected: _objetivo,
                    onSelect: (v) => setState(() => _objetivo = v),
                  ),
                  const SizedBox(height: 20),

                  const _FieldLabel('Nivel'),
                  _ChipGroup(
                    options: kNivelOptions,
                    selected: _nivel,
                    onSelect: (v) => setState(() => _nivel = v),
                  ),
                  const SizedBox(height: 20),

                  const _FieldLabel('Lesiones o condiciones de salud'),
                  _TextField(
                    controller: _injuries,
                    maxLines: 3,
                    hint: 'Ej. Molestia en rodilla izquierda…',
                  ),
                  const SizedBox(height: 20),

                  const _FieldLabel('Teléfono'),
                  _TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    hint: '11 5555-1234',
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RedesignColors.actionPrimary,
                      foregroundColor: RedesignColors.onActionPrimary,
                      minimumSize: const Size(double.infinity, 54),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  RedesignColors.onActionPrimary),
                            ),
                          )
                        : const Text(
                            'Guardar cambios',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Metropolis',
                            ),
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: 'Metropolis',
          color: RedesignColors.primario200,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  const _TextField({
    required this.controller,
    this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontFamily: 'Metropolis',
        color: RedesignColors.primario50,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontFamily: 'Metropolis',
          color: RedesignColors.primario500,
          fontSize: 15,
        ),
        filled: true,
        fillColor: RedesignColors.primario700,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
              color: RedesignColors.secundario500, width: 1.5),
        ),
      ),
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _ChipGroup({
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onSelect(o),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected == o
                    ? RedesignColors.actionPrimary
                    : RedesignColors.primario700,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected == o
                      ? RedesignColors.actionPrimary
                      : RedesignColors.primario600,
                  width: 1.5,
                ),
              ),
              child: Text(
                o,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: selected == o
                      ? RedesignColors.onActionPrimary
                      : RedesignColors.primario200,
                  fontSize: 14,
                  fontWeight:
                      selected == o ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
