import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/intake_form.dart';
import '../../services/auth_service.dart';
import '../../services/student_service.dart';

/// One-time "Formulario para conocer al Atleta" the student completes after
/// onboarding, before reaching the dashboard. Renders from [kIntakeSections]
/// (shared with the trainer's read-only view) and submits the answers into
/// `athlete_intake` via [StudentService.submitIntake].
class StudentIntakeScreen extends ConsumerStatefulWidget {
  const StudentIntakeScreen({super.key});

  @override
  ConsumerState<StudentIntakeScreen> createState() => _StudentIntakeScreenState();
}

class _StudentIntakeScreenState extends ConsumerState<StudentIntakeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  /// Answers keyed by IntakeField.key. String for text/single-choice,
  /// `List<String>` for multi-choice.
  final Map<String, dynamic> _responses = {};

  /// Text controllers for text/number/longText fields and "Otro" inputs
  /// (keyed by field key, or `key__other` for the free-text option).
  final Map<String, TextEditingController> _controllers = {};

  /// Field keys whose "Otro" option is toggled open (input shown), even before
  /// any text is typed. Decouples the tap state from the stored free-text value.
  final Set<String> _otherOpen = {};

  @override
  void initState() {
    super.initState();
    // Prefill name + email from the signed-in account.
    final user = ref.read(authProvider).user;
    if (user != null) {
      if ((user.name ?? '').trim().isNotEmpty) {
        _responses['full_name'] = user.name!.trim();
      }
      if (user.email.trim().isNotEmpty) {
        _responses['email'] = user.email.trim();
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key, {String? initial}) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initial ?? ''),
    );
  }

  bool _isFieldAnswered(IntakeField field) {
    final value = _responses[field.key];
    if (field.type == IntakeFieldType.multiChoice) {
      return value is List && value.isNotEmpty;
    }
    return value is String && value.trim().isNotEmpty;
  }

  bool get _currentSectionValid {
    final section = kIntakeSections[_currentPage];
    for (final field in section.fields) {
      if (field.required && !_isFieldAnswered(field)) return false;
    }
    return true;
  }

  void _next() {
    if (!_currentSectionValid) {
      _showMissingWarning();
      return;
    }
    if (_currentPage < kIntakeSections.length - 1) {
      FocusScope.of(context).unfocus();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prev() {
    if (_currentPage > 0) {
      FocusScope.of(context).unfocus();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showMissingWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Por favor completá los campos obligatorios (*).'),
        backgroundColor: AppColors.warning,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_currentSectionValid) {
      _showMissingWarning();
      return;
    }
    setState(() => _isLoading = true);
    try {
      // Flush any pending "other" free-text into the responses map.
      final cleaned = <String, dynamic>{};
      for (final field in kIntakeFields) {
        final value = _responses[field.key];
        if (value == null) continue;
        if (value is List) {
          if (value.isNotEmpty) cleaned[field.key] = value;
        } else if (value is String && value.trim().isNotEmpty) {
          cleaned[field.key] = value.trim();
        }
      }

      await ref.read(studentServiceProvider).submitIntake(cleaned);
      await ref.read(authProvider.notifier).refreshProfile();

      if (mounted) context.go('/student');
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
    final isLast = _currentPage == kIntakeSections.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (p) => setState(() => _currentPage = p),
                itemCount: kIntakeSections.length,
                itemBuilder: (context, index) =>
                    _buildSectionPage(kIntakeSections[index]),
              ),
            ),
            _buildNav(isLast),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(kIntakeSections.length, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= _currentPage
                        ? AppColors.studentColor
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Paso ${_currentPage + 1} de ${kIntakeSections.length}',
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionPage(IntakeSection section) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          if (_currentPage == 0) ...[
            const Text(
              'Formulario para conocer al Atleta',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Completá con la mayor cantidad de información posible para que tu '
              'plan sea lo más personalizado posible.',
              style: TextStyle(color: AppColors.textLight, fontSize: 13),
            ),
            const SizedBox(height: 20),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.studentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(section.icon, color: AppColors.studentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (section.subtitle != null)
                      Text(
                        section.subtitle!,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...section.fields.map(_buildField),
        ],
      ),
    );
  }

  Widget _buildField(IntakeField field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: field.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
              children: [
                if (field.required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.studentColor),
                  ),
              ],
            ),
          ),
          if (field.helper != null) ...[
            const SizedBox(height: 4),
            Text(
              field.helper!,
              style: TextStyle(
                color: AppColors.textLight.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 10),
          switch (field.type) {
            IntakeFieldType.text => _buildTextInput(field),
            IntakeFieldType.number => _buildTextInput(field, number: true),
            IntakeFieldType.longText => _buildTextInput(field, multiline: true),
            IntakeFieldType.singleChoice => _buildSingleChoice(field),
            IntakeFieldType.multiChoice => _buildMultiChoice(field),
          },
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textLight.withValues(alpha: 0.4)),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.studentColor, width: 1.5),
      ),
    );
  }

  Widget _buildTextInput(
    IntakeField field, {
    bool multiline = false,
    bool number = false,
  }) {
    final controller = _controllerFor(
      field.key,
      initial: _responses[field.key] as String?,
    );
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      maxLines: multiline ? 4 : 1,
      minLines: multiline ? 3 : 1,
      keyboardType: number
          ? TextInputType.number
          : (multiline ? TextInputType.multiline : TextInputType.text),
      inputFormatters:
          number ? [FilteringTextInputFormatter.digitsOnly] : null,
      textCapitalization:
          multiline ? TextCapitalization.sentences : TextCapitalization.none,
      decoration: _inputDecoration(multiline ? 'Escribí tu respuesta...' : null),
      onChanged: (v) => setState(() => _responses[field.key] = v),
    );
  }

  Widget _buildSingleChoice(IntakeField field) {
    final current = _responses[field.key] as String?;
    final isOther =
        _otherOpen.contains(field.key) ||
        (current != null && !field.options.contains(current));
    return Column(
      children: [
        ...field.options.map((opt) {
          final selected = current == opt;
          return _choiceTile(
            label: opt,
            selected: selected,
            circular: true,
            onTap: () => setState(() {
              _otherOpen.remove(field.key);
              _responses[field.key] = opt;
            }),
          );
        }),
        if (field.allowOther)
          _otherTile(
            field: field,
            selected: isOther,
            multi: false,
            currentOtherText: isOther ? current : null,
          ),
      ],
    );
  }

  Widget _buildMultiChoice(IntakeField field) {
    final current = (_responses[field.key] as List?)?.cast<String>() ?? [];
    final otherValue = current.firstWhere(
      (v) => !field.options.contains(v),
      orElse: () => '',
    );
    final hasOther = otherValue.isNotEmpty || _otherOpen.contains(field.key);
    return Column(
      children: [
        ...field.options.map((opt) {
          final selected = current.contains(opt);
          return _choiceTile(
            label: opt,
            selected: selected,
            circular: false,
            onTap: () => setState(() {
              final list = [...current];
              if (selected) {
                list.remove(opt);
              } else {
                list.add(opt);
              }
              _responses[field.key] = list;
            }),
          );
        }),
        if (field.allowOther)
          _otherTile(
            field: field,
            selected: hasOther,
            multi: true,
            currentOtherText: hasOther ? otherValue : null,
          ),
      ],
    );
  }

  Widget _choiceTile({
    required String label,
    required bool selected,
    required bool circular,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.studentColor.withValues(alpha: 0.15)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.studentColor
                  : Colors.white.withValues(alpha: 0.08),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                circular
                    ? (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked)
                    : (selected
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded),
                color: selected ? AppColors.studentColor : AppColors.textLight,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textLight,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _otherTile({
    required IntakeField field,
    required bool selected,
    required bool multi,
    String? currentOtherText,
  }) {
    final controller = _controllerFor(
      '${field.key}__other',
      initial: currentOtherText,
    );
    return Column(
      children: [
        _choiceTile(
          label: 'Otro',
          selected: selected,
          circular: !multi,
          onTap: () => setState(() {
            if (selected) {
              _otherOpen.remove(field.key);
            } else {
              _otherOpen.add(field.key);
            }
            if (multi) {
              final list =
                  ((_responses[field.key] as List?)?.cast<String>() ?? [])
                      .where((v) => field.options.contains(v))
                      .toList();
              if (!selected && controller.text.trim().isNotEmpty) {
                list.add(controller.text.trim());
              }
              _responses[field.key] = list;
            } else {
              _responses[field.key] =
                  selected ? null : controller.text.trim();
            }
          }),
        ),
        if (selected)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Especificá...'),
              onChanged: (v) => setState(() {
                final text = v.trim();
                if (multi) {
                  final list =
                      ((_responses[field.key] as List?)?.cast<String>() ?? [])
                          .where((x) => field.options.contains(x))
                          .toList();
                  if (text.isNotEmpty) list.add(text);
                  _responses[field.key] = list;
                } else {
                  _responses[field.key] = text.isEmpty ? '' : text;
                }
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildNav(bool isLast) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: _prev,
              child: const Text(
                'Atrás',
                style: TextStyle(color: AppColors.textLight),
              ),
            )
          else
            const SizedBox(width: 60),
          const Spacer(),
          ElevatedButton(
            onPressed: _isLoading ? null : (isLast ? _submit : _next),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isLast ? AppColors.success : AppColors.studentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(isLast ? 'Enviar formulario' : 'Siguiente'),
          ),
        ],
      ),
    );
  }
}
