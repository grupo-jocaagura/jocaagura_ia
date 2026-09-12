// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../internal/domain_values.dart';

/// Runtime-reported measurements; null means unknown and zero is measured.
final class ModelAiUsage {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiUsage({this.inputTokens, this.outputTokens, this.totalTokens}) {
    requireCount(inputTokens, 'inputTokens');
    requireCount(outputTokens, 'outputTokens');
    requireCount(totalTokens, 'totalTokens');
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiUsage.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiUsage(
      inputTokens: readOptionalInt(json['inputTokens'], 'inputTokens'),
      outputTokens: readOptionalInt(json['outputTokens'], 'outputTokens'),
      totalTokens: readOptionalInt(json['totalTokens'], 'totalTokens'),
    ),
  );

  /// Reported input tokens, or null if unknown.
  final int? inputTokens;

  /// Reported output tokens, or null if unknown.
  final int? outputTokens;

  /// Independently reported total; not derived from other counts.
  final int? totalTokens;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'totalTokens': totalTokens,
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiUsage copyWith({
    Object? inputTokens = unset,
    Object? outputTokens = unset,
    Object? totalTokens = unset,
  }) => ModelAiUsage(
    inputTokens: nullableUpdate<int>(inputTokens, this.inputTokens),
    outputTokens: nullableUpdate<int>(outputTokens, this.outputTokens),
    totalTokens: nullableUpdate<int>(totalTokens, this.totalTokens),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiUsage &&
          inputTokens == other.inputTokens &&
          outputTokens == other.outputTokens &&
          totalTokens == other.totalTokens;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[inputTokens, outputTokens, totalTokens]);
}
