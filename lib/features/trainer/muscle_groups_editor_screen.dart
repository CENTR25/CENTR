import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/muscle_group_service.dart';
import '../../services/trainer_service.dart';

/// Editor de grupos musculares (ADR-007). Shared by trainer and admin:
/// admin manages the global groups, a trainer manages their own (globals are
/// shown read-only).
class MuscleGroupsEditorScreen extends ConsumerStatefulWidget {
  final bool isAdmin;
  const MuscleGroupsEditorScreen({super.key, this.isAdmin = false});

  @override
  ConsumerState<MuscleGroupsEditorScreen> createState() =>
      _MuscleGroupsEditorScreenState();
}

class _MuscleGroupsEditorScreenState
    extends ConsumerState<MuscleGroupsEditorScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      ref.invalidate(muscleGroupRowsProvider);
      ref.invalidate(muscleGroupNamesProvider);
      await ref.read(muscleGroupRowsProvider.future);
    } catch (e) {
      final msg = '$e'.contains('23505') || '$e'.contains('duplicate')
          ? 'Ya existe un grupo con ese nombre.'
          : 'Error: $e';
      messenger.showSnackBar(SnackBar(
          content: Text(msg), backgroundColor: RedesignColors.danger));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askName(String title, {String initial = ''}) {
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => Theme(
        data: RedesignTheme.theme,
        child: AlertDialog(
          backgroundColor: RedesignColors.primario800,
          title: Text(title,
              style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario50),
            decoration: const InputDecoration(hintText: 'Nombre del grupo'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                  foregroundColor: RedesignColors.primario300),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: RedesignColors.actionPrimary,
                foregroundColor: RedesignColors.primario900,
                minimumSize: const Size(0, 40),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(muscleGroupRowsProvider);
    final trainerId =
        widget.isAdmin ? null : ref.watch(myTrainerIdProvider).valueOrNull;
    final service = ref.read(muscleGroupServiceProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        appBar: AppBar(
          backgroundColor: RedesignColors.background,
          foregroundColor: RedesignColors.primario50,
          elevation: 0,
          title: Text('Grupos musculares',
              style: RedesignType.bodyMd.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w700)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.primario900,
          onPressed: _busy
              ? null
              : () async {
                  if (!widget.isAdmin && trainerId == null) return;
                  final name = await _askName('Nuevo grupo muscular');
                  if (name == null || name.isEmpty) return;
                  final all = rowsAsync.valueOrNull ?? const <MuscleGroup>[];
                  final order = all.isEmpty
                      ? 1
                      : all
                              .map((g) => g.displayOrder)
                              .reduce((a, b) => a > b ? a : b) +
                          1;
                  await _run(() =>
                      service.add(name, trainerId: trainerId, order: order));
                },
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar grupo'),
        ),
        body: rowsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: RedesignType.bodySm
                      .copyWith(color: RedesignColors.danger))),
          data: (rows) {
            // Admin edits globals only; trainer edits own, sees globals.
            final editable = rows
                .where((g) => widget.isAdmin ? g.isGlobal : g.trainerId == trainerId && trainerId != null)
                .toList();
            final readOnly = widget.isAdmin
                ? <MuscleGroup>[]
                : rows.where((g) => g.isGlobal).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.isAdmin
                        ? 'Grupos globales. Renombrar actualiza todos los ejercicios que lo usan. Desactivar oculta el grupo de los filtros sin tocar ejercicios.'
                        : 'Tus grupos propios. Renombrar actualiza solo tus ejercicios. Los grupos globales los gestiona el administrador.',
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
                  ),
                ),
                if (editable.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Todavía no creaste grupos.',
                        textAlign: TextAlign.center,
                        style: RedesignType.bodySm
                            .copyWith(color: RedesignColors.primario400)),
                  )
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: editable.length,
                    onReorderItem: (from, to) {
                      final list = [...editable];
                      list.insert(to, list.removeAt(from));
                      _run(() => service.reorder(list));
                    },
                    itemBuilder: (_, i) {
                      final g = editable[i];
                      return _GroupTile(
                        key: ValueKey(g.id),
                        group: g,
                        index: i,
                        busy: _busy,
                        onRename: () async {
                          final n = await _askName('Renombrar grupo',
                              initial: g.name);
                          if (n == null || n.isEmpty || n == g.name) return;
                          await _run(() => service.rename(g.id, n));
                        },
                        onToggle: (v) =>
                            _run(() => service.setActive(g.id, v)),
                      );
                    },
                  ),
                if (readOnly.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text('Globales',
                      style: RedesignType.label.copyWith(
                          color: RedesignColors.primario300,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final g in readOnly)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: RedesignColors.primario700,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(g.name,
                              style: RedesignType.buttonSm.copyWith(
                                  color: g.isActive
                                      ? RedesignColors.primario50
                                      : RedesignColors.primario500)),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final MuscleGroup group;
  final int index;
  final bool busy;
  final VoidCallback onRename;
  final ValueChanged<bool> onToggle;

  const _GroupTile({
    super.key,
    required this.group,
    required this.index,
    required this.busy,
    required this.onRename,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: RedesignColors.primario800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.drag_indicator_rounded,
                  color: RedesignColors.primario400, size: 20),
            ),
          ),
          Expanded(
            child: Text(
              group.name,
              style: RedesignType.bodySm.copyWith(
                color: group.isActive
                    ? RedesignColors.primario50
                    : RedesignColors.primario500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onRename,
            icon: const Icon(Icons.edit_rounded,
                color: RedesignColors.primario300, size: 18),
            tooltip: 'Renombrar',
          ),
          Switch(
            value: group.isActive,
            onChanged: busy ? null : onToggle,
            activeThumbColor: RedesignColors.actionPrimary,
          ),
        ],
      ),
    );
  }
}
