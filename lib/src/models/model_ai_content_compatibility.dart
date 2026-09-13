// Final fields and defensive copies keep this SDK-only value immutable.
// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import '../enums/ai_enums.dart';
import '../internal/content_values.dart';
import '../internal/domain_values.dart';

/// Pure assessment result. Meeting declarations does not certify inference.
final class ModelAiContentCompatibility {
  ModelAiContentCompatibility({
    required this.status,
    required List<String> reasons,
  }) : reasons = List<String>.unmodifiable(reasons) {
    if ((status == EnumAiContentCompatibilityStatus.meetsDeclaredConstraints) !=
            this.reasons.isEmpty ||
        this.reasons.any((String reason) => reason.trim().isEmpty)) {
      throw ArgumentError(
        'reasons: empty only for meetsDeclaredConstraints; otherwise nonblank',
      );
    }
  }
  factory ModelAiContentCompatibility.fromJson(Map<String, dynamic> json) {
    final EnumAiContentCompatibilityStatus status = decodeAt(
      'status',
      () => readContentEnum(
        json['status'],
        EnumAiContentCompatibilityStatus.values,
      ),
    );
    return decodeAt(
      'reasons',
      () => ModelAiContentCompatibility(
        status: status,
        reasons: readContentList(
          json['reasons'],
          (Object? value) => readString(value, 'value'),
        ),
      ),
    );
  }
  final EnumAiContentCompatibilityStatus status;

  /// Ordered diagnostics, never provider codes or resource contents.
  final List<String> reasons;
  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.name,
    'reasons': List<String>.of(reasons),
  };
  ModelAiContentCompatibility copyWith({
    Object? status = unset,
    Object? reasons = unset,
  }) => ModelAiContentCompatibility(
    status: requiredUpdate(status, this.status),
    reasons: requiredUpdate(reasons, this.reasons),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAiContentCompatibility &&
          status == other.status &&
          listEquals(reasons, other.reasons);
  @override
  int get hashCode => Object.hash(status, Object.hashAll(reasons));
}
