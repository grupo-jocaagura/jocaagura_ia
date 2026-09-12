# Initial AI domain contract

## Scope

The Dart package is now named `jocaagura_ai` (formerly `jocaagura_ia`); the
GitHub repository name is unchanged. Import `package:jocaagura_ai/jocaagura_ai.dart`.
This rename does not change the domain API, enum names or serialized payloads.
The separate `packages/jocaagura_ai_server` consumes these contracts; engine,
transport and configuration code stay outside the core.

Implement the initial pure Dart domain for local AI inference and model lifecycle
management. No Flutter, jocaagura_domain, inference runtime, or production
third-party dependencies are introduced. Jocaagura conventions are adopted
without inheriting its Model base class. Streaming, multimodal payloads, remote
inference, active execution cancellation, persistence, runtime adapters, model
formats, inference-engine integration, and model provenance remain separate work.

## Data models

| Model | Fields |
| --- | --- |
| ModelAiMessage | role, content |
| ModelAiGenerationOptions | maxOutputTokens?, temperature?, stopSequences |
| ModelAiRequest | requestId, modelId, messages, options |
| ModelAiResponse | requestId, modelId, text, finishReason, usage? |
| ModelAiUsage | inputTokens?, outputTokens?, totalTokens? |
| ModelAiDescriptor | id, displayName, version, capabilities, requirements, source |
| ModelAiRequirements | storageBytes?, minimumMemoryBytes? |
| ModelAiSource | type, path?, assetPath?, url?, expectedSha256? |
| ModelAiState | modelId, status, progress?, failure? |
| ModelAiFailure | code, message, retryable |

There is no ModelAiPrompt: requests own an ordered list of messages. Requests
reference models by logical modelId; descriptors describe installable artifacts.
Model versions are opaque nonblank strings, not package release versions.

## Enums

- EnumAiMessageRole: system, user, assistant.
- EnumAiCapability: textGeneration.
- EnumAiSourceType: localFile, bundledAsset, remoteDownload.
- EnumAiModelStatus: notInstalled, installing, verifying, installed, loading,
  ready, unloading, removing, failed.
- EnumAiFinishReason: completed, outputLimit.
- EnumAiFailureCode: invalidRequest, modelUnavailable, integrityFailure,
  insufficientResources, unsupportedCapability, modelLoadFailure, inferenceFailure.

Enums use stable string names in JSON, never ordinal indexes. Unknown values
fail closed with FormatException; no fallback silently indicates success.

## Invariants

- Identifiers, descriptor names/versions, and failure messages are nonblank.
  Message content and stop sequences are nonempty; whitespace is preserved.
- Requests contain at least one message; descriptors have nonempty capabilities.
- ModelAiRequirements contains only storageBytes and minimumMemoryBytes; runtime,
  backend, accelerator, and recommended-memory fields are outside the v0 contract.
- Token counts and byte sizes are nullable nonnegative integers. Null means
  unknown, while zero is a measurement. totalTokens is reported independently:
  it is not inferred or required to equal inputTokens + outputTokens.
- maxOutputTokens is null or positive; temperature is null or finite and
  nonnegative. Runtime-specific supported ranges remain an adapter concern.
- A localFile source requires path and forbids assetPath/url.
- A bundledAsset source requires assetPath and forbids path/url.
- A remoteDownload source requires an absolute HTTPS URL and expectedSha256,
  and forbids path/assetPath. URL validation requires a nonempty host, empty
  Uri.userInfo, and no fragment (including an empty trailing #). Query parameters
  are not inspected for credentials; the contract does not promise credential
  detection or establish source trust.
- SHA-256, when present, contains exactly 64 hexadecimal characters and is
  normalized to lowercase. The domain validates its shape, not file contents.
- A source URL describes acquisition, never permission for remote inference.
- progress is null or finite in [0, 1]. Null means unmeasurable, zero is measured
  start, and one is measured completion. Failed snapshots may preserve progress.
- A failed state requires failure; other statuses forbid failure.
- A successful response may contain empty text. v0 supports only completed and
  outputLimit finish reasons. AiGateway exposes no active cancellation control;
  cancellation and any associated partial-result semantics are deferred to the
  runtime/streaming issue. JSON with finishReason "cancelled" fails closed.
  Operational failures use AiFailureResult, not a failed finish reason.

## Lifecycle transitions

installed means resources are locally present; ready means the runtime has
loaded them and can accept inference. Inference errors do not automatically
change model availability.

| From | Allowed next status |
| --- | --- |
| notInstalled | installing |
| installing | verifying, failed |
| verifying | installed, failed |
| installed | loading, removing |
| loading | ready, failed |
| ready | unloading |
| unloading | installed, failed |
| removing | notInstalled, failed |
| failed | installed, notInstalled |

Same-status updates are allowed, for example to report progress or update failure
information. A failed snapshot does not identify which resources are usable.
Recovery must first establish a verified installed or notInstalled snapshot,
clearing failure, before the normal state rules permit loading/removal or
installation. Direct failed -> loading/installing/removing shortcuts are rejected.

The public predicate checks domain status edges only; it does not verify resources
or infer hidden execution context. Verification belongs to a future implementation,
not this pure-domain issue. A ready model must unload before removal.

## Contract signatures

```dart
sealed class AiResult<T> { const AiResult(); }
final class AiSuccess<T> extends AiResult<T> { /* final T value */ }
final class AiFailureResult<T> extends AiResult<T> {
  /* final ModelAiFailure failure */
}

abstract interface class AiGateway {
  Future<AiResult<ModelAiResponse>> infer(ModelAiRequest request);
}

abstract interface class AiModelManager {
  Future<AiResult<List<ModelAiDescriptor>>> discover();
  Future<AiResult<ModelAiState>> install(ModelAiDescriptor model);
  Future<AiResult<ModelAiState>> load(String modelId);
  Future<AiResult<ModelAiState>> unload(String modelId);
  Future<AiResult<ModelAiState>> remove(String modelId);
  Stream<ModelAiState> watch(String modelId);
}
```

AiResult is a nonpersistable contractual primitive: it has no JSON or copyWith
requirement. Its payload must be immutable when used by these contracts;
discover returns an unmodifiable list. The sealed variants support exhaustive
pattern matching. These interfaces do not provide runtime implementations.

Expected operational failures are returned as AiFailureResult; infrastructure
exceptions must be mapped by adapters. In v0, acquisition/read failures map to
modelUnavailable, integrity mismatches to integrityFailure, loading failures to
modelLoadFailure, and inference failures to inferenceFailure. retryable is
context-dependent. Programming errors are not silently converted to success.

For a known model, watch emits the current snapshot followed by valid updates.
Unknown nonblank IDs initially emit notInstalled; invalid blank IDs throw
ArgumentError. Runtime failures are failed snapshots, not stream error events.
Successful install/load/unload/remove return installed/ready/installed/notInstalled
respectively. Installation registers the descriptor; a conflicting descriptor
for an existing ID returns invalidRequest. Repeated operations already at their
target are idempotent. Operations in an incompatible/busy state return
invalidRequest; load without installed resources returns modelUnavailable.
Adapters serialize mutations per model ID and release listener resources when
a subscription is cancelled. Cancelling a watch subscription only detaches its
listener; it is not a request to cancel inference or a model operation. The domain
does not implement a scheduler.

## Serialization and compatibility

All ten models have fromJson, toJson, copyWith, value equality, and hashCode.
Constructors and copyWith validate at runtime with ArgumentError. fromJson
reports invalid/missing required fields and invalid nested data as FormatException.
Unknown object fields are ignored for additive compatibility. Required object
fields remain required even where the Dart constructor offers a default.
Nullable fields may be absent or null. Serialization always includes nullable
keys and uses only JSON values. Optional stopSequences defaults to an empty list
when absent; an explicit null is invalid.

JSON keys and enum names are stable contracts. Existing payloads remain readable
within the same major package version; breaking contracts need an explicit
version/migration decision (including while the package is pre-1.0). Readers of
older versions still reject newly introduced enum values: compatibility is not
a promise of forward acceptance. Capability sets serialize in sorted name order;
message and stop-sequence order is preserved. Dates and runtime handles are absent.

copyWith distinguishes omission from explicit null for every nullable field.
Nullable copyWith parameters use an internal sentinel and validate replacement
types at runtime. Lists and sets are defensively copied and unmodifiable. Mutating input collections
or returned JSON must never mutate a model. List equality is ordered; capability
set equality and hashes are independent of insertion order.

The models use final classes/fields and defensive collections instead of the
package:meta immutable annotation. A narrowly scoped, documented lint suppression
on these value types avoids introducing a dependency solely for that annotation.

## Definition of Done

- [ ] Implement the ten ModelAi models and six EnumAi enumerations listed above.
- [ ] Implement AiResult/AiSuccess/AiFailureResult and both interface contracts.
- [ ] Every model has factory fromJson, toJson, typed copyWith, value equality,
      consistent hashCode, and deep collection immutability.
- [ ] Test actual JSON text round trips: model -> toJson -> jsonEncode ->
      jsonDecode -> fromJson -> equal model, including nested/nullable values.
- [ ] Test source invariants, required SHA-256, enum rejection, numeric bounds,
      missing/malformed fields, unknown object fields, and deterministic JSON.
- [ ] Test copyWith omission/clearing/replacement, defensive copying, and hashes.
- [ ] Document and test all permitted/rejected lifecycle transition pairs,
      including failed recovery only through installed/notInstalled.
- [ ] Defer active cancellation; expose only completed/outputLimit in v0 and
      reject cancelled JSON payloads.
- [ ] Match requirements documentation to storageBytes/minimumMemoryBytes and
      URL documentation to host/userInfo/fragment checks, not generic credentials.
- [ ] Test exhaustive result handling and demonstrate the interfaces with fakes;
      no real network, filesystem, or runtime is required for domain tests.
- [ ] Replace Awesome scaffold and update English API docs, README, runnable
      example, and Unreleased without changing package version 0.0.0.
- [ ] Pass formatting, strict analysis, existing CI script/workflow checks,
      Dart tests, and >=95% lib coverage, targeting 100%.
- [ ] Provide a temporary full implementation diff for review before any commit.

Changes are reviewed through an issue-linked branch and a pull request to
develop. The issue remains open until integration is approved.
