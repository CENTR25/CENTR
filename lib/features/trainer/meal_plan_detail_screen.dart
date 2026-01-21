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
      appBar: AppBar(
        title: Text(widget.planName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
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
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: AppColors.warning),
                    const SizedBox(width: 8),
                     Text(
                      'Objetivo: ${plan['target_calories'] ?? '-'} kcal',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        plan['objective'] ?? 'General',
                        style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
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
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.warning,
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
                            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text('Sin comidas para este día', style: TextStyle(color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => _showAddMeal(dayNum),
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar comida'),
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
        child: const Icon(Icons.add),
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

    return Card(
      child: ListTile(
        leading: item['image_url'] != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: item['image_url'],
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              )
            : CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                child: Icon(Icons.restaurant, color: color, size: 20),
              ),
        title: Text(item['meal_title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(timeLabel, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            if (item['calories'] != null) Text('${item['calories']} kcal'),
            if (item['meal_description'] != null) Text(item['meal_description'], maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
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
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text('Agregar Comida - Día ${widget.day}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   TextButton.icon(
                     onPressed: _showFoodBankSearch,
                     icon: const Icon(Icons.search),
                     label: const Text('Buscar en Banco'),
                   )
                ],
              ),
              const SizedBox(height: 24),
              
              // Image Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    image: _imageFile != null
                        ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Agregar foto (opcional)', style: TextStyle(color: Colors.grey)),
                          ],
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _time,
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Desayuno')),
                  DropdownMenuItem(value: 'lunch', child: Text('Almuerzo')),
                  DropdownMenuItem(value: 'snack', child: Text('Merienda')),
                  DropdownMenuItem(value: 'dinner', child: Text('Cena')),
                ],
                onChanged: (v) => setState(() => _time = v!),
                decoration: const InputDecoration(labelText: 'Momento del día'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre de la comida', hintText: 'Ej: Pollo con arroz'),
                validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
               TextFormField(
                controller: _calController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorías (aprox)', hintText: 'Ej: 500'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción / Ingredientes / Macros'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Guardar'),
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
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              const Expanded(child: Text('Banco de Alimentos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center)),
              const SizedBox(width: 48), // balance space
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar comida (ej: pollo, avena...)',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            onChanged: (val) {
               // Debounce could be good, but for now direct call if length > 2
               if (val.length > 2) _search(val);
            },
            onSubmitted: _search,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty 
                  ? Center(child: Text('Busca una comida para ver resultados', style: TextStyle(color: Colors.grey.shade400)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return ListTile(
                          title: Text(item['meal_title'] ?? ''),
                          subtitle: Text(item['meal_description'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                          leading: item['image_url'] != null
                             ? CircleAvatar(backgroundImage: NetworkImage(item['image_url']))
                             : const CircleAvatar(child: Icon(Icons.restaurant, size: 16)),
                          trailing: Text('${item['calories'] ?? 0} kcal'),
                          onTap: () => Navigator.pop(context, item),
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Editar Plan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
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
                        height: 150,
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
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
                                  Icon(Icons.add_photo_alternate_outlined, 
                                       size: 40, color: Colors.grey.shade600),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Cambiar portada',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
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
                      decoration: const InputDecoration(
                        labelText: 'Nombre del plan',
                        prefixIcon: Icon(Icons.restaurant_menu),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _caloriesController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Calorías objetivo',
                        prefixIcon: Icon(Icons.local_fire_department),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Notas',
                        prefixIcon: Icon(Icons.notes),
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
