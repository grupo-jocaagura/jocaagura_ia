# Jocaagura IA

![CI](https://img.shields.io/github/actions/workflow/status/grupo-jocaagura/jocaagura_ia/validate_pr.yaml?branch=develop)
![Status](https://img.shields.io/badge/status-domain%20prototype-blue)
![Coverage minimum](https://img.shields.io/badge/coverage_minimum-95%25-brightgreen)

Pure Dart domain contracts for local AI inference and model lifecycle management, following Jocaagura naming, immutability, and JSON conventions.

## Description

`jocaagura_ia` aims to provide a shared domain API for running AI models inside the application.

Business logic will interact with Jocaagura-owned requests, responses, model descriptors, and lifecycle states. Adapters will handle the integration with the inference engine, runtime, model format, and local model files.

The primary goal is to perform inference directly on the device, with the model and all required resources already available, without requiring an Internet connection, local server, API key, or external AI provider during inference.

The approach includes:

- Inference contracts independent of the underlying engine, model format, and model source.
- Models bundled by the application or downloaded in advance for later offline use.
- Model installation, integrity verification, loading, unloading, and removal.
- Observable model capabilities, known storage/minimum memory requirements, and lifecycle states.
- Replaceable adapters that allow different inference engines and models to be evaluated without leaking their technical details into business logic.

## Project status

**Bootstrap — version `0.0.0`.**

The package provides ten immutable `ModelAi*` data models, six `EnumAi*` enums,
`AiResult<T>` variants, and the `AiGateway` / `AiModelManager` interfaces.

The domain depends only on the Dart SDK. It follows Jocaagura conventions without
depending on Flutter or `jocaagura_domain`.

Inference engines and model-management adapters are not implemented yet. The
local inference scenarios below remain POC milestones.

## Architecture

```text
Dart / Flutter Application
          │
          ▼
     jocaagura_ia
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

### Candidate engine for the POC

The initial discovery proposes evaluating [llamadart](https://pub.dev/packages/llamadart).

Its current documentation describes local execution of GGUF models through `llama.cpp` and `.litertlm` models through LiteRT-LM.

`llamadart` is not yet a dependency of this package.

Validation will begin with one local model and one concrete combination of device, runtime, and inference backend.

Support for each platform, format, modality, backend, and hardware accelerator will only be documented after it has been tested.

Compatibility claimed by an upstream inference engine does not automatically constitute verified support by `jocaagura_ia`.

The architecture may later support optional remote adapters.

Remote execution must remain explicit. The local-first design does not automatically send requests to cloud providers when local inference fails.

## Quick start

### Current requirements

- Dart SDK `>=3.13.2 <4.0.0`.
- Git for repository development.

Flutter is not required to use or test the domain package.

Flutter integration requirements will be defined once the first local inference adapter is introduced.

### Local development

From the repository root:

```sh
dart pub get
dart analyze --fatal-infos --fatal-warnings .
dart test
```

### Domain example

```dart
import 'dart:convert';
import 'package:jocaagura_ia/jocaagura_ia.dart';

final ModelAiRequest request = ModelAiRequest(
  requestId: 'request-1',
  modelId: 'local-model',
  messages: <ModelAiMessage>[
    ModelAiMessage(
      role: EnumAiMessageRole.user,
      content: 'Respond only with OK',
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

Run the [fixture example](example/jocaagura_ia_example.dart) with:

```sh
dart run example/jocaagura_ia_example.dart
```

The example demonstrates serialization and result handling; it performs no real
inference. Installation from pub.dev and an inference example will follow the
first functional runtime integration.

Version `0.0.0` is reserved for the bootstrap phase.

## Initial milestones

1. **Local inference with networking disabled.**

   Load a model already present on the device, execute a simple request — for example, `Respond only with OK` — and obtain the result through the Jocaagura domain API.

   The initial discovery proposes Gemma 4 E2B in `.litertlm` format as the first candidate model.

   Its final selection remains subject to runtime, device, memory, and compatibility testing.

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
- [Package changes and evolution](CHANGELOG.md).
- [MIT License](LICENSE).
- [Repository operations](.github/CI_CD.md).
- [Official repository](https://github.com/grupo-jocaagura/jocaagura_ia).
- [Jocaagura Domain](https://github.com/grupo-jocaagura/jocaagura_domain): reference for domain conventions. This package intentionally has no dependency on it.
- [Candidate inference engine documentation](https://pub.dev/packages/llamadart).

The MIT License applies to the `jocaagura_ia` source code.

Models, inference runtimes, native libraries, and related assets retain their own licenses and distribution terms.
