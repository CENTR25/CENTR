import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/trainer_service.dart';
import '../../services/storage_service.dart';

class MealPlanDetailScreen extends ConsumerStatefulWidget {
  final String planId;
  final String planName;

  const MealPlanDetailScreen({
    super.key,
    required this.planId,
    required this.planName,
  });

  @override
  ConsumerState<MealPlanDetailScreen> createState() => _MealPlanDetailScreenState();
}

class _MealPlanDetailScreenState extends ConsumerState<MealPlanDetailScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _currentDay = 1;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(mealPlanDetailProvider(widget.planId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.planName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => planAsync.value != null ? _showEditPlan(planAsync.value!) : null,
          ),
        ],
      ),
      body: planAsync.when(
        data: (plan) {
          if (plan == null) return const Center(child: Text('Plan no encontrado'));

          final items = (plan['meal_plan_items'] as List?) ?? [];
          
          // Determine number of days (e.g., max day found or default 7)
          // For simplicity, let's assume a weekly plan (7 days)
          const daysCount = 7;
          
           if (_tabController == null) {
            _tabController = TabController(length: daysCount, vsync: this);
            _tabController!.addListener(() {
              setState(() => _currentDay = _tabController!.index + 1);
            });
          }

          return Column(
            children: [
              // Header Info
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.warning, AppColors.warningDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${plan['target_calories'] ?? '-'} kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 22),
                        ),
                        Text(
                          'OBJETIVO DIARIO',
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        plan['objective'] ?? 'General',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Days Tabs
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.warning,
                unselectedLabelColor: AppColors.textLight,
                indicatorColor: AppColors.warning,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                overlayColor: WidgetStateProperty.all(AppColors.warning.withOpacity(0.05)),
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tabs: List.generate(daysCount, (i) => Tab(text: 'Día ${i + 1}')),
              ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: List.generate(daysCount, (dayIndex) {
                    final dayNum = dayIndex + 1;
                    final dayItems = items.where((i) => i['day_number'] == dayNum).toList();
                    
                    // Sort order: Breakfast, Lunch, Snack, Dinner
                    dayItems.sort((a, b) {
                       final order = {'breakfast': 0, 'lunch': 1, 'snack': 2, 'dinner': 3};
                       final aOrder = order[a['time_of_day']] ?? 99;
                       final bOrder = order[b['time_of_day']] ?? 99;
                       return aOrder.compareTo(bOrder);
                    });

                    if (dayItems.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: Icon(Icons.restaurant_menu_rounded, size: 48, color: Colors.white.withOpacity(0.1)),
                            ),
                            const SizedBox(height: 24),
                            Text('Sin comidas para este día', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddMeal(dayNum),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Agregar comida', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: dayItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = dayItems[index];
                        return _MealItemCard(
                          item: item,
                          onDelete: () => _deleteItem(item['id']),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMeal(_currentDay),
        backgroundColor: AppColors.warning,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add_rounded, size: 32),
      ),
    );
  }

  void _showAddMeal(int day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMealSheet(planId: widget.planId, day: day),
    );
  }

  void _showEditPlan(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditMealPlanSheet(plan: plan),
    );
  }

  Future<void> _deleteItem(String itemId) async {
     try {
      final service = ref.read(trainerServiceProvider);
      await service.removeMealPlanItem(itemId);
      ref.invalidate(mealPlanDetailProvider(widget.planId));
      ref.invalidate(myMealPlansProvider); // Update list summary too
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comida eliminada'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _MealItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;

  const _MealItemCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final time = item['time_of_day'] ?? 'meal';
    final timeLabel = {
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'snack': 'Merienda',
    }[time] ?? 'Comida';
    
    final color = {
      'breakfast': Colors.orange,
      'lunch': Colors.red,
      'dinner': Colors.blue,
      'snack': Colors.green,
    }[time] ?? Colors.grey;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: item['image_url'] != null
            ? Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(item['image_url']),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.restaurant_rounded, color: color, size: 28),
              ),
        title: Text(
          item['meal_title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    timeLabel.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5),
                  ),
                ),
                if (item['calories'] != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${item['calories']} kcal',
                    style: TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ],
            ),
            if (item['meal_description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                item['meal_description'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textLight.withOpacity(0.8), fontSize: 13),
              ),
            ],
          ],
        ),
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded, color: AppColors.error.withOpacity(0.8)),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _AddMealSheet extends ConsumerStatefulWidget {
  final String planId;
  final int day;

  const _AddMealSheet({required this.planId, required this.day});

  @override
  ConsumerState<_AddMealSheet> createState() => _AddMealSheetState();
}

class _AddMealSheetState extends ConsumerState<_AddMealSheet> {
  final _formKey = GlobalKey<FormState>();
  String _time = 'breakfast';
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _calController = TextEditingController();
  File? _imageFile;
  final _picker = ImagePicker();
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _imageFile = File(pickedFile.path));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(trainerServiceProvider);
      final storage = ref.read(storageServiceProvider);
      
      await service.addMealPlanItem(
        mealPlanId: widget.planId,
        dayNumber: widget.day,
        timeOfDay: _time,
        name: _nameController.text.trim(),
        description: _descController.text.isEmpty ? null : _descController.text.trim(),
        calories: int.tryParse(_calController.text.trim()),
        imageFile: _imageFile,
        storageService: storage,
      );
      
      ref.invalidate(mealPlanDetailProvider(widget.planId));
      ref.invalidate(myMealPlansProvider);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showFoodBankSearch() async {
    final selectedItem = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _FoodBankSearchSheet(),
    );

    if (selectedItem != null) {
      setState(() {
        _nameController.text = selectedItem['meal_title'] ?? '';
        _descController.text = selectedItem['meal_description'] ?? '';
        _calController.text = (selectedItem['calories'] as int?)?.toString() ?? '';
        if (selectedItem['time_of_day'] != null) {
          // Verify if it maps to our values
          final t = selectedItem['time_of_day'];
          if (['breakfast', 'lunch', 'dinner', 'snack'].contains(t)) {
             _time = t;
          }
        }
        // If macros exist, maybe append to description for now or just log them
        // The current addMealPlanItem supports 'macros' map, but the UI doesn't have inputs for it.
        // We can secretly store it if we added a member generic map, but for now let's just use text fields.
        if (selectedItem['macros'] != null) {
           final m = selectedItem['macros'];
           if (m is Map) {
             final macroText = "\n\nMacros: P: ${m['p']}g, C: ${m['c']}g, G: ${m['f']}g";
             if (!_descController.text.contains("Macros:")) {
               _descController.text += macroText;
             }
           }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                     'Nueva Comida - Día ${widget.day}', 
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                   ),
                   TextButton.icon(
                     onPressed: _showFoodBankSearch,
                     style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                     icon: const Icon(Icons.search_rounded),
                     label: const Text('BANCO', style: TextStyle(fontWeight: FontWeight.bold)),
                   )
                ],
              ),
              const SizedBox(height: 20),
              
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                    image: _imageFile != null
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.add_a_photo_rounded, size: 32, color: AppColors.warning),
                            ),
                            const SizedBox(height: 12),
                            Text('Agregar foto', style: TextStyle(color: Colors.white.withOpacity(0.5))),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),

              DropdownButtonFormField<String>(
                value: _time,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Desayuno')),
                  DropdownMenuItem(value: 'lunch', child: Text('Almuerzo')),
                  DropdownMenuItem(value: 'snack', child: Text('Merienda')),
                  DropdownMenuItem(value: 'dinner', child: Text('Cena')),
                ],
                onChanged: (v) => setState(() => _time = v!),
                decoration: InputDecoration(
                  labelText: 'Momento del día',
                  labelStyle: TextStyle(color: AppColors.textLight),
                  prefixIcon: const Icon(Icons.schedule_rounded, color: AppColors.warning),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Nombre de la comida', 
                  hintText: 'Ej: Pollo con arroz',
                  prefixIcon: const Icon(Icons.restaurant_rounded, color: AppColors.warning),
                ),
                validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
               TextFormField(
                controller: _calController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Calorías (aprox)', 
                  hintText: 'Ej: 500',
                  prefixIcon: const Icon(Icons.local_fire_department_rounded, color: AppColors.warning),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Descripción / Ingredientes',
                  prefixIcon: const Icon(Icons.notes_rounded, color: AppColors.warning),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text('GUARDAR COMIDA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodBankSearchSheet extends ConsumerStatefulWidget {
  const _FoodBankSearchSheet();

  @override
  ConsumerState<_FoodBankSearchSheet> createState() => _FoodBankSearchSheetState();
}

class _FoodBankSearchSheetState extends ConsumerState<_FoodBankSearchSheet> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  Future<void> _search(String query) async {
    if (query.length < 2) return;
    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(trainerServiceProvider);
      final results = await service.searchFoodBank(query);
      setState(() => _results = results);
    } catch (e) {
      // ignore error
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context), 
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)
              ),
              const Expanded(
                child: Text(
                  'Banco de Alimentos', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white), 
                  textAlign: TextAlign.center
                )
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Ej: Pollo, avena, pasta...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.warning),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
               if (val.length > 2) _search(val);
            },
            onSubmitted: _search,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: AppColors.warning))
              : _results.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                          const SizedBox(height: 16),
                          Text('Busca una comida para ver resultados', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                        ],
                      )
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.02),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(item['meal_title'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              item['meal_description'] ?? '', 
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.textLight),
                            ),
                            leading: Container(
                              width: 45,
                              height: 45,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withOpacity(0.05),
                                image: item['image_url'] != null
                                   ? DecorationImage(image: NetworkImage(item['image_url']), fit: BoxFit.cover)
                                   : null,
                              ),
                              child: item['image_url'] == null 
                                ? const Icon(Icons.restaurant_rounded, size: 20, color: AppColors.warning)
                                : null,
                            ),
                            trailing: Text(
                              '${item['calories'] ?? 0} kcal',
                              style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold),
                            ),
                            onTap: () => Navigator.pop(context, item),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

final mealPlanDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, planId) async {
  final service = ref.watch(trainerServiceProvider);
  return service.getMealPlan(planId);
});

class _EditMealPlanSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> plan;

  const _EditMealPlanSheet({required this.plan});

  @override
  ConsumerState<_EditMealPlanSheet> createState() => _EditMealPlanSheetState();
}

class _EditMealPlanSheetState extends ConsumerState<_EditMealPlanSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _caloriesController;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.plan['title']);
    _descController = TextEditingController(text: widget.plan['description']);
    _caloriesController = TextEditingController(text: widget.plan['target_calories']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (mounted) {
        setState(() => _selectedImage = File(pickedFile.path));
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final trainerService = ref.read(trainerServiceProvider);
      final storageService = ref.read(storageServiceProvider);

      await trainerService.updateMealPlan(
        planId: widget.plan['id'],
        title: _nameController.text.trim(),
        description: _descController.text.trim(),
        targetCalories: int.tryParse(_caloriesController.text.trim()),
        imageFile: _selectedImage,
        storageService: storageService,
      );

      ref.invalidate(mealPlanDetailProvider(widget.plan['id']));
      ref.invalidate(myMealPlansProvider);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plan actualizado exitosamente'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.edit_rounded, color: AppColors.warning, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Editar Plan',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _save,
                    style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
                        : const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : widget.plan['image_url'] != null 
                                  ? DecorationImage(
                                      image: NetworkImage(widget.plan['image_url']),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                        ),
                        child: _selectedImage == null && widget.plan['image_url'] == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, 
                                       size: 40, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cambiar portada',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                    ),

                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nombre del plan',
                        prefixIcon: Icon(Icons.restaurant_menu_rounded, color: AppColors.warning),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Calorías objetivo',
                        prefixIcon: Icon(Icons.local_fire_department_rounded, color: AppColors.warning),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Notas',
                        prefixIcon: Icon(Icons.notes_rounded, color: AppColors.warning),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
