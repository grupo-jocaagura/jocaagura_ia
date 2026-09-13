// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/content_values.dart';
import '../internal/domain_values.dart';
import 'model_ai_content_part.dart';

/// An immutable message in ordered inference context.
final class ModelAiMessage {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiMessage({required this.role, required List<ModelAiContentPart> parts})
    : parts = List<ModelAiContentPart>.unmodifiable(parts) {
    if (this.parts.isEmpty) {
      throw ArgumentError('parts: at least one content part is required');
    }
  }

  /// Creates exactly one text part, without flattening existing content.
  ModelAiMessage.text({required EnumAiMessageRole role, required String text})
    : this(
        role: role,
        parts: <ModelAiContentPart>[ModelAiTextPart(text: text)],
      );

  /// Reads legacy content or canonical parts; both/neither keys are invalid.
  factory ModelAiMessage.fromJson(Map<String, dynamic> json) {
    final EnumAiMessageRole role = decodeAt(
      'role',
      () => readContentEnum(json['role'], EnumAiMessageRole.values),
    );
    if (json.containsKey('content') == json.containsKey('parts')) {
      throw const FormatException(
        'Exactly one of content or parts is required',
      );
    }
    if (json.containsKey('content')) {
      return decodeAt(
        'content',
        () => ModelAiMessage.text(
          role: role,
          text: readString(json['content'], 'value'),
        ),
      );
    }
    return decodeAt(
      'parts',
      () => ModelAiMessage(
        role: role,
        parts: readContentList(
          json['parts'],
          (Object? value) =>
              ModelAiContentPart.fromJson(readObject(value, 'value')),
        ),
      ),
    );
  }

  /// The message author role.
  final EnumAiMessageRole role;

  /// Nonempty ordered input. Parts are never coalesced or dropped.
  final List<ModelAiContentPart> parts;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role.name,
    'parts': parts.map((ModelAiContentPart part) => part.toJson()).toList(),
  };

  /// Omission preserves fields; explicit null is invalid for required fields.
  ModelAiMessage copyWith({Object? role = unset, Object? parts = unset}) =>
      ModelAiMessage(
        role: requiredUpdate(role, this.role),
        parts: requiredUpdate(parts, this.parts),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiMessage &&
          role == other.role &&
          listEquals(parts, other.parts);

  @override
  int get hashCode => Object.hash(role, Object.hashAll(parts));
}
