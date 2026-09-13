// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../internal/content_values.dart';
import '../internal/domain_values.dart';
import 'model_ai_generation_options.dart';
import 'model_ai_message.dart';

/// A logical model reference and ordered context for one inference.
final class ModelAiRequest {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiRequest({
    required this.requestId,
    required this.modelId,
    required List<ModelAiMessage> messages,
    ModelAiGenerationOptions? options,
  }) : messages = List<ModelAiMessage>.unmodifiable(messages),
       options = options ?? ModelAiGenerationOptions() {
    requireText(requestId, 'requestId');
    requireText(modelId, 'modelId');
    if (this.messages.isEmpty) {
      throw ArgumentError.value(
        messages,
        'messages',
        'At least one message is required',
      );
    }
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiRequest.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiRequest(
      requestId: readString(json['requestId'], 'requestId'),
      modelId: readString(json['modelId'], 'modelId'),
      messages: decodeAt(
        'messages',
        () => readContentList(
          json['messages'],
          (Object? value) =>
              ModelAiMessage.fromJson(readObject(value, 'value')),
        ),
      ),
      options: ModelAiGenerationOptions.fromJson(
        readObject(json['options'], 'options'),
      ),
    ),
  );

  /// Nonblank request identifier used to correlate the response.
  final String requestId;

  /// Logical model identifier; never a descriptor snapshot.
  final String modelId;

  /// Nonempty ordered context.
  final List<ModelAiMessage> messages;

  /// Generation preferences.
  final ModelAiGenerationOptions options;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'requestId': requestId,
    'modelId': modelId,
    'messages': messages.map((ModelAiMessage value) => value.toJson()).toList(),
    'options': options.toJson(),
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiRequest copyWith({
    String? requestId,
    String? modelId,
    List<ModelAiMessage>? messages,
    ModelAiGenerationOptions? options,
  }) => ModelAiRequest(
    requestId: requestId ?? this.requestId,
    modelId: modelId ?? this.modelId,
    messages: messages ?? this.messages,
    options: options ?? this.options,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiRequest &&
          requestId == other.requestId &&
          modelId == other.modelId &&
          listEquals(messages, other.messages) &&
          options == other.options;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    requestId,
    modelId,
    Object.hashAll(messages),
    options,
  ]);
}
