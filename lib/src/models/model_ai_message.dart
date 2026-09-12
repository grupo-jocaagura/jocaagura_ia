// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/domain_values.dart';

/// An immutable message in ordered inference context.
final class ModelAiMessage {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiMessage({required this.role, required this.content}) {
    requireText(content, 'content', allowWhitespace: true);
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiMessage.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiMessage(
      role: readEnum(json['role'], EnumAiMessageRole.values, 'role'),
      content: readString(json['content'], 'content'),
    ),
  );

  /// The message author role.
  final EnumAiMessageRole role;

  /// Nonempty text; whitespace is preserved.
  final String content;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'role': role.name,
    'content': content,
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiMessage copyWith({EnumAiMessageRole? role, String? content}) =>
      ModelAiMessage(role: role ?? this.role, content: content ?? this.content);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiMessage && role == other.role && content == other.content;

  @override
  int get hashCode => Object.hashAll(<Object?>[role, content]);
}
