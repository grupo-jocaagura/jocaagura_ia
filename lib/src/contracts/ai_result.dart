import '../models/model_ai_failure.dart';

/// An operational result, not a persistable model. Payloads follow their own
/// immutability contracts; generic values are not deep-copied by this wrapper.
sealed class AiResult<T> {
  /// Allows the two exhaustive result variants.
  const AiResult();
}

/// A successfully completed operation containing [value].
final class AiSuccess<T> extends AiResult<T> {
  /// Creates a successful result. Collection payloads must be unmodifiable.
  const AiSuccess(this.value);

  /// The successful operation value.
  final T value;
}

/// An expected operational failure, never an infrastructure exception payload.
final class AiFailureResult<T> extends AiResult<T> {
  /// Creates a failed result.
  const AiFailureResult(this.failure);

  /// Stable domain failure information.
  final ModelAiFailure failure;
}
