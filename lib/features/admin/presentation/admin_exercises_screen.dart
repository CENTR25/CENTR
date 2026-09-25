import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/string_utils.dart';
import '../../../services/admin_service.dart';

/// Admin management of the GLOBAL exercise library.
/// Admins can add, edit, delete global exercises and hide/unhide them.
class AdminExercisesView extends ConsumerStatefulWidget {
  const AdminExercisesView({super.key});

  @override
  ConsumerState<AdminExercisesView> createState() => _AdminExercisesViewState();
}

class _AdminExercisesViewState extends ConsumerState<AdminExercisesView> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercisesAsync = ref.watch(globalExercisesProvider);

    return Scaffold(
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar ejercicio...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // ── List ────────────────────────────────────────────────────────
          Expanded(
            child: exercisesAsync.when(
              data: (exercises) {
                // Accent-insensitive filter reusing the shared foldSearch helper.
                final q = foldSearch(_searchQuery.trim());
                final filtered = q.isEmpty
                    ? exercises
                    : exercises
                        .where((e) =>
                            foldSearch(e['name'] as String? ?? '').contains(q))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center_rounded,
                            size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          q.isEmpty
                              ? 'No hay ejercicios globales'
                              : 'Sin resultados para "$_searchQuery"',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        if (q.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Agrega el primer ejercicio para todos los entrenadores',
                            style: TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final ex = filtered[index];
                    final name = (ex['name'] as String?) ?? 'Ejercicio';
                    final muscle = (ex['muscle_group'] as String?) ?? '';
                    final category = ex['category'] as String?;
                    final isHidden = ex['is_hidden'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.fitness_center_rounded,
                              color: AppColors.primary),
                        ),
                        title: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              [muscle, if (category != null) category]
                                  .where((s) => s.isNotEmpty)
                                  .join(' · '),
                              style:
                                  TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isHidden
                                    ? Colors.grey.withValues(alpha: 0.1)
                                    : AppColors.success.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isHidden ? 'Oculto' : 'Visible',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isHidden
                                      ? Colors.grey
                                      : AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) =>
                              _handleAction(context, value, ex),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(isHidden ? 'Mostrar' : 'Ocultar'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar',
                                  style:
                                      TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AdminExerciseSheet(),
    );
  }

  void _showEditSheet(BuildContext context, Map<String, dynamic> ex) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdminExerciseSheet(exerciseToEdit: ex),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    Map<String, dynamic> ex,
  ) async {
    final id = ex['id'] as String;
    final name = (ex['name'] as String?) ?? 'Ejercicio';
    final isHidden = ex['is_hidden'] == true;

    switch (action) {
      case 'edit':
        _showEditSheet(context, ex);
        break;

      case 'toggle':
        try {
          await ref
              .read(adminServiceProvider)
              .setGlobalExerciseHidden(id, !isHidden);
          ref.invalidate(globalExercisesProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(isHidden
                      ? 'Ejercicio visible'
                      : 'Ejercicio oculto')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: AppColors.error),
            );
          }
        }
        break;

      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Eliminar ejercicio'),
            content: Text(
              '¿Eliminar "$name"? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await ref
                .read(adminServiceProvider)
                .deleteGlobalExercise(id);
            ref.invalidate(globalExercisesProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ejercicio eliminado'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: AppColors.error),
              );
            }
          }
        }
        break;
    }
  }
}

// ── Create / Edit exercise sheet ────────────────────────────────────────────
class _AdminExerciseSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? exerciseToEdit;

  const _AdminExerciseSheet({this.exerciseToEdit});

  @override
  ConsumerState<_AdminExerciseSheet> createState() =>
      _AdminExerciseSheetState();
}

class _AdminExerciseSheetState extends ConsumerState<_AdminExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _equipmentController = TextEditingController();
  bool _isLoading = false;

  bool get _isEditMode => widget.exerciseToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.exerciseToEdit case final ex?) {
      _nameController.text = ex['name'] as String? ?? '';
      _muscleController.text = ex['muscle_group'] as String? ?? '';
      _categoryController.text = ex['category'] as String? ?? '';
      final rawEquip = ex['equipment'];
      if (rawEquip is List) {
        _equipmentController.text = rawEquip.cast<String>().join(', ');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _muscleController.dispose();
    _categoryController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final equipment = _equipmentController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final category = _categoryController.text.trim();

      if (_isEditMode) {
        await ref.read(adminServiceProvider).updateGlobalExercise(
              widget.exerciseToEdit!['id'] as String,
              name: _nameController.text.trim(),
              muscleGroup: _muscleController.text.trim(),
              category: category.isEmpty ? null : category,
              equipment: equipment.isEmpty ? null : equipment,
            );
      } else {
        await ref.read(adminServiceProvider).createGlobalExercise(
              name: _nameController.text.trim(),
              muscleGroup: _muscleController.text.trim(),
              category: category.isEmpty ? null : category,
              equipment: equipment.isEmpty ? null : equipment,
            );
      }

      ref.invalidate(globalExercisesProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                _isEditMode ? 'Ejercicio actualizado' : 'Ejercicio creado'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isEditMode ? 'Editar ejercicio' : 'Agregar ejercicio',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.fitness_center),
                ),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _muscleController,
                decoration: const InputDecoration(
                  labelText: 'Grupo muscular',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.accessibility_new),
                ),
                validator: (v) =>
                    v?.trim().isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Categoría (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _equipmentController,
                decoration: const InputDecoration(
                  labelText: 'Equipamiento (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.sports_gymnastics),
                  helperText: 'Separá con comas: mancuernas, banco',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(_isEditMode
                          ? 'Guardar cambios'
                          : 'Crear ejercicio'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
