import 'package:flutter/material.dart';
import '../core/constants/intake_form.dart';

// ---------------------------------------------------------------------------
// Icon lookup — maps the string names stored in the DB back to IconData.
// Only the icons used in kIntakeSections are listed here.
// ---------------------------------------------------------------------------

const _kIconByName = <String, IconData>{
  'badge_outlined': Icons.badge_outlined,
  'fitness_center': Icons.fitness_center_rounded,
  'restaurant': Icons.restaurant_rounded,
  'schedule': Icons.schedule_rounded,
  'flag': Icons.flag_rounded,
  // Legacy / extras
  'assignment': Icons.assignment_outlined,
  'person': Icons.person_rounded,
};

final _kNameByIcon = <IconData, String>{
  Icons.badge_outlined: 'badge_outlined',
  Icons.fitness_center_rounded: 'fitness_center',
  Icons.restaurant_rounded: 'restaurant',
  Icons.schedule_rounded: 'schedule',
  Icons.flag_rounded: 'flag',
  Icons.assignment_outlined: 'assignment',
  Icons.person_rounded: 'person',
};

/// All distinct icon names available in the editor's icon picker.
const kIntakeIconNames = [
  'badge_outlined',
  'fitness_center',
  'restaurant',
  'schedule',
  'flag',
  'assignment',
  'person',
];

IconData iconFromName(String name) =>
    _kIconByName[name] ?? Icons.help_outline_rounded;

String iconToName(IconData icon) => _kNameByIcon[icon] ?? 'badge_outlined';

// ---------------------------------------------------------------------------
// DTOs
// ---------------------------------------------------------------------------

/// Runtime, serializable equivalent of [IntakeFieldType].
enum IntakeFieldTypeDtoEnum {
  text,
  longText,
  number,
  singleChoice,
  multiChoice;

  String toJson() => name;

  static IntakeFieldTypeDtoEnum fromJson(String s) {
    return IntakeFieldTypeDtoEnum.values.firstWhere(
      (e) => e.name == s,
      orElse: () => IntakeFieldTypeDtoEnum.text,
    );
  }

  IntakeFieldType toConst() {
    switch (this) {
      case IntakeFieldTypeDtoEnum.text:
        return IntakeFieldType.text;
      case IntakeFieldTypeDtoEnum.longText:
        return IntakeFieldType.longText;
      case IntakeFieldTypeDtoEnum.number:
        return IntakeFieldType.number;
      case IntakeFieldTypeDtoEnum.singleChoice:
        return IntakeFieldType.singleChoice;
      case IntakeFieldTypeDtoEnum.multiChoice:
        return IntakeFieldType.multiChoice;
    }
  }

  static IntakeFieldTypeDtoEnum fromConst(IntakeFieldType t) {
    switch (t) {
      case IntakeFieldType.text:
        return IntakeFieldTypeDtoEnum.text;
      case IntakeFieldType.longText:
        return IntakeFieldTypeDtoEnum.longText;
      case IntakeFieldType.number:
        return IntakeFieldTypeDtoEnum.number;
      case IntakeFieldType.singleChoice:
        return IntakeFieldTypeDtoEnum.singleChoice;
      case IntakeFieldType.multiChoice:
        return IntakeFieldTypeDtoEnum.multiChoice;
    }
  }
}

/// Mutable, serializable version of [IntakeField].
/// [keyLocked] is a UI-only flag set by the editor — it is NEVER persisted to
/// the DB; it's computed at load time by checking whether any athlete_intake
/// responses exist for this key.
class IntakeFieldDto {
  final String key;
  final String label;
  final IntakeFieldTypeDtoEnum type;
  final bool required;
  final List<String> options;
  final bool allowOther;
  final String? helper;
  final String? placeholder;
  final bool allowAudio;

  /// UI-only flag: true when at least one athlete has submitted a response
  /// for this field. When true the [key] is rendered read-only in the editor
  /// and removing the field triggers a warning dialog.
  final bool keyLocked;

  const IntakeFieldDto({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.allowOther = false,
    this.helper,
    this.placeholder,
    this.allowAudio = false,
    this.keyLocked = false,
  });

  IntakeFieldDto copyWith({
    String? key,
    String? label,
    IntakeFieldTypeDtoEnum? type,
    bool? required,
    List<String>? options,
    bool? allowOther,
    String? helper,
    String? placeholder,
    bool? allowAudio,
    bool? keyLocked,
  }) {
    return IntakeFieldDto(
      key: key ?? this.key,
      label: label ?? this.label,
      type: type ?? this.type,
      required: required ?? this.required,
      options: options ?? this.options,
      allowOther: allowOther ?? this.allowOther,
      helper: helper ?? this.helper,
      placeholder: placeholder ?? this.placeholder,
      allowAudio: allowAudio ?? this.allowAudio,
      keyLocked: keyLocked ?? this.keyLocked,
    );
  }

  factory IntakeFieldDto.fromMap(Map<String, dynamic> m) {
    return IntakeFieldDto(
      key: m['key'] as String? ?? '',
      label: m['label'] as String? ?? '',
      type: IntakeFieldTypeDtoEnum.fromJson(m['type'] as String? ?? 'text'),
      required: m['required'] as bool? ?? false,
      options: (m['options'] as List?)?.map((e) => e.toString()).toList() ?? [],
      allowOther: m['allow_other'] as bool? ?? false,
      helper: m['helper'] as String?,
      placeholder: m['placeholder'] as String?,
      allowAudio: m['allow_audio'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'type': type.toJson(),
      'required': required,
      'options': options,
      'allow_other': allowOther,
      if (helper != null) 'helper': helper,
      if (placeholder != null) 'placeholder': placeholder,
      'allow_audio': allowAudio,
    };
  }

  factory IntakeFieldDto.fromConst(IntakeField f) {
    return IntakeFieldDto(
      key: f.key,
      label: f.label,
      type: IntakeFieldTypeDtoEnum.fromConst(f.type),
      required: f.required,
      options: List.from(f.options),
      allowOther: f.allowOther,
      helper: f.helper,
      placeholder: f.placeholder,
      allowAudio: f.allowAudio,
    );
  }

  /// Convert back to a const-compatible [IntakeField] for use in the existing
  /// wizard and read-only view renderers.
  IntakeField toIntakeField() {
    return IntakeField(
      key: key,
      label: label,
      type: type.toConst(),
      required: required,
      options: options,
      allowOther: allowOther,
      helper: helper,
      placeholder: placeholder,
      allowAudio: allowAudio,
    );
  }
}

/// Mutable, serializable version of [IntakeSection].
class IntakeSectionDto {
  final String title;
  final String? subtitle;

  /// Icon stored as a string name, resolved at render time via [iconFromName].
  final String iconName;
  final List<IntakeFieldDto> fields;

  const IntakeSectionDto({
    required this.title,
    this.subtitle,
    required this.iconName,
    required this.fields,
  });

  IntakeSectionDto copyWith({
    String? title,
    String? subtitle,
    String? iconName,
    List<IntakeFieldDto>? fields,
  }) {
    return IntakeSectionDto(
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      iconName: iconName ?? this.iconName,
      fields: fields ?? this.fields,
    );
  }

  factory IntakeSectionDto.fromMap(Map<String, dynamic> m) {
    final rawFields = m['fields'] as List? ?? [];
    return IntakeSectionDto(
      title: m['title'] as String? ?? '',
      subtitle: m['subtitle'] as String?,
      iconName: m['icon_name'] as String? ?? 'badge_outlined',
      fields: rawFields
          .map((f) => IntakeFieldDto.fromMap(Map<String, dynamic>.from(f as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'icon_name': iconName,
      'fields': fields.map((f) => f.toMap()).toList(),
    };
  }

  /// Convert back to a const-compatible [IntakeSection] for renderers that
  /// still use [IntakeSection].
  IntakeSection toIntakeSection() {
    return IntakeSection(
      title: title,
      subtitle: subtitle,
      icon: iconFromName(iconName),
      fields: fields.map((f) => f.toIntakeField()).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Convert the hardcoded constant to DTOs (used as the in-code fallback)
// ---------------------------------------------------------------------------

List<IntakeSectionDto> kIntakeSectionsAsDto() {
  return kIntakeSections
      .map(
        (s) => IntakeSectionDto(
          title: s.title,
          subtitle: s.subtitle,
          iconName: iconToName(s.icon),
          fields: s.fields.map(IntakeFieldDto.fromConst).toList(),
        ),
      )
      .toList();
}

/// Helper: flatten all field DTOs from a list of section DTOs.
List<IntakeFieldDto> flattenFields(List<IntakeSectionDto> sections) => [
      for (final s in sections) ...s.fields,
    ];
