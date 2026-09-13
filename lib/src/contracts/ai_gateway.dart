import '../models/model_ai_request.dart';
import '../models/model_ai_response.dart';
import 'ai_result.dart';

/// Runtime-independent inference using locally available model resources.
/// Implementations map expected infrastructure errors to AiFailureResult and
/// correlate successful responses with the requestId/modelId of the request.
/// No implicit network access or remote fallback is permitted during inference.
abstract interface class AiGateway {
  /// Returns a terminal response or a domain failure.
  /// v0 has no active cancellation control or cancellation finish reason.
  /// Valid but unsupported content uses unsupportedCapability, never lossy
  /// coercion or text-only success. Declarations are not runtime certification.
  /// Execution cancellation is deferred to the runtime/streaming contract.
  Future<AiResult<ModelAiResponse>> infer(ModelAiRequest request);
}
