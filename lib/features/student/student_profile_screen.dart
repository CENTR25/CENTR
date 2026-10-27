import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_redesign.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';
import 'profile_constants.dart';
import 'student_profile_edit_screen.dart';

/// Student "Mi perfil" — view of the athlete's own profile. Reached from the
/// home side drawer. "Editar" opens [StudentProfileEditScreen].
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileAsync = ref.watch(myAthleteProfileProvider);

    return Theme(
      data: RedesignTheme.theme,
      child: Scaffold(
        backgroundColor: RedesignColors.background,
        body: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(RedesignColors.actionPrimary),
              ),
            ),
            error: (e, _) => Center(
              child: Text('No se pudo cargar tu perfil',
                  style: const TextStyle(color: RedesignColors.primario300)),
            ),
            data: (profile) {
              final name = (profile?['name'] as String?)?.trim().isNotEmpty ==
                      true
                  ? (profile!['name'] as String).trim()
                  : (user?.displayName ?? 'Atleta');
              final email = user?.email ?? '';
              final avatarUrl = profile?['avatar_url'] as String?;
              final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

              final weight = fmtNum(profile?['weight']);
              final height = fmtNum(profile?['height_cm']);
              final age = profile?['age'] != null ? '${profile!['age']}' : '';
              final goal = (profile?['goal'] as String?)?.trim() ?? '';
              final level = (profile?['training_level'] as String?)?.trim() ?? '';
              final injuries = (profile?['injuries'] as String?)?.trim() ?? '';
              final phone = (profile?['phone'] as String?)?.trim() ?? '';
              final trainerName =
                  (profile?['trainer_name'] as String?)?.trim() ?? '';

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top bar: back + Editar
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(Icons.arrow_back,
                                    color: Colors.white, size: 26),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const StudentProfileEditScreen(),
                                    ),
                                  );
                                  ref.invalidate(myAthleteProfileProvider);
                                },
                                child: const Text(
                                  'Editar',
                                  style: TextStyle(
                                    fontFamily: 'Metropolis',
                                    color: RedesignColors.secundario300,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Avatar + name + email
                          Center(
                            child: Column(
                              children: [
                                _Avatar(
                                    avatarUrl: avatarUrl,
                                    initial: initial,
                                    radius: 52),
                                const SizedBox(height: 14),
                                Text(
                                  name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'Metropolis',
                                    color: RedesignColors.primario50,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (email.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Metropolis',
                                      color: RedesignColors.primario400,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Stat cards: Peso / Altura / Edad
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Peso',
                                  value: weight.isNotEmpty ? weight : '–',
                                  unit: 'kg',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: 'Altura',
                                  value: height.isNotEmpty ? height : '–',
                                  unit: 'cm',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatCard(
                                  label: 'Edad',
                                  value: age.isNotEmpty ? age : '–',
                                  unit: 'años',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Info card
                          Container(
                            decoration: BoxDecoration(
                              color: RedesignColors.primario700,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                _InfoRow(
                                  icon: Icons.track_changes_rounded,
                                  label: 'Objetivo',
                                  value: goal.isNotEmpty ? goal : 'Sin definir',
                                ),
                                const _InfoDivider(),
                                _InfoRow(
                                  icon: Icons.directions_run_rounded,
                                  label: 'Nivel',
                                  value: level.isNotEmpty ? level : 'Sin definir',
                                ),
                                const _InfoDivider(),
                                _InfoRow(
                                  icon: Icons.healing_rounded,
                                  label: 'Lesiones / salud',
                                  value: injuries.isNotEmpty
                                      ? injuries
                                      : 'Sin registrar',
                                ),
                                const _InfoDivider(),
                                _InfoRow(
                                  icon: Icons.phone_rounded,
                                  label: 'Teléfono',
                                  value: phone.isNotEmpty ? phone : 'Sin cargar',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Mi entrenador
                          const Text(
                            'Mi entrenador',
                            style: TextStyle(
                              fontFamily: 'Metropolis',
                              color: RedesignColors.primario50,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 16),
                            decoration: BoxDecoration(
                              color: RedesignColors.primario700,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: const BoxDecoration(
                                    color: RedesignColors.secundario900,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.sports_rounded,
                                    color: RedesignColors.secundario300,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    trainerName.isNotEmpty
                                        ? trainerName
                                        : 'Sin entrenador asignado',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Metropolis',
                                      color: RedesignColors.primario50,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;
  final double radius;

  const _Avatar({
    required this.avatarUrl,
    required this.initial,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: RedesignColors.secundario500, width: 2.5),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: RedesignColors.primario800,
        backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
            ? NetworkImage(avatarUrl!)
            : null,
        child: (avatarUrl == null || avatarUrl!.isEmpty)
            ? Text(
                initial,
                style: TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario50,
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
      decoration: BoxDecoration(
        color: RedesignColors.primario700,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario400,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario50,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: const TextStyle(
                  fontFamily: 'Metropolis',
                  color: RedesignColors.primario400,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoDivider extends StatelessWidget {
  const _InfoDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: RedesignColors.primario600,
      indent: 18,
      endIndent: 18,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: RedesignColors.primario600,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: RedesignColors.secundario300, size: 20),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Metropolis',
              color: RedesignColors.primario50,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Metropolis',
                color: RedesignColors.primario300,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
