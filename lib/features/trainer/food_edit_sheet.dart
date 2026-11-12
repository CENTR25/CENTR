import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/food_service.dart';

InputDecoration foodFieldDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: RedesignColors.primario400),
      filled: true,
      fillColor: RedesignColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: RedesignColors.inputBorderFocused),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

Widget _sheetFrame(BuildContext context, String title, List<Widget> children) {
  return Theme(
    data: RedesignTheme.theme,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: RedesignColors.primario900,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: RedesignType.headingMd
                        .copyWith(color: RedesignColors.primario50)),
                const SizedBox(height: 16),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _saveRow({
  required bool saving,
  required VoidCallback onSave,
  required VoidCallback onCancel,
  VoidCallback? onDelete,
}) {
  return Row(
    children: [
      if (onDelete != null) ...[
        IconButton(
          onPressed: saving ? null : onDelete,
          icon: const Icon(Icons.delete_outline_rounded,
              color: RedesignColors.peligro400),
        ),
      ],
      const Spacer(),
      TextButton(
        onPressed: saving ? null : onCancel,
        style: TextButton.styleFrom(
            foregroundColor: RedesignColors.primario300,
            minimumSize: const Size(0, 44)),
        child: const Text('Cancelar'),
      ),
      const SizedBox(width: 8),
      ElevatedButton(
        onPressed: saving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: RedesignColors.actionPrimary,
          foregroundColor: RedesignColors.onActionPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        child: saving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Guardar'),
      ),
    ],
  );
}

final _numFormatter =
    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

double _parse(String s) => parseDecimal(s) ?? 0;

// ---------------------------------------------------------------------------
// FoodEditSheet — create / edit an ingredient
// ---------------------------------------------------------------------------

class FoodEditSheet extends StatefulWidget {
  final Map<String, dynamic>? food;
  final FoodAccess access;
  final FoodService service;

  const FoodEditSheet(
      {super.key, this.food, required this.access, required this.service});

  /// Returns true when something changed.
  static Future<bool> show(BuildContext context,
      {Map<String, dynamic>? food,
      required FoodAccess access,
      required FoodService service}) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FoodEditSheet(food: food, access: access, service: service),
    );
    return r == true;
  }

  @override
  State<FoodEditSheet> createState() => _FoodEditSheetState();
}

class _FoodEditSheetState extends State<FoodEditSheet> {
  late final _name = TextEditingController(text: _s('name'));
  late final _state = TextEditingController(text: _s('state'));
  late final _kcal = TextEditingController(text: _n('calories'));
  late final _p = TextEditingController(text: _n('protein'));
  late final _c = TextEditingController(text: _n('carbs'));
  late final _f = TextEditingController(text: _n('fat'));
  late final _fiber = TextEditingController(text: _n('fiber'));
  late final _serving =
      TextEditingController(text: _n('serving_size', fallback: '100'));
  late String _category =
      kFoodCategories.contains(widget.food?['category'])
          ? widget.food!['category'] as String
          : 'Otros';
  late bool _verified = widget.food?['verified'] == true;
  bool _saving = false;
  String? _error;

  String _s(String k) => widget.food?[k]?.toString() ?? '';
  String _n(String k, {String fallback = ''}) {
    final v = widget.food?[k];
    if (v == null) return fallback;
    final d = (v is num) ? v.toDouble() : double.tryParse(v.toString());
    if (d == null) return fallback;
    return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
  }

  @override
  void dispose() {
    for (final c in [_name, _state, _kcal, _p, _c, _f, _fiber, _serving]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isEdit => widget.food != null;
  bool get _copyOnEdit => _isEdit && !widget.access.canEdit(widget.food!);

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Ingresá un nombre.');
      return;
    }
    final vals = [_kcal, _p, _c, _f, _fiber].map((c) => _parse(c.text));
    if (vals.any((v) => v < 0 || v > 2000)) {
      setState(() => _error = 'Revisá los valores numéricos.');
      return;
    }
    final serving = _parse(_serving.text);
    if (serving <= 0) {
      setState(() => _error = 'La porción debe ser mayor a 0.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = {
      'name': name,
      'category': _category,
      'state': _state.text.trim(),
      'calories': _parse(_kcal.text),
      'protein': _parse(_p.text),
      'carbs': _parse(_c.text),
      'fat': _parse(_f.text),
      'fiber': _parse(_fiber.text),
      'serving_size': serving,
      'serving_unit': widget.food?['serving_unit'] ?? 'g',
      'source': widget.food?['source'] ?? 'custom',
      'verified': widget.access.isAdmin ? _verified : false,
    };
    try {
      if (_isEdit) {
        await widget.service.saveFood(widget.food!, data, widget.access);
      } else {
        await widget.service.createFood(data, widget.access);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final dup = e.toString().contains('23505');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = dup
              ? 'Ya existe un alimento con ese nombre y estado.'
              : 'No se pudo guardar. Intentá de nuevo.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: RedesignColors.primario900,
        title: const Text('Eliminar alimento',
            style: TextStyle(color: RedesignColors.primario50)),
        content: const Text('Esta acción no se puede deshacer.',
            style: TextStyle(color: RedesignColors.primario300)),
        actions: [
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: RedesignColors.primario300),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: RedesignColors.peligro400),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      await widget.service.deleteFood(widget.food!['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo eliminar.';
        });
      }
    }
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_numFormatter],
        style: const TextStyle(color: RedesignColors.primario50),
        decoration: foodFieldDecoration(label),
      );

  @override
  Widget build(BuildContext context) {
    final unit = widget.food?['serving_unit']?.toString() ?? 'g';
    return _sheetFrame(
      context,
      _isEdit ? 'Editar alimento' : 'Nuevo alimento',
      [
        if (_copyOnEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Es un alimento global: al guardar se crea tu propia copia.',
              style: RedesignType.label
                  .copyWith(color: RedesignColors.secundario300),
            ),
          ),
        TextField(
          controller: _name,
          maxLength: 200,
          style: const TextStyle(color: RedesignColors.primario50),
          decoration: foodFieldDecoration('Nombre').copyWith(counterText: ''),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _state,
          maxLength: 100,
          style: const TextStyle(color: RedesignColors.primario50),
          decoration: foodFieldDecoration('Estado (cruda, cocida...)')
              .copyWith(counterText: ''),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _category,
          dropdownColor: RedesignColors.primario800,
          style: const TextStyle(color: RedesignColors.primario50),
          decoration: foodFieldDecoration('Categoría'),
          items: [
            for (final c in kFoodCategories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _category = v ?? 'Otros'),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _num(_serving, 'Porción ($unit)')),
          const SizedBox(width: 10),
          Expanded(child: _num(_kcal, 'Calorías')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _num(_p, 'Proteína')),
          const SizedBox(width: 10),
          Expanded(child: _num(_c, 'Carbos')),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _num(_f, 'Grasas')),
          const SizedBox(width: 10),
          Expanded(child: _num(_fiber, 'Fibra')),
        ]),
        if (widget.access.isAdmin)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: RedesignColors.actionPrimary,
            title: const Text('Verificado',
                style: TextStyle(color: RedesignColors.primario50)),
            value: _verified,
            onChanged: (v) => setState(() => _verified = v),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: const TextStyle(color: RedesignColors.peligro400)),
          ),
        const SizedBox(height: 12),
        _saveRow(
          saving: _saving,
          onSave: _save,
          onCancel: () => Navigator.pop(context, false),
          onDelete: _isEdit && !_copyOnEdit ? _delete : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// MealEditSheet — create / edit a prepared meal (default_meals)
// ---------------------------------------------------------------------------

class MealEditSheet extends StatefulWidget {
  final Map<String, dynamic>? meal;
  final FoodAccess access;
  final FoodService service;

  const MealEditSheet(
      {super.key, this.meal, required this.access, required this.service});

  static Future<bool> show(BuildContext context,
      {Map<String, dynamic>? meal,
      required FoodAccess access,
      required FoodService service}) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          MealEditSheet(meal: meal, access: access, service: service),
    );
    return r == true;
  }

  @override
  State<MealEditSheet> createState() => _MealEditSheetState();
}

class _MealEditSheetState extends State<MealEditSheet> {
  Map get _macros => (widget.meal?['macros'] as Map?) ?? const {};
  String _m(String k) {
    final v = _macros[k];
    if (v is num) {
      return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    }
    return v?.toString() ?? '';
  }

  late final _title =
      TextEditingController(text: widget.meal?['meal_title']?.toString() ?? '');
  late final _desc = TextEditingController(
      text: widget.meal?['meal_description']?.toString() ?? '');
  late final _kcal =
      TextEditingController(text: widget.meal?['calories']?.toString() ?? '');
  late final _p = TextEditingController(text: _m('p'));
  late final _c = TextEditingController(text: _m('c'));
  late final _f = TextEditingController(text: _m('f'));
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.meal != null;
  bool get _copyOnEdit => _isEdit && !widget.access.canEdit(widget.meal!);

  @override
  void dispose() {
    for (final c in [_title, _desc, _kcal, _p, _c, _f]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Ingresá un título.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = {
      'meal_title': _title.text.trim(),
      'meal_description': _desc.text.trim(),
      'calories': _parse(_kcal.text),
      'macros': {
        'p': _parse(_p.text),
        'c': _parse(_c.text),
        'f': _parse(_f.text),
      },
      'image_url': widget.meal?['image_url'],
      'time_of_day': widget.meal?['time_of_day'],
    };
    try {
      if (_isEdit) {
        await widget.service.saveMeal(widget.meal!, data, widget.access);
      } else {
        await widget.service.createMeal(data, widget.access);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo guardar. Intentá de nuevo.';
        });
      }
    }
  }

  Future<void> _delete() async {
    setState(() => _saving = true);
    try {
      await widget.service.deleteMeal(widget.meal!['id'] as String);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'No se pudo eliminar.';
        });
      }
    }
  }

  Widget _num(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [_numFormatter],
        style: const TextStyle(color: RedesignColors.primario50),
        decoration: foodFieldDecoration(label),
      );

  @override
  Widget build(BuildContext context) {
    return _sheetFrame(
      context,
      _isEdit ? 'Editar comida' : 'Nueva comida',
      [
        if (_copyOnEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Es una comida global: al guardar se crea tu propia copia.',
              style: RedesignType.label
                  .copyWith(color: RedesignColors.secundario300),
            ),
          ),
        TextField(
          controller: _title,
          style: const TextStyle(color: RedesignColors.primario50),
          decoration: foodFieldDecoration('Título'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _desc,
          maxLines: 3,
          style: const TextStyle(color: RedesignColors.primario50),
          decoration: foodFieldDecoration('Descripción'),
        ),
        const SizedBox(height: 10),
        _num(_kcal, 'Calorías'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _num(_p, 'Prot.')),
          const SizedBox(width: 10),
          Expanded(child: _num(_c, 'Carbos')),
          const SizedBox(width: 10),
          Expanded(child: _num(_f, 'Grasas')),
        ]),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!,
                style: const TextStyle(color: RedesignColors.peligro400)),
          ),
        const SizedBox(height: 12),
        _saveRow(
          saving: _saving,
          onSave: _save,
          onCancel: () => Navigator.pop(context, false),
          onDelete: _isEdit && !_copyOnEdit ? _delete : null,
        ),
      ],
    );
  }
}
