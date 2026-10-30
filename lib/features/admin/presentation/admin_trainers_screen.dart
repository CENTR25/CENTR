import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../widgets/admin_common.dart';
import '../widgets/admin_invite_trainer_sheet.dart';
import 'admin_trainer_detail_screen.dart';

enum _TrainerFilter { todos, sinPlan, activos, invitados }

/// Admin Entrenadores — searchable, filterable list of trainers.
class AdminTrainersView extends ConsumerStatefulWidget {
  const AdminTrainersView({super.key});

  @override
  ConsumerState<AdminTrainersView> createState() => _AdminTrainersViewState();
}

class _AdminTrainersViewState extends ConsumerState<AdminTrainersView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _TrainerFilter _filter = _TrainerFilter.todos;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openInvite() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminInviteTrainerSheet(),
    );
  }

  bool _matchesFilter(Map<String, dynamic> t) {
    final hasSub = t['subscription'] != null;
    final profile = t['profiles'] as Map<String, dynamic>?;
    final firstLogin = profile?['first_login_at'];
    switch (_filter) {
      case _TrainerFilter.todos:
        return true;
      case _TrainerFilter.sinPlan:
        return !hasSub;
      case _TrainerFilter.activos:
        return hasSub;
      case _TrainerFilter.invitados:
        return firstLogin == null;
    }
  }

  bool _matchesQuery(Map<String, dynamic> t) {
    if (_query.isEmpty) return true;
    final name = (t['name'] ?? '').toString().toLowerCase();
    final email =
        ((t['profiles'] as Map<String, dynamic>?)?['email'] ?? '')
            .toString()
            .toLowerCase();
    return name.contains(_query) || email.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    final trainersAsync = ref.watch(adminTrainersProvider);

    return RefreshIndicator(
      color: RedesignColors.actionPrimary,
      backgroundColor: RedesignColors.primario800,
      onRefresh: () async {
        ref.invalidate(adminTrainersProvider);
        await ref.read(adminTrainersProvider.future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AdminGradientHeader(
              title: 'Entrenadores',
              trailing: _InvitarPill(onTap: _openInvite),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 130),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    style: RedesignType.bodySm
                        .copyWith(color: RedesignColors.primario50),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o email',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Todos', _TrainerFilter.todos),
                        const SizedBox(width: 8),
                        _chip('Sin plan', _TrainerFilter.sinPlan),
                        const SizedBox(width: 8),
                        _chip('Activos', _TrainerFilter.activos),
                        const SizedBox(width: 8),
                        _chip('Invitados', _TrainerFilter.invitados),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  trainersAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Text(
                        'Error: $e',
                        style: const TextStyle(color: RedesignColors.danger),
                      ),
                    ),
                    data: (trainers) {
                      final filtered = trainers
                          .where(_matchesFilter)
                          .where(_matchesQuery)
                          .toList();
                      if (filtered.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              _query.isEmpty
                                  ? 'No hay entrenadores en esta vista.'
                                  : 'Sin resultados para "$_query"',
                              style: RedesignType.bodySm.copyWith(
                                color: RedesignColors.primario300,
                              ),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final t in filtered) _TrainerCard(trainer: t),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, _TrainerFilter value) {
    return AdminFilterChip(
      label: label,
      active: _filter == value,
      onTap: () => setState(() => _filter = value),
    );
  }
}

class _InvitarPill extends StatelessWidget {
  final VoidCallback onTap;
  const _InvitarPill({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: RedesignColors.actionPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_alt_1_rounded,
                color: RedesignColors.onActionPrimary, size: 18),
            const SizedBox(width: 6),
            Text(
              'Invitar',
              style: RedesignType.buttonSm.copyWith(
                color: RedesignColors.onActionPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final Map<String, dynamic> trainer;
  const _TrainerCard({required this.trainer});

  String _subtitle() {
    final sub = trainer['subscription'] as Map<String, dynamic>?;
    if (sub == null) return 'Sin suscripción';
    final plan = sub['subscription_plans'] as Map<String, dynamic>?;
    final planName = plan?['name'] as String? ?? 'Plan';
    final maxStudents = plan?['max_students'] as int?;
    final days = _daysUntil(sub['ends_at'] as String?);
    if (days != null && days <= 7) {
      return '$planName · vence en $days día${days == 1 ? '' : 's'}';
    }
    final alumnos = trainer['alumnos_count'] as int? ?? 0;
    final maxLabel = maxStudents != null ? '/$maxStudents' : '';
    return '$planName · $alumnos$maxLabel alumnos';
  }

  int? _daysUntil(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return null;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
  }

  @override
  Widget build(BuildContext context) {
    final name = (trainer['name'] ?? 'Sin nombre').toString();
    final photo = trainer['profile_photo'] as String?;
    final id = trainer['id'] as String;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'E';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AdminCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AdminTrainerDetailScreen(trainerId: id),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
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
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: RedesignType.bodySm.copyWith(
                      color: RedesignColors.primario50,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(),
                    style: RedesignType.label
                        .copyWith(color: RedesignColors.primario300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
