import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/theme_redesign.dart';
import '../../core/utils/string_utils.dart';
import '../../services/food_service.dart';
import 'food_edit_sheet.dart';
import 'food_import_sheet.dart';

// ---------------------------------------------------------------------------
// BancoAlimentosScreen
//
// Two tabs: "Ingredientes" (foods, per serving) and "Comidas" (default_meals).
// Selecting an item pops with a meal-shaped map (meal_title, meal_description,
// calories:int, macros, image_url, time_of_day) so the caller (Nueva comida
// sheet) can prefill its form. Admin edits globals; trainers edit their own
// (copy-on-edit for globals).
// ---------------------------------------------------------------------------

class BancoAlimentosScreen extends ConsumerStatefulWidget {
  const BancoAlimentosScreen({super.key});

  @override
  ConsumerState<BancoAlimentosScreen> createState() =>
      _BancoAlimentosScreenState();
}

class _BancoAlimentosScreenState extends ConsumerState<BancoAlimentosScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  String _search = '';
  String? _category;

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(foodsProvider);
    ref.invalidate(mealsBankProvider);
  }

  List<Map<String, dynamic>> _filterFoods(List<Map<String, dynamic>> foods) {
    final q = foldSearch(_search.trim());
    return foods.where((f) {
      if (_category != null && f['category'] != _category) return false;
      if (q.isEmpty) return true;
      return foldSearch('${f['name'] ?? ''} ${f['state'] ?? ''}').contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> _filterMeals(List<Map<String, dynamic>> meals) {
    final q = foldSearch(_search.trim());
    if (q.isEmpty) return meals;
    return meals.where((m) {
      return foldSearch(
              '${m['meal_title'] ?? ''} ${m['meal_description'] ?? ''}')
          .contains(q);
    }).toList();
  }

  Future<void> _pickFood(Map<String, dynamic> f) async {
    final size = _num(f['serving_size']) <= 0 ? 100.0 : _num(f['serving_size']);
    final unit = f['serving_unit']?.toString() ?? 'g';
    final grams = await showDialog<double>(
      context: context,
      builder: (_) => _PortionDialog(defaultAmount: size, unit: unit),
    );
    if (grams == null || !mounted) return;
    final k = grams / size;
    final state = (f['state'] ?? '').toString().trim();
    final amount =
        grams == grams.roundToDouble() ? grams.toInt() : grams;
    Navigator.pop(context, {
      'meal_title': state.isEmpty ? '${f['name']}' : '${f['name']} ($state)',
      'meal_description': '$amount $unit',
      'calories': (_num(f['calories']) * k).round(),
      'macros': {
        'p': _round1(_num(f['protein']) * k),
        'c': _round1(_num(f['carbs']) * k),
        'f': _round1(_num(f['fat']) * k),
      },
      'image_url': null,
      'time_of_day': null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(foodAccessProvider).valueOrNull;
    final service = ref.watch(foodServiceProvider);
    final foodsTab = _tabs.index == 0;

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
            onPressed: () => Navigator.pop(context),
          ),
          centerTitle: true,
          title: const Text(
            'Banco de alimentos',
            style: TextStyle(
              color: RedesignColors.primario50,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Metropolis',
            ),
          ),
          actions: [
            if (access != null && access.canWrite && foodsTab)
              IconButton(
                tooltip: 'Importar CSV',
                icon: const Icon(Icons.upload_file_rounded,
                    color: RedesignColors.primario50),
                onPressed: () async {
                  final existing = (ref.read(foodsProvider).valueOrNull ?? [])
                      .where((f) => access.isAdmin
                          ? f['created_by_trainer'] == null
                          : f['created_by_trainer'] == access.trainerId)
                      .map((f) => foodKey(
                          f['name']?.toString(), f['state']?.toString()))
                      .toSet();
                  final done = await FoodImportSheet.show(context,
                      access: access, service: service, existingKeys: existing);
                  if (done) _refresh();
                },
              ),
          ],
          bottom: TabBar(
            controller: _tabs,
            indicatorColor: RedesignColors.actionPrimary,
            labelColor: RedesignColors.primario50,
            unselectedLabelColor: RedesignColors.primario400,
            tabs: const [Tab(text: 'Ingredientes'), Tab(text: 'Comidas')],
          ),
        ),
        floatingActionButton: (access != null && access.canWrite)
            ? FloatingActionButton(
                backgroundColor: RedesignColors.actionPrimary,
                foregroundColor: RedesignColors.onActionPrimary,
                onPressed: () async {
                  final changed = foodsTab
                      ? await FoodEditSheet.show(context,
                          access: access, service: service)
                      : await MealEditSheet.show(context,
                          access: access, service: service);
                  if (changed) _refresh();
                },
                child: const Icon(Icons.add_rounded),
              )
            : null,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                style: RedesignType.bodySm
                    .copyWith(color: RedesignColors.primario50),
                decoration: InputDecoration(
                  hintText: 'Buscar alimento',
                  hintStyle: const TextStyle(color: RedesignColors.primario400),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: RedesignColors.primario400),
                  filled: true,
                  fillColor: RedesignColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(RedesignRadius.input),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
              ),
            ),
            if (foodsTab) _categoryChips(),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _foodsList(access),
                  _mealsList(access),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final c in [null, ...kFoodCategories])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(c ?? 'Todas'),
                selected: _category == c,
                showCheckmark: false,
                selectedColor: RedesignColors.secundario300,
                backgroundColor: RedesignColors.primario700,
                side: BorderSide.none,
                labelStyle: TextStyle(
                  color: _category == c
                      ? RedesignColors.onActionPrimary
                      : RedesignColors.primario300,
                  fontSize: 12,
                ),
                onSelected: (_) => setState(() => _category = c),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty(String text) => Center(
        child: Text(text,
            style: RedesignType.bodySm
                .copyWith(color: RedesignColors.primario300)),
      );

  Widget _foodsList(FoodAccess? access) {
    return ref.watch(foodsProvider).when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: RedesignColors.actionPrimary)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: RedesignColors.danger))),
          data: (foods) {
            final filtered = _filterFoods(foods);
            if (foods.isEmpty) return _empty('Todavía no hay ingredientes.');
            if (filtered.isEmpty) return _empty('Sin resultados.');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final f = filtered[i];
                return _FoodRow(
                  food: f,
                  onAdd: () => _pickFood(f),
                  onEdit: (access != null && access.canWrite)
                      ? () async {
                          final changed = await FoodEditSheet.show(context,
                              food: f,
                              access: access,
                              service: ref.read(foodServiceProvider));
                          if (changed) _refresh();
                        }
                      : null,
                );
              },
            );
          },
        );
  }

  Widget _mealsList(FoodAccess? access) {
    return ref.watch(mealsBankProvider).when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: RedesignColors.actionPrimary)),
          error: (e, _) => Center(
              child: Text('Error: $e',
                  style: const TextStyle(color: RedesignColors.danger))),
          data: (meals) {
            final filtered = _filterMeals(meals);
            if (meals.isEmpty) return _empty('El banco de comidas está vacío.');
            if (filtered.isEmpty) return _empty('Sin resultados.');
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final m = filtered[i];
                return _MealRow(
                  meal: m,
                  onAdd: () => Navigator.pop(context, {
                    ...m,
                    'calories': _num(m['calories']).round(),
                  }),
                  onEdit: (access != null && access.canWrite)
                      ? () async {
                          final changed = await MealEditSheet.show(context,
                              meal: m,
                              access: access,
                              service: ref.read(foodServiceProvider));
                          if (changed) _refresh();
                        }
                      : null,
                );
              },
            );
          },
        );
  }
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0;
}

double _round1(double v) => (v * 10).round() / 10;

String _fmt(dynamic v) {
  final d = _num(v);
  return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}

// ---------------------------------------------------------------------------
// Portion dialog
// ---------------------------------------------------------------------------

class _PortionDialog extends StatefulWidget {
  final double defaultAmount;
  final String unit;
  const _PortionDialog({required this.defaultAmount, required this.unit});

  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  late final _ctrl = TextEditingController(
      text: widget.defaultAmount == widget.defaultAmount.roundToDouble()
          ? widget.defaultAmount.toInt().toString()
          : widget.defaultAmount.toString());

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: RedesignColors.primario900,
      title: Text('Cantidad (${widget.unit})',
          style: const TextStyle(color: RedesignColors.primario50)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        style: const TextStyle(color: RedesignColors.primario50),
        decoration: foodFieldDecoration('Cantidad'),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: RedesignColors.primario300),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          style: TextButton.styleFrom(
              foregroundColor: RedesignColors.secundario300),
          onPressed: () {
            final v = parseDecimal(_ctrl.text);
            if (v == null || v <= 0 || v > 10000) return;
            Navigator.pop(context, v);
          },
          child: const Text('Agregar'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Rows
// ---------------------------------------------------------------------------

BoxDecoration _cardDeco() => BoxDecoration(
      color: RedesignColors.primario700,
      borderRadius: BorderRadius.circular(RedesignRadius.card),
      border: Border.all(
        color: RedesignColors.secundario300.withValues(alpha: 0.18),
      ),
    );

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: RedesignColors.secundario300.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: RedesignColors.secundario300.withValues(alpha: 0.4)),
        ),
        child: const Icon(Icons.add_rounded,
            color: RedesignColors.secundario300, size: 20),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;
  const _Macro(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: RedesignType.bodySm.copyWith(
                  color: RedesignColors.primario50,
                  fontWeight: FontWeight.w600)),
          Text(label,
              style: RedesignType.label
                  .copyWith(color: RedesignColors.primario400)),
        ]),
      );
}

class _FoodRow extends StatefulWidget {
  final Map<String, dynamic> food;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;
  const _FoodRow({required this.food, required this.onAdd, this.onEdit});

  @override
  State<_FoodRow> createState() => _FoodRowState();
}

class _FoodRowState extends State<_FoodRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final state = (f['state'] ?? '').toString();
    final size = _fmt(f['serving_size'] ?? 100);
    final unit = f['serving_unit']?.toString() ?? 'g';
    final isGlobal = f['created_by_trainer'] == null;
    final verified = f['verified'] == true;
    final source = f['source']?.toString();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDeco(),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isEmpty ? '${f['name']}' : '${f['name']} · $state',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RedesignType.bodySm.copyWith(
                            color: RedesignColors.primario50,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text('${_fmt(f['calories'])} kcal / $size $unit',
                          style: RedesignType.label
                              .copyWith(color: RedesignColors.primario300)),
                    ],
                  ),
                ),
                Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: RedesignColors.primario400),
                const SizedBox(width: 6),
                _AddButton(onTap: widget.onAdd),
              ],
            ),
          ),
          if (_open) ...[
            const SizedBox(height: 10),
            Row(children: [
              _Macro('Prot.', '${_fmt(f['protein'])} g'),
              _Macro('Carbos', '${_fmt(f['carbs'])} g'),
              _Macro('Grasas', '${_fmt(f['fat'])} g'),
              _Macro('Fibra', '${_fmt(f['fiber'])} g'),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  _Badge(f['category']?.toString() ?? 'Otros'),
                  _Badge(isGlobal ? 'Global' : 'Propio'),
                  if (source != null && source.isNotEmpty) _Badge(source),
                  _Badge(verified ? 'Verificado' : 'Sin verificar',
                      color: verified
                          ? RedesignColors.exito500
                          : RedesignColors.advertencia400),
                ]),
              ),
              if (widget.onEdit != null)
                IconButton(
                  tooltip: 'Editar',
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_rounded,
                      size: 18, color: RedesignColors.secundario300),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge(this.text, {this.color = RedesignColors.primario300});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(color: color, fontSize: 11)),
      );
}

class _MealRow extends StatefulWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;
  const _MealRow({required this.meal, required this.onAdd, this.onEdit});

  @override
  State<_MealRow> createState() => _MealRowState();
}

class _MealRowState extends State<_MealRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    final title = meal['meal_title']?.toString() ?? 'Comida';
    final kcal = meal['calories'] == null ? null : _num(meal['calories']).round();
    final imageUrl = meal['image_url']?.toString();
    final desc = meal['meal_description']?.toString() ?? '';
    final macros = (meal['macros'] as Map?) ?? const {};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _cardDeco(),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const _Thumb(),
                          errorWidget: (_, __, ___) => const _Thumb(),
                        )
                      : const _Thumb(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RedesignType.bodySm.copyWith(
                              color: RedesignColors.primario50,
                              fontWeight: FontWeight.w600)),
                      if (kcal != null) ...[
                        const SizedBox(height: 2),
                        Text('$kcal kcal',
                            style: RedesignType.label
                                .copyWith(color: RedesignColors.primario300)),
                      ],
                    ],
                  ),
                ),
                Icon(
                    _open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: RedesignColors.primario400),
                const SizedBox(width: 6),
                _AddButton(onTap: widget.onAdd),
              ],
            ),
          ),
          if (_open) ...[
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(desc,
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario200)),
              ),
            ],
            const SizedBox(height: 10),
            Row(children: [
              _Macro('Prot.', '${_fmt(macros['p'])} g'),
              _Macro('Carbos', '${_fmt(macros['c'])} g'),
              _Macro('Grasas', '${_fmt(macros['f'])} g'),
              if (widget.onEdit != null)
                IconButton(
                  tooltip: 'Editar',
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_rounded,
                      size: 18, color: RedesignColors.secundario300),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: RedesignColors.primario800,
      child: const Icon(Icons.restaurant_rounded,
          size: 22, color: RedesignColors.primario400),
    );
  }
}
