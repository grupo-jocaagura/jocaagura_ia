// This final value type uses final fields and defensive collection copies.
// The annotation-based lint requires package:meta; the domain is SDK-only.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/domain_values.dart';
import 'model_ai_failure.dart';

/// An immutable lifecycle snapshot, including measured progress and failures.
final class ModelAiState {
  /// Creates a validated immutable value; invalid arguments throw ArgumentError.
  ModelAiState({
    required this.modelId,
    required this.status,
    this.progress,
    this.failure,
  }) {
    requireText(modelId, 'modelId');
    requireReal(progress, 'progress', maximum: 1);
    if ((status == EnumAiModelStatus.failed) != (failure != null)) {
      throw ArgumentError('Failure is required exactly when status is failed');
    }
  }

  /// Decodes JSON, throwing FormatException for invalid or missing fields.
  factory ModelAiState.fromJson(Map<String, dynamic> json) => decodeModel(
    () => ModelAiState(
      modelId: readString(json['modelId'], 'modelId'),
      status: readEnum(json['status'], EnumAiModelStatus.values, 'status'),
      progress: readOptionalDouble(json['progress'], 'progress'),
      failure: json['failure'] == null
          ? null
          : ModelAiFailure.fromJson(readObject(json['failure'], 'failure')),
    ),
  );

  /// Logical model identifier.
  final String modelId;

  /// Current lifecycle status; installed differs from ready.
  final EnumAiModelStatus status;

  /// Finite progress in `[0, 1]`; null means no measurable progress.
  final double? progress;

  /// Present if and only if status is failed.
  final ModelAiFailure? failure;

  /// Returns independent JSON data with deterministic keys and enum names.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'modelId': modelId,
    'status': status.name,
    'progress': progress,
    'failure': failure?.toJson(),
  };

  /// Copies this value. Omitted nullable fields are preserved; null clears them.
  ModelAiState copyWith({
    String? modelId,
    EnumAiModelStatus? status,
    Object? progress = unset,
    Object? failure = unset,
  }) => ModelAiState(
    modelId: modelId ?? this.modelId,
    status: status ?? this.status,
    progress: nullableUpdate<double>(progress, this.progress),
    failure: nullableUpdate<ModelAiFailure>(failure, this.failure),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiState &&
          modelId == other.modelId &&
          status == other.status &&
          progress == other.progress &&
          failure == other.failure;

  @override
  int get hashCode =>
      Object.hashAll(<Object?>[modelId, status, progress, failure]);
}
