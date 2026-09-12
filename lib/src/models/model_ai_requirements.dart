// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../internal/domain_values.dart';

/// Known storage and minimum memory requirements in bytes; unknown values are null.
final class ModelAiRequirements {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiRequirements({this.storageBytes, this.minimumMemoryBytes}) {
    requireCount(storageBytes, 'storageBytes');
    requireCount(minimumMemoryBytes, 'minimumMemoryBytes');
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiRequirements.fromJson(Map<String, dynamic> json) =>
      decodeModel(
        () => ModelAiRequirements(
          storageBytes: readOptionalInt(json['storageBytes'], 'storageBytes'),
          minimumMemoryBytes: readOptionalInt(
            json['minimumMemoryBytes'],
            'minimumMemoryBytes',
          ),
        ),
      );

  /// Nonnegative storage requirement in bytes, if known.
  final int? storageBytes;

  /// Nonnegative minimum memory requirement in bytes, if known.
  final int? minimumMemoryBytes;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'storageBytes': storageBytes,
    'minimumMemoryBytes': minimumMemoryBytes,
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiRequirements copyWith({
    Object? storageBytes = unset,
    Object? minimumMemoryBytes = unset,
  }) => ModelAiRequirements(
    storageBytes: nullableUpdate<int>(storageBytes, this.storageBytes),
    minimumMemoryBytes: nullableUpdate<int>(
      minimumMemoryBytes,
      this.minimumMemoryBytes,
    ),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiRequirements &&
          storageBytes == other.storageBytes &&
          minimumMemoryBytes == other.minimumMemoryBytes;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[storageBytes, minimumMemoryBytes]);
}
