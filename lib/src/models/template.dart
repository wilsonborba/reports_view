import 'report.dart';

/// Slot definition of a published visual template version.
class TemplateSlot {
  final String slotName;

  /// dimension, measure, series, label, value, node_id, parent_id, edge_source, edge_target, group
  final String role;
  final bool isRequired;
  final int minCount;
  final int maxCount;
  final List<String> acceptedTypes;

  const TemplateSlot({
    required this.slotName,
    required this.role,
    this.isRequired = true,
    this.minCount = 1,
    this.maxCount = 1,
    this.acceptedTypes = const [],
  });

  factory TemplateSlot.fromJson(Map<String, dynamic> j) => TemplateSlot(
        slotName: '${j['slot_name'] ?? ''}',
        role: '${j['role'] ?? 'dimension'}',
        isRequired: (j['is_required'] as bool?) ?? true,
        minCount: (j['min_count'] as num?)?.toInt() ?? 0,
        maxCount: (j['max_count'] as num?)?.toInt() ?? 1,
        acceptedTypes: ((j['accepted_types'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  Map<String, dynamic> toJson() => {
        'slot_name': slotName,
        'role': role,
        'is_required': isRequired,
        'min_count': minCount,
        'max_count': maxCount,
        'accepted_types': acceptedTypes,
      };
}

/// Configurable option of a published visual template version.
class TemplateOption {
  final String optionName;

  /// bool, int, float, text, enum
  final String valueType;
  final String defaultValue;
  final List<String> allowedValues;

  const TemplateOption({
    required this.optionName,
    required this.valueType,
    this.defaultValue = '',
    this.allowedValues = const [],
  });

  factory TemplateOption.fromJson(Map<String, dynamic> j) => TemplateOption(
        optionName: '${j['option_name'] ?? ''}',
        valueType: '${j['value_type'] ?? 'text'}',
        defaultValue: '${j['default_value'] ?? ''}',
        allowedValues: ((j['allowed_values'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  Map<String, dynamic> toJson() => {
        'option_name': optionName,
        'value_type': valueType,
        'default_value': defaultValue,
        'allowed_values': allowedValues,
      };
}

/// Published immutable visual template version returned by template discovery.
class VisualTemplate {
  final String templateId;
  final int version;

  /// chart or diagram
  final String kind;
  final String visual;
  final String title;
  final List<TemplateSlot> slots;
  final List<TemplateOption> options;

  const VisualTemplate({
    required this.templateId,
    required this.version,
    required this.kind,
    required this.visual,
    required this.title,
    this.slots = const [],
    this.options = const [],
  });

  factory VisualTemplate.fromJson(Map<String, dynamic> j) => VisualTemplate(
        templateId: '${j['template_id'] ?? ''}',
        version: (j['version'] as num?)?.toInt() ?? 1,
        kind: '${j['kind'] ?? 'chart'}',
        visual: '${j['visual'] ?? 'auto'}',
        title: '${j['title'] ?? j['template_id'] ?? ''}',
        slots: ((j['slots'] as List?) ?? const [])
            .map((e) => TemplateSlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        options: ((j['options'] as List?) ?? const [])
            .map((e) => TemplateOption.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'version': version,
        'kind': kind,
        'visual': visual,
        'title': title,
        'slots': [for (final s in slots) s.toJson()],
        'options': [for (final o in options) o.toJson()],
      };
}

/// Binding of a dataset or consumer aggregate to a published template version.
class CardVisualBinding {
  final String template;
  final int version;
  final Map<String, List<String>> mapping;
  final Map<String, String> options;

  const CardVisualBinding({
    required this.template,
    required this.version,
    required this.mapping,
    this.options = const {},
  });

  factory CardVisualBinding.fromJson(Map<String, dynamic> j) {
    final rawMap = (j['mapping'] as Map?) ?? const {};
    final parsedMap = <String, List<String>>{};
    for (final entry in rawMap.entries) {
      final vals = entry.value is List ? (entry.value as List).map((e) => '$e').toList() : <String>[];
      parsedMap['${entry.key}'] = vals;
    }
    final rawOpts = (j['options'] as Map?) ?? const {};
    final parsedOpts = <String, String>{
      for (final entry in rawOpts.entries) '${entry.key}': '${entry.value}',
    };
    return CardVisualBinding(
      template: '${j['template'] ?? ''}',
      version: (j['version'] as num?)?.toInt() ?? 1,
      mapping: parsedMap,
      options: parsedOpts,
    );
  }

  Map<String, dynamic> toJson() => {
        'template': template,
        'version': version,
        'mapping': mapping,
        'options': options,
      };
}

class TemplateValidationResult {
  final bool isValid;
  final String? error;

  const TemplateValidationResult._(this.isValid, this.error);

  const TemplateValidationResult.ok() : this._(true, null);

  const TemplateValidationResult.fail(String message) : this._(false, message);
}

/// Validates a [CardVisualBinding] against [VisualTemplate] slots and [DatasetDescriptor] fields
/// before any chart widget is drawn.
class TemplateValidator {
  static TemplateValidationResult validate(
    VisualTemplate template,
    CardVisualBinding binding,
    DatasetDescriptor descriptor,
  ) {
    if (binding.template != template.templateId || binding.version != template.version) {
      return TemplateValidationResult.fail(
        'Binding targets ${binding.template} v${binding.version}, expected ${template.templateId} v${template.version}',
      );
    }

    final slotNames = {for (final s in template.slots) s.slotName};
    for (final key in binding.mapping.keys) {
      if (!slotNames.contains(key)) {
        return TemplateValidationResult.fail("Unknown template slot '$key'");
      }
    }

    for (final slot in template.slots) {
      final fields = binding.mapping[slot.slotName] ?? const <String>[];
      if (slot.isRequired && fields.length < slot.minCount) {
        return TemplateValidationResult.fail(
          "Slot '${slot.slotName}' requires at least ${slot.minCount} field(s)",
        );
      }
      if (fields.length > slot.maxCount) {
        return TemplateValidationResult.fail(
          "Slot '${slot.slotName}' allows at most ${slot.maxCount} field(s)",
        );
      }
      for (final fieldName in fields) {
        final field = descriptor.field(fieldName);
        if (field == null) {
          return TemplateValidationResult.fail(
            "Unknown field '$fieldName' for slot '${slot.slotName}'",
          );
        }
        if (slot.acceptedTypes.isNotEmpty && !slot.acceptedTypes.contains(field.type)) {
          return TemplateValidationResult.fail(
            "Field '$fieldName' has type '${field.type}', expected ${slot.acceptedTypes.join(', ')}",
          );
        }
      }
    }

    return const TemplateValidationResult.ok();
  }
}
