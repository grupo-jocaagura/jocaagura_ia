// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/domain_values.dart';
import 'model_ai_usage.dart';

/// A successful terminal inference result, completed or stopped at an output limit.
final class ModelAiResponse {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiResponse({
    required this.requestId,
    required this.modelId,
    required this.text,
    required this.finishReason,
    this.usage,
  }) {
    requireText(requestId, 'requestId');
    requireText(modelId, 'modelId');
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiResponse.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiResponse(
      requestId: readString(json['requestId'], 'requestId'),
      modelId: readString(json['modelId'], 'modelId'),
      text: readString(json['text'], 'text'),
      finishReason: readEnum(
        json['finishReason'],
        EnumAiFinishReason.values,
        'finishReason',
      ),
      usage: json['usage'] == null
          ? null
          : ModelAiUsage.fromJson(readObject(json['usage'], 'usage')),
    ),
  );

  /// Identifier of the originating request.
  final String requestId;

  /// Logical model identifier used for the inference.
  final String modelId;

  /// Generated text, which may be empty.
  final String text;

  /// Successful termination reason.
  final EnumAiFinishReason finishReason;

  /// Optional measurements supplied by the runtime.
  final ModelAiUsage? usage;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'requestId': requestId,
    'modelId': modelId,
    'text': text,
    'finishReason': finishReason.name,
    'usage': usage?.toJson(),
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiResponse copyWith({
    String? requestId,
    String? modelId,
    String? text,
    EnumAiFinishReason? finishReason,
    Object? usage = unset,
  }) => ModelAiResponse(
    requestId: requestId ?? this.requestId,
    modelId: modelId ?? this.modelId,
    text: text ?? this.text,
    finishReason: finishReason ?? this.finishReason,
    usage: nullableUpdate<ModelAiUsage>(usage, this.usage),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiResponse &&
          requestId == other.requestId &&
          modelId == other.modelId &&
          text == other.text &&
          finishReason == other.finishReason &&
          usage == other.usage;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[requestId, modelId, text, finishReason, usage]);
}
