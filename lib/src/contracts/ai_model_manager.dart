import '../models/model_ai_descriptor.dart';
import '../models/model_ai_state.dart';
import 'ai_result.dart';

/// Acquires model resources and observes their installation/loading lifecycle.
/// Implementations serialize mutations per model ID, enforce the documented
/// status transitions, and map expected operational errors to domain failures.
/// See doc/domain.md for recovery, idempotence, and error mapping contracts.
abstract interface class AiModelManager {
  /// Returns known descriptors in an unmodifiable list, or a domain failure.
  Future<AiResult<List<ModelAiDescriptor>>> discover();

  /// Registers and acquires [model], verifying expected integrity before exposing
  /// installed resources. Conflicting configurations for the same ID fail.
  /// Network access is allowed only for explicit remoteDownload acquisition.
  Future<AiResult<ModelAiState>> install(ModelAiDescriptor model);

  /// Loads installed resources and returns ready on success.
  Future<AiResult<ModelAiState>> load(String modelId);

  /// Releases runtime resources, returning installed on success.
  Future<AiResult<ModelAiState>> unload(String modelId);

  /// Removes unloaded resources, returning notInstalled on success.
  Future<AiResult<ModelAiState>> remove(String modelId);

  /// Emits an initial snapshot then valid updates. Unknown IDs start notInstalled;
  /// blank IDs throw ArgumentError. Operational failures are failed snapshots,
  /// not stream errors. Cancelling a subscription releases its listener resources.
  Stream<ModelAiState> watch(String modelId);
}
