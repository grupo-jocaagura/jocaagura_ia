/// The author role of an ordered context message.
enum EnumAiMessageRole { system, user, assistant }

/// Capabilities with a defined public domain contract.
enum EnumAiCapability { textGeneration }

/// How model resources are acquired, not where inference executes.
enum EnumAiSourceType { localFile, bundledAsset, remoteDownload }

/// Lifecycle status: installed resources are not necessarily loaded.
enum EnumAiModelStatus {
  notInstalled,
  installing,
  verifying,
  installed,
  loading,
  ready,
  unloading,
  removing,
  failed,
}

/// Successful terminal reasons; operational errors use AiFailureResult.
/// Active cancellation is deferred until an execution/streaming contract exists.
enum EnumAiFinishReason { completed, outputLimit }

/// Stable failure categories independent of an inference runtime.
enum EnumAiFailureCode {
  invalidRequest,
  modelUnavailable,
  integrityFailure,
  insufficientResources,
  unsupportedCapability,
  modelLoadFailure,
  inferenceFailure,
}

/// Valid lifecycle edges. A self-transition updates the current snapshot.
extension EnumAiModelStatusTransitions on EnumAiModelStatus {
  /// Whether the status edge is allowed, not a check of underlying resources.
  /// A failure must first resolve to a verified installed/notInstalled snapshot;
  /// it cannot imply that installation, loading, or removal can safely resume.
  bool canTransitionTo(EnumAiModelStatus next) {
    if (this == next) {
      return true;
    }
    return switch (this) {
      EnumAiModelStatus.notInstalled => next == EnumAiModelStatus.installing,
      EnumAiModelStatus.installing =>
        next == EnumAiModelStatus.verifying || next == EnumAiModelStatus.failed,
      EnumAiModelStatus.verifying =>
        next == EnumAiModelStatus.installed || next == EnumAiModelStatus.failed,
      EnumAiModelStatus.installed =>
        next == EnumAiModelStatus.loading || next == EnumAiModelStatus.removing,
      EnumAiModelStatus.loading =>
        next == EnumAiModelStatus.ready || next == EnumAiModelStatus.failed,
      EnumAiModelStatus.ready => next == EnumAiModelStatus.unloading,
      EnumAiModelStatus.unloading =>
        next == EnumAiModelStatus.installed || next == EnumAiModelStatus.failed,
      EnumAiModelStatus.removing =>
        next == EnumAiModelStatus.notInstalled ||
            next == EnumAiModelStatus.failed,
      EnumAiModelStatus.failed =>
        next == EnumAiModelStatus.installed ||
            next == EnumAiModelStatus.notInstalled,
    };
  }
}
