import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/student_service.dart';

class StudentMealPlanScreen extends ConsumerStatefulWidget {
  const StudentMealPlanScreen({super.key});

  @override
  ConsumerState<StudentMealPlanScreen> createState() => _StudentMealPlanScreenState();
}

class _StudentMealPlanScreenState extends ConsumerState<StudentMealPlanScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _currentDay = 1;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(activeMealPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Plan Alimenticio'),
      ),
      body: planAsync.when(
        data: (plan) {
          if (plan == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  const Text('No tienes un plan activo', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }

          final items = (plan['meal_plan_items'] as List?) ?? [];
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
                    if (plan['description'] != null)
                      Flexible(
                        child: Text(
                          plan['description'],
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                            Icon(Icons.restaurant, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            const Text('Descanso o libre', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: dayItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _StudentMealItemCard(item: dayItems[index]);
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
    );
  }
}

class _StudentMealItemCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _StudentMealItemCard({required this.item});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item['image_url'] != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: CachedNetworkImage(
                imageUrl: item['image_url'],
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Center(child: Icon(Icons.image, color: Colors.grey)),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 150,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
          ListTile(
            leading: item['image_url'] == null
                ? CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(Icons.restaurant, color: color, size: 20),
                  )
                : null,
            title: Text(item['meal_title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(timeLabel, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                if (item['calories'] != null) Text('${item['calories']} kcal'),
                if (item['meal_description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(item['meal_description']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
