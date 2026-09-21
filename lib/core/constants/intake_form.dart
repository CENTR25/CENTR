import 'package:flutter/material.dart';

/// Single source of truth for the athlete intake questionnaire.
///
/// Both the student wizard (`student_intake_screen.dart`) and the trainer's
/// read-only view (`trainer/intake_view_screen.dart`) render from these
/// definitions, and answers are stored in `athlete_intake.responses` keyed by
/// [IntakeField.key]. Keep keys stable — they are the persisted contract.
enum IntakeFieldType { text, longText, number, singleChoice, multiChoice }

class IntakeField {
  final String key;
  final String label;
  final IntakeFieldType type;
  final bool required;

  /// Options for singleChoice / multiChoice fields.
  final List<String> options;

  /// Whether a singleChoice/multiChoice field allows a free-text "Otro" value.
  final bool allowOther;

  /// Helper text shown under the label (the grey hint on the Google form).
  final String? helper;

  const IntakeField({
    required this.key,
    required this.label,
    required this.type,
    this.required = false,
    this.options = const [],
    this.allowOther = false,
    this.helper,
  });
}

class IntakeSection {
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<IntakeField> fields;

  const IntakeSection({
    required this.title,
    this.subtitle,
    required this.icon,
    required this.fields,
  });
}

/// The questionnaire, mirroring the trainer's "Formulario para conocer al
/// Atleta". Copy is intentionally in Spanish (the app's language).
const List<IntakeSection> kIntakeSections = [
  IntakeSection(
    title: 'Datos Personales',
    subtitle: 'Datos básicos del atleta.',
    icon: Icons.badge_outlined,
    fields: [
      IntakeField(
        key: 'full_name',
        label: 'Nombre y Apellido',
        type: IntakeFieldType.text,
        required: true,
      ),
      IntakeField(
        key: 'email',
        label: 'E-Mail',
        type: IntakeFieldType.text,
        required: true,
      ),
      IntakeField(
        key: 'instagram',
        label: 'Instagram',
        type: IntakeFieldType.text,
        required: true,
      ),
      IntakeField(
        key: 'age',
        label: 'Edad',
        type: IntakeFieldType.number,
        required: true,
      ),
      IntakeField(
        key: 'height',
        label: 'Estatura',
        type: IntakeFieldType.text,
        required: true,
        helper: 'Por ej. 1.75 m',
      ),
      IntakeField(
        key: 'current_weight',
        label: 'Peso Actual',
        type: IntakeFieldType.text,
        required: true,
        helper: 'Por ej. 72 kg',
      ),
      IntakeField(
        key: 'initial_video_call',
        label:
            '¿Estás dispuesto/a a realizar una Videollamada Inicial una vez entregada la planificación para charlar juntos tus objetivos?',
        type: IntakeFieldType.singleChoice,
        required: true,
        options: ['Sí', 'No'],
        allowOther: true,
      ),
    ],
  ),
  IntakeSection(
    title: 'Entrenamiento',
    subtitle: 'Datos sobre tu entrenamiento.',
    icon: Icons.fitness_center_rounded,
    fields: [
      IntakeField(
        key: 'training_experience',
        label: '¿Hace cuánto entrenas?',
        type: IntakeFieldType.text,
        required: true,
      ),
      IntakeField(
        key: 'previous_routine',
        label: '¿Qué rutina estabas haciendo hasta el momento?',
        type: IntakeFieldType.longText,
      ),
      IntakeField(
        key: 'muscle_focus',
        label:
            '¿Alguna preferencia de qué División Muscular preferís? ¿O a qué quisieras darle más enfoque?',
        type: IntakeFieldType.longText,
        helper: 'Por ej. 2 días de piernas y 2 de tren superior.',
      ),
      IntakeField(
        key: 'gym',
        label: '¿En qué gimnasio entrenas?',
        type: IntakeFieldType.longText,
        helper:
            'Nombre y, si podés, link de Instagram o web. Así vemos la disponibilidad de equipamiento y te armamos un plan más personalizado.',
      ),
      IntakeField(
        key: 'days_per_week',
        label: '¿Cuántos días a la semana podés/querés ir a entrenar?',
        type: IntakeFieldType.singleChoice,
        required: true,
        options: ['2 días', '3 días', '4 días', '5 días', '6 días'],
      ),
      IntakeField(
        key: 'objective',
        label: 'Objetivo',
        type: IntakeFieldType.singleChoice,
        required: true,
        options: [
          'Volumen (ganancia de masa muscular)',
          'Definición (reducción de tejido adiposo)',
          'Recomposición (reducción de tejido adiposo y ganancia de masa muscular)',
        ],
      ),
    ],
  ),
  IntakeSection(
    title: 'Nutrición',
    subtitle: 'Datos sobre tu alimentación.',
    icon: Icons.restaurant_rounded,
    fields: [
      IntakeField(
        key: 'meals_per_day',
        label: '¿Cuántas comidas al día solés hacer? ¿O cuántas quisieras tener?',
        type: IntakeFieldType.text,
        required: true,
      ),
      IntakeField(
        key: 'intolerances',
        label: '¿Sufrís alguna intolerancia?',
        type: IntakeFieldType.multiChoice,
        options: ['Lactosa', 'T.A.C.C.'],
        allowOther: true,
      ),
      IntakeField(
        key: 'foods_disliked',
        label: 'Comidas que NO te gustan o no querés tener en tu plan alimenticio',
        type: IntakeFieldType.longText,
      ),
      IntakeField(
        key: 'foods_liked',
        label: 'Comidas que SÍ te gustaría tener en tu plan alimenticio',
        type: IntakeFieldType.longText,
        helper: 'Comidas que disfrutás y te gustaría conservar en tu plan.',
      ),
      IntakeField(
        key: 'supplements',
        label: '¿Consumís algún suplemento?',
        type: IntakeFieldType.longText,
        required: true,
        helper: 'Por ej. Proteína en polvo, Creatina, BCAA, Glutamina...',
      ),
      IntakeField(
        key: 'medication',
        label: '¿Consumís alguna medicación?',
        type: IntakeFieldType.longText,
        helper: 'Por ej. Medicación para tiroides, pastilla anticonceptiva...',
      ),
    ],
  ),
  IntakeSection(
    title: 'Agenda / Horarios',
    subtitle: 'Para ayudarte con las comidas y el entrenamiento.',
    icon: Icons.schedule_rounded,
    fields: [
      IntakeField(
        key: 'schedule',
        label: 'Contame un poco sobre tu agenda y horarios diarios',
        type: IntakeFieldType.longText,
        required: true,
        helper:
            '¿A qué horario irías a entrenar? ¿A qué hora solés desayunar/almorzar/cenar? ¿Tenés tiempo para cocinarte? Horarios laborales.',
      ),
    ],
  ),
  IntakeSection(
    title: 'Objetivos',
    subtitle: 'Objetivos a corto, mediano y largo plazo.',
    icon: Icons.flag_rounded,
    fields: [
      IntakeField(
        key: 'goal_short_term',
        label: 'Objetivo a CORTO plazo (1 mes)',
        type: IntakeFieldType.longText,
      ),
      IntakeField(
        key: 'goal_mid_term',
        label: 'Objetivo a MEDIANO plazo (3 meses)',
        type: IntakeFieldType.longText,
      ),
      IntakeField(
        key: 'goal_long_term',
        label: 'Objetivo a LARGO plazo (12 meses)',
        type: IntakeFieldType.longText,
      ),
    ],
  ),
];

/// Flattened view of every field, for lookups (e.g. the trainer view).
final List<IntakeField> kIntakeFields = [
  for (final section in kIntakeSections) ...section.fields,
];
