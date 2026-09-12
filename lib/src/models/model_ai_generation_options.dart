// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../internal/domain_values.dart';

/// Portable generation preferences; adapters validate runtime support.
final class ModelAiGenerationOptions {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiGenerationOptions({
    this.maxOutputTokens,
    this.temperature,
    List<String> stopSequences = const <String>[],
  }) : stopSequences = List<String>.unmodifiable(stopSequences) {
    requireCount(maxOutputTokens, 'maxOutputTokens', positive: true);
    requireReal(temperature, 'temperature');
    for (final String stop in this.stopSequences) {
      requireText(stop, 'stopSequences', allowWhitespace: true);
    }
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiGenerationOptions.fromJson(Map<String, dynamic> json) =>
      decodeModel(
        () => ModelAiGenerationOptions(
          maxOutputTokens: readOptionalInt(
            json['maxOutputTokens'],
            'maxOutputTokens',
          ),
          temperature: readOptionalDouble(json['temperature'], 'temperature'),
          stopSequences: json.containsKey('stopSequences')
              ? readList(json['stopSequences'], 'stopSequences')
                    .map((Object? value) => readString(value, 'stopSequences'))
                    .toList()
              : <String>[],
        ),
      );

  /// Positive output token limit, or null for the adapter default.
  final int? maxOutputTokens;

  /// Finite nonnegative sampling temperature, or null for the adapter default.
  final double? temperature;

  /// Ordered nonempty stop strings.
  final List<String> stopSequences;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'maxOutputTokens': maxOutputTokens,
    'temperature': temperature,
    'stopSequences': List<String>.of(stopSequences),
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiGenerationOptions copyWith({
    Object? maxOutputTokens = unset,
    Object? temperature = unset,
    List<String>? stopSequences,
  }) => ModelAiGenerationOptions(
    maxOutputTokens: nullableUpdate<int>(maxOutputTokens, this.maxOutputTokens),
    temperature: nullableUpdate<double>(temperature, this.temperature),
    stopSequences: stopSequences ?? this.stopSequences,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiGenerationOptions &&
          maxOutputTokens == other.maxOutputTokens &&
          temperature == other.temperature &&
          listEquals(stopSequences, other.stopSequences);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    maxOutputTokens,
    temperature,
    Object.hashAll(stopSequences),
  ]);
}
