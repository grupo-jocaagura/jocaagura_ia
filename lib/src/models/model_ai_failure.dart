// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/domain_values.dart';

/// Serializable operational failure independent of infrastructure exceptions.
final class ModelAiFailure {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiFailure({
    required this.code,
    required this.message,
    this.retryable = false,
  }) {
    requireText(message, 'message');
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiFailure.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiFailure(
      code: readEnum(json['code'], EnumAiFailureCode.values, 'code'),
      message: readString(json['message'], 'message'),
      retryable: readBool(json['retryable'], 'retryable'),
    ),
  );

  /// Stable failure category.
  final EnumAiFailureCode code;

  /// Nonblank, consumer-readable failure explanation.
  final String message;

  /// Whether the adapter considers a later retry appropriate.
  final bool retryable;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code.name,
    'message': message,
    'retryable': retryable,
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiFailure copyWith({
    EnumAiFailureCode? code,
    String? message,
    bool? retryable,
  }) => ModelAiFailure(
    code: code ?? this.code,
    message: message ?? this.message,
    retryable: retryable ?? this.retryable,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiFailure &&
          code == other.code &&
          message == other.message &&
          retryable == other.retryable;

  @override
  int get hashCode => Object.hashAll(<Object?>[code, message, retryable]);
}
