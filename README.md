# Jocaagura AI

![CI](https://img.shields.io/github/actions/workflow/status/grupo-jocaagura/jocaagura_ia/validate_pr.yaml?branch=develop)
![Status](https://img.shields.io/badge/status-domain%20prototype-blue)
![Coverage minimum](https://img.shields.io/badge/coverage_minimum-95%25-brightgreen)

Pure Dart domain contracts for local AI inference and model lifecycle management, following Jocaagura naming, immutability, and JSON conventions.

## Description

`jocaagura_ai` aims to provide a shared domain API for running AI models inside the application.

Business logic will interact with Jocaagura-owned requests, responses, model descriptors, and lifecycle states. Adapters will handle the integration with the inference engine, runtime, model format, and local model files.

The primary goal is to perform inference directly on the device, with the model and all required resources already available, without requiring an Internet connection, local server, API key, or external AI provider during inference.

The approach includes:

- Inference contracts independent of the underlying engine, model format, and model source.
- Models bundled by the application or downloaded in advance for later offline use.
- Model installation, integrity verification, loading, unloading, and removal.
- Observable model capabilities, known storage/minimum memory requirements, and lifecycle states.
- Replaceable adapters that allow different inference engines and models to be evaluated without leaking their technical details into business logic.

## Project status

**Package version `0.0.3`, including ordered text/image input and declaration
assessment. CI will prepare the selected minor promotion to `0.1.0`.**

The package provides immutable `ModelAi*` values, typed content parts/sources,
directional declarations, a pure compatibility assessor, `AiResult<T>` variants,
and the `AiGateway` / `AiModelManager` interfaces.

The domain depends only on the Dart SDK. It follows Jocaagura conventions without
depending on Flutter or `jocaagura_domain`.

The separate [jocaagura_ai_server](https://github.com/grupo-jocaagura/jocaagura_ia/tree/develop/packages/jocaagura_ai_server) package
implements the first local inference POC. It depends on this core and on the
runtime; the core does not depend on the server. Full model management remains
future work. See the [POC evidence](doc/local_inference_poc.md) for tested scope.

## Architecture

```text
Dart / Flutter Application
          │
          ▼
     jocaagura_ai
     ├── AiGateway ─────────► Local inference adapter
     │                                │
     │                                ▼
     │                    Embedded engine + local model
     │                                │
     │                                ▼
     │                     Device CPU / GPU / NPU
     │
     └── AiModelManager ────► Model installation and lifecycle
```

Inference and model lifecycle management will remain separate responsibilities:

| Contract              | Responsibility                                                                                  |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| `AiGateway`           | Receive inference requests and return Jocaagura domain responses.                               |
| `AiModelManager`      | Manage model availability, installation, removal, loading, and observable lifecycle state.      |
| `ModelAiDescriptor`   | Describe a model's identity, capabilities, and known requirements.                              |
| `ModelAiRequirements` | Express nullable `storageBytes` and `minimumMemoryBytes`; no runtime/backend/accelerator fields. |
| `ModelAiState`        | Represent lifecycle state and failures associated with a model.                                 |

Requests contain `requestId`, `modelId`, ordered `messages`, and generation
options. Descriptors contain the artifact source; requests do not embed them.
There is no `ModelAiPrompt` wrapper in this initial API.

`AiResult<T>` is a sealed, nonpersistable result primitive. Expected operational
failures use `AiFailureResult<T>` containing `ModelAiFailure`. Successful results
use `AiSuccess<T>`. JSON decoding rejects unknown enums and invalid values with
`FormatException`. See the [domain contract](doc/domain.md) for all models,
invariants, lifecycle transitions, and compatibility rules.

The v0 finish reasons are `completed` and `outputLimit`. Active cancellation is
reserved for a future runtime/streaming contract. Failed lifecycle snapshots
recover through verified `installed` or `notInstalled` states before another
operation can begin.

`ModelAiSource` validates remote URLs as absolute HTTPS with a nonempty host,
empty `Uri.userInfo`, and no fragment. It does not inspect query parameters for
credentials; this is URL-shape validation, not a credential-detection guarantee.

JSON keys and enum names are versioned contracts. Breaking changes require an
explicit compatibility decision, including during pre-1.0 development.

Classes and types belonging to the inference engine will remain isolated inside their adapters.

### Local inference consumer

`packages/jocaagura_ai_server` uses [llamadart](https://pub.dev/packages/llamadart)
0.8.23 with LiteRT-LM CPU and a local Gemma 4 E2B `.litertlm` artifact.

Its current documentation describes local execution of GGUF models through `llama.cpp` and `.litertlm` models through LiteRT-LM.

`llamadart` is a dependency only of the server, never of this domain package.

The POC supports one user message containing one text part, one configured model
ID and greedy generation. HTTP and direct smoke use the same embedded adapter.
Its companion API migration rejects images and multipart input before opening
resources. No image inference is certified.

The core represents ordered text/image input from inline bytes or lexical
local-file references. `assessAiContentCompatibility` checks model and backend
declarations without IO. Missing profiles/allowlists can yield `undetermined`;
null maxima impose no declared bound and do not alone prevent
`meetsDeclaredConstraints`. Meeting declarations is not proof of runtime support.
See [content contracts and migration](doc/content.md) for the complete schema.

Support for each platform, format, modality, backend, and hardware accelerator will only be documented after it has been tested.

Compatibility claimed by an upstream inference engine does not automatically constitute verified support by `jocaagura_ai`.

The architecture may later support optional remote adapters.

Remote execution must remain explicit. The local-first design does not automatically send requests to cloud providers when local inference fails.

## Quick start

### Current requirements

- Dart SDK `>=3.13.2 <4.0.0`.
- Git for repository development.

Flutter is not required to use or test the domain package.

The first server consumer also runs with Dart alone. Flutter integration is
outside this POC.

### Local development

From the repository root:

```sh
dart pub get
(cd packages/jocaagura_ai_server && dart pub get)
dart analyze --fatal-infos --fatal-warnings .
dart test
```

### Domain example

```dart
import 'dart:convert';
import 'package:jocaagura_ai/jocaagura_ai.dart';

final ModelAiRequest request = ModelAiRequest(
  requestId: 'request-1',
  modelId: 'local-model',
  messages: <ModelAiMessage>[
    ModelAiMessage.text(
      role: EnumAiMessageRole.user,
      text: 'Respond only with OK',
    ),
  ],
  options: ModelAiGenerationOptions(maxOutputTokens: 8),
);

final ModelAiRequest restored = ModelAiRequest.fromJson(
  jsonDecode(jsonEncode(request.toJson())) as Map<String, dynamic>,
);
final ModelAiRequest updated = restored.copyWith(
  options: restored.options.copyWith(maxOutputTokens: null),
);
```

Every model provides `fromJson`, `toJson`, `copyWith`, value equality, and
immutable collections. Explicit null clears nullable fields in `copyWith`;
omitting an argument preserves it. Unknown measurements remain null, not zero.

Run the [fixture example](example/jocaagura_ai_example.dart) with:

```sh
dart run example/jocaagura_ai_example.dart
```

The example demonstrates serialization and result handling; it performs no real
inference. Run the separate server's [inference example](https://github.com/grupo-jocaagura/jocaagura_ia/tree/develop/packages/jocaagura_ai_server)
for the local model POC. Package publication remains a separate release step.

### Package migration

Change the dependency name from `jocaagura_ia` to `jocaagura_ai` and import
`package:jocaagura_ai/jocaagura_ai.dart`. No old-name entrypoint shim is provided.
The 0.0.2 package rename preserved the domain API and JSON of that release.
The Unreleased content extension separately migrates `ModelAiMessage` from
`content` to `parts`: use `ModelAiMessage.text(role: ..., text: ...)` for one text
part. Readers accept legacy `content` JSON; writers emit only canonical `parts`.
Both keys together are rejected. Dart consumers must explicitly migrate without
silently flattening mixed content. This is a breaking API/writer change;
release version selection and publication remain separate work.
The GitHub repository and Git dependency URL remain
`https://github.com/grupo-jocaagura/jocaagura_ia`.

Version `0.0.0` is reserved for the bootstrap phase.

## Initial milestones

1. **Local inference with networking disabled.**

   Load a model already present on the device, execute a simple request — for example, `Respond only with OK` — and obtain the result through the Jocaagura domain API.

   The committed POC records Gemma 4 E2B `.litertlm` with LiteRT-LM CPU on one
   Windows x64 computer, including two offline direct text runs. That evidence
   does not certify images or additional devices/backends.

2. **Installation and offline reuse.**

   Obtain a model from a trusted source, verify its SHA-256 checksum, install it locally, and repeat the same inference with networking disabled.

3. **Lifecycle and failure handling.**

   Observe model acquisition, integrity verification, availability, loading, readiness, inference failures, resource release, and model removal when appropriate.

4. **Documented compatibility.**

   Record the models, platforms, runtimes, inference backends, accelerators, and capabilities that have actually been tested before expanding the public compatibility surface.

## Models and offline execution

An application may:

- Provide an already available local model file.
- Bundle a model and its required resources with the application.
- Download a model before its first use and store it for future offline inference.

Downloading a model or preparing a runtime may require an Internet connection.

The offline guarantee applies to inference once the model and all required runtime resources are locally available.

The repository does not distribute model weights.

Each consuming application is responsible for selecting models appropriate for its target hardware and complying with the corresponding model licenses and usage conditions.

Runtime memory requirements may be significantly higher than the model file size because inference can also require context buffers, KV caches, runtime allocations, multimodal encoders, and accelerator-specific resources.

## Quality and contributions

CI requires:

- Consistent formatting.
- Strict static analysis.
- Automated tests.
- Minimum **95% code coverage**.
- **100% code coverage** as the target.

Coverage measures domain contracts and invariants. Passing domain tests does not
certify real inference, device support, or runtime compatibility.

Contributions should include tests proportional to the change and an entry under `Unreleased` in the changelog.

Changes involving model integrations must also document:

- Device used for testing.
- Operating system and version.
- Runtime and inference backend.
- Model and format.
- Relevant hardware acceleration.
- Scenario under test.
- Whether inference was successfully executed with networking disabled.

## Documentation map

- [Domain models, JSON invariants, and lifecycle contracts](doc/domain.md).
- [Ordered content, capability declarations, and API migration](doc/content.md).
- [Package changes and evolution](CHANGELOG.md).
- [MIT License](LICENSE).
- [Repository operations](.github/CI_CD.md).
- [Official repository](https://github.com/grupo-jocaagura/jocaagura_ia).
- [Jocaagura Domain](https://github.com/grupo-jocaagura/jocaagura_domain): reference for domain conventions. This package intentionally has no dependency on it.
- [Candidate inference engine documentation](https://pub.dev/packages/llamadart).

The MIT License applies to the `jocaagura_ai` source code.

Models, inference runtimes, native libraries, and related assets retain their own licenses and distribution terms.


## Release discipline

Development patch versions accumulate changes on `develop`. Public promotions
explicitly choose a minor or major bump and consolidate the preceding patch
notes with `Unreleased`, preserving the historical entries. The current planned
promotion is `0.0.3 -> 0.1.0`; `Prepare promotion` performs that bump in CI before
the `develop -> master` PR. See [.github/CI_CD.md](https://github.com/grupo-jocaagura/jocaagura_ia/blob/develop/.github/CI_CD.md)
for the preparation flow and the CP-0 gate on automatic publication.
