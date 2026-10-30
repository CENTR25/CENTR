import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_redesign.dart';
import '../../../services/admin_service.dart';
import '../../shared/redesign_toast.dart';
import 'admin_common.dart';
import 'admin_redesign_sheet.dart';

/// Create or edit a subscription plan. Pass [plan] to edit; omit to create.
class AdminPlanEditorSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? plan;

  const AdminPlanEditorSheet({super.key, this.plan});

  @override
  ConsumerState<AdminPlanEditorSheet> createState() =>
      _AdminPlanEditorSheetState();
}

class _AdminPlanEditorSheetState extends ConsumerState<AdminPlanEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _maxCtrl;
  late final TextEditingController _featuresCtrl;
  bool _loading = false;

  bool get _isEdit => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _nameCtrl = TextEditingController(text: p?['name']?.toString() ?? '');
    _priceCtrl = TextEditingController(
        text: p?['price'] != null ? (p!['price'] as num).round().toString() : '');
    _durationCtrl = TextEditingController(
        text: p?['duration_days']?.toString() ?? '30');
    _maxCtrl =
        TextEditingController(text: p?['max_students']?.toString() ?? '');
    _featuresCtrl = TextEditingController(
        text: adminFeatureLabels(p?['features']).join(', '));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _maxCtrl.dispose();
    _featuresCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final features = _featuresCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;
    final max =
        _maxCtrl.text.trim().isEmpty ? null : int.tryParse(_maxCtrl.text.trim());
    try {
      final admin = ref.read(adminServiceProvider);
      if (_isEdit) {
        await admin.updateSubscriptionPlan(
          widget.plan!['id'] as String,
          name: name,
          price: price,
          durationDays: duration,
          maxStudents: max,
          features: features,
        );
      } else {
        await admin.createSubscriptionPlan(
          name: name,
          price: price,
          durationDays: duration,
          maxStudents: max,
          features: features,
        );
      }
      ref.invalidate(subscriptionPlansProvider);
      ref.invalidate(planTrainerCountsProvider);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      showRedesignToast(
        nav.context,
        title: _isEdit ? 'Plan actualizado' : 'Plan creado',
        subtitle: 'Los cambios se guardaron.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showRedesignToast(
        context,
        title: 'No se pudo guardar',
        subtitle: '$e',
        icon: Icons.error_outline_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminRedesignSheet(
      children: [
        Text(
          _isEdit ? 'Editar plan' : 'Crear plan',
          style: RedesignType.headingMd.copyWith(
            color: RedesignColors.primario50,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 18),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field(
                controller: _nameCtrl,
                hint: 'Nombre del plan',
                icon: Icons.workspace_premium_outlined,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _priceCtrl,
                hint: 'Precio por mes',
                icon: Icons.attach_money_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _durationCtrl,
                hint: 'Duración (días)',
                icon: Icons.calendar_today_rounded,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              _field(
                controller: _maxCtrl,
                hint: 'Máximo de alumnos',
                icon: Icons.groups_outlined,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 12),
              _field(
                controller: _featuresCtrl,
                hint: 'Características (coma: Soporte, Analytics)',
                icon: Icons.checklist_rounded,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: RedesignColors.onActionPrimary,
                          ),
                        )
                      : Text(_isEdit ? 'Guardar cambios' : 'Crear plan'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: RedesignType.bodySm.copyWith(color: RedesignColors.primario50),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
    );
  }
}
